// 📁 screens/new_analysis_setup_screen.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:recruitswift/config/app_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

import '../models/job_description.dart';
import '../models/analysis_job.dart';
import '../models/analysis_result.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'analysis_job_detail_screen.dart';

class NewAnalysisSetupScreen extends StatefulWidget {
  static const routeName = '/newAnalysisSetup';
  final JobDescription selectedJD;

  const NewAnalysisSetupScreen({super.key, required this.selectedJD});

  @override
  State<NewAnalysisSetupScreen> createState() => _NewAnalysisSetupScreenState();
}

class _NewAnalysisSetupScreenState extends State<NewAnalysisSetupScreen> with SingleTickerProviderStateMixin {
  final List<PlatformFile> _pickedCVs = [];
  final Uuid _uuid = const Uuid();

  bool _isProcessing = false;
  String _processingStatusMessage = 'Select CVs to begin analysis.';
  double _currentProgress = 0.0;
  int _filesSuccessfullyProcessed = 0;
  int _filesFailedProcessing = 0;
  String? _currentAnalysisJobId;
  AnalysisJob? _createdAnalysisJob;

  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  late AnimationController _progressAnimationController;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false, Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade700,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _updateStatusAndProgress(String message, {double? progress, bool isErrorSource = false}) {
    if (!mounted) return;
    setState(() {
      _processingStatusMessage = message;
      if (progress != null) {
        _currentProgress = progress.clamp(0.0, 1.0);
        _progressAnimationController.animateTo(_currentProgress, curve: Curves.easeInOut);
      }
    });
    if (isErrorSource || message.toLowerCase().contains("complete") || message.toLowerCase().contains("cancelled")) {
        _showSnackbar(message, isError: isErrorSource);
    }
  }

  Future<void> _pickCVs() async {
    if (_isProcessing) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files.where((file) =>
            file.bytes != null && file.bytes!.isNotEmpty &&
            file.name != null && file.name!.isNotEmpty).toList();

        int addedCount = 0;
        if (newFiles.isNotEmpty) {
          setState(() {
            for (var newFile in newFiles) {
              if (!_pickedCVs.any((existing) => existing.name == newFile.name)) {
                _pickedCVs.add(newFile);
                addedCount++;
              }
            }
            _processingStatusMessage = '${_pickedCVs.length} CV(s) ready for analysis.';
            _currentProgress = 0.0;
            _filesSuccessfullyProcessed = 0;
            _filesFailedProcessing = 0;
          });
          if (addedCount > 0) {
            _showSnackbar('$addedCount CV(s) added. Total: ${_pickedCVs.length}', isError: false);
          } else if (newFiles.isNotEmpty) {
             _showSnackbar('Selected CV(s) were already in the list.', isError: false, duration: const Duration(seconds: 2));
          }
        } else {
          _showSnackbar('Selected files are invalid or empty.', isError: true);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error picking CV files: $e");
      _showSnackbar('Error picking files: ${e.toString()}', isError: true);
    }
  }

  Future<String> _saveFileToTemporaryLocation(Uint8List fileBytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeFileName = p.basename(fileName);
      final filePath = p.join(tempDir.path, "${_uuid.v4()}_$safeFileName");
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      if (kDebugMode) print("File saved temporarily at: $filePath");
      return filePath;
    } catch (e) {
      if (kDebugMode) print("Error saving file locally: $e");
      return "";
    }
  }

  Future<void> _startFullAnalysisProcess() async {
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null) {
      _updateStatusAndProgress("Error: User not authenticated. Please log in.", isErrorSource: true); return;
    }
    if (widget.selectedJD.id == null) {
      _updateStatusAndProgress("Error: Selected Job Description is invalid.", isErrorSource: true); return;
    }
    if (_pickedCVs.isEmpty) {
      _updateStatusAndProgress("Please select at least one CV to analyze."); return;
    }

    if (!AppConfig.isGeminiApiKeyConfigured()) {
        _updateStatusAndProgress("Critical Error: Gemini API Key is not configured in AppConfig. Analysis cannot proceed.", isErrorSource: true);
        setState(() => _isProcessing = false);
        return;
    }


    setState(() {
      _isProcessing = true;
      _currentProgress = 0.0;
      _filesSuccessfullyProcessed = 0;
      _filesFailedProcessing = 0;
      _processingStatusMessage = 'Initializing analysis job...';
    });

    AnalysisJob newAnalysisJob = AnalysisJob(
      jdId: widget.selectedJD.id!,
      jobTitle: widget.selectedJD.title,
      userId: currentUserId,
      status: 'processing',
      totalCVsToProcess: _pickedCVs.length,
      cvsProcessedCount: 0,
      shortlistedCount: 0,
    );

    try {
      final analysisJobRef = await _firestoreService.createAnalysisJob(newAnalysisJob);
      _currentAnalysisJobId = analysisJobRef.id;
      _createdAnalysisJob = newAnalysisJob.copyWith(id: _currentAnalysisJobId);

      _updateStatusAndProgress("Analysis job created. Processing ${_pickedCVs.length} CV(s)...", progress: 0.05);

      for (int i = 0; i < _pickedCVs.length; i++) {
        if (!mounted || !_isProcessing) {
            _updateStatusAndProgress("Processing cancelled by user.", isErrorSource: false);
            if (_currentAnalysisJobId != null) {
                await _firestoreService.updateAnalysisJobProgress(_currentAnalysisJobId!, status: 'cancelled', errorMessageToSet: "User cancelled processing.");
            }
            break;
        }

        final cvFile = _pickedCVs[i];
        final String cvFileNameForDisplay = cvFile.name ?? "Unnamed_CV_${i+1}";
        _updateStatusAndProgress(
          "Processing ${i+1}/${_pickedCVs.length}: $cvFileNameForDisplay...",
          progress: (i + 0.1) / _pickedCVs.length
        );

        String localCvPath = "";
        if (cvFile.bytes != null) {
            localCvPath = await _saveFileToTemporaryLocation(cvFile.bytes!, cvFileNameForDisplay);
        }

        try {
          _updateStatusAndProgress("Extracting text from $cvFileNameForDisplay...", progress: (i + 0.3) / _pickedCVs.length);
          if (cvFile.bytes == null) {
            throw Exception("CV file bytes are null for $cvFileNameForDisplay.");
          }
          final cvTextContent = await _geminiService.extractTextFromCv(cvFile.bytes!, cvFileNameForDisplay);

          _updateStatusAndProgress("Analyzing $cvFileNameForDisplay against JD...", progress: (i + 0.6) / _pickedCVs.length);
          final jdStructuredData = {
            'title': widget.selectedJD.title,
            'summary': widget.selectedJD.summary,
            'keyRequirements': widget.selectedJD.keyRequirements,
            'requiredSkills': widget.selectedJD.requiredSkills,
            'experienceLevel': widget.selectedJD.experienceLevel,
          };
          final analysisData = await _geminiService.analyzeAndMatchCv(
            cvFileName: cvFileNameForDisplay,
            cvText: cvTextContent,
            jobDescriptionData: jdStructuredData,
          );

          if (analysisData.containsKey('error')) {
            throw Exception("AI Analysis Error for $cvFileNameForDisplay: ${analysisData['error']}");
          }

          AnalysisResult result = AnalysisResult(
            id: _uuid.v4(),
            analysisJobId: _currentAnalysisJobId!,
            candidateId: analysisData['candidateId'] as String? ?? _uuid.v4(),
            candidateName: analysisData['candidateName'] as String? ?? 'Unknown Candidate',
            candidateEmail: analysisData['candidateEmail'] as String? ?? 'no_email@example.com',
            cvFileName: cvFileNameForDisplay,
            cvFileUrl: localCvPath.isNotEmpty ? localCvPath : null,
            extractedSkills: List<String>.from(analysisData['extractedSkills'] ?? []),
            extractedExperienceSummary: analysisData['extractedExperienceSummary'] as String? ?? 'No AI summary available.',
            matchScore: (analysisData['matchScore'] as num?)?.toDouble() ?? 0.0,
            matchSummary: analysisData['matchSummary'] as String? ?? 'No AI explanation available.',
          );

          await _firestoreService.addAnalysisResult(_currentAnalysisJobId!, result);
          await _firestoreService.updateAnalysisJobProgress(
            _currentAnalysisJobId!,
            cvsProcessedIncrement: 1,
            shortlistedIncrement: result.isShortlisted ? 1 : 0,
          );
          _filesSuccessfullyProcessed++;
          _updateStatusAndProgress("Successfully processed: $cvFileNameForDisplay", progress: (i + 1.0) / _pickedCVs.length);

        } catch (e) {
          _filesFailedProcessing++;
          if (kDebugMode) print("Error processing CV $cvFileNameForDisplay: $e");
          _updateStatusAndProgress(
            "Error with $cvFileNameForDisplay: ${e.toString().length > 100 ? e.toString().substring(0,100) : e.toString()}...",
            isErrorSource: true,
            progress: (i + 1.0) / _pickedCVs.length
          );
           if(_currentAnalysisJobId != null) {
            await _firestoreService.updateAnalysisJobProgress(
                _currentAnalysisJobId!,
                cvsProcessedIncrement: 1,
                status: 'processing_with_errors',
                errorMessageToSet: "Error with $cvFileNameForDisplay: ${e.toString()}"
            );
           }
        } finally {
          if(mounted) {
            final totalAttempted = _filesSuccessfullyProcessed + _filesFailedProcessing;
            setState(() => _currentProgress = totalAttempted / _pickedCVs.length);
            _progressAnimationController.animateTo(_currentProgress, curve: Curves.easeInOut);
          }
        }
      }

      if(mounted && _isProcessing && _currentAnalysisJobId != null) {
        final finalStatus = _filesFailedProcessing > 0 ? 'completed_with_errors' : 'completed';
        await _firestoreService.updateAnalysisJobProgress(
            _currentAnalysisJobId!,
            status: finalStatus,
            clearErrorMessage: (_filesFailedProcessing == 0)
        );
        _updateStatusAndProgress(
          "Analysis complete. Success: $_filesSuccessfullyProcessed, Failed: $_filesFailedProcessing. Status: $finalStatus.",
          isErrorSource: _filesFailedProcessing > 0
        );
      }

    } catch (e) {
      if (kDebugMode) print("Critical error during analysis job setup or Firestore operation: $e");
      _updateStatusAndProgress("Analysis setup failed: ${e.toString()}", isErrorSource: true);
       if(_currentAnalysisJobId != null) {
         try {
            await _firestoreService.updateAnalysisJobProgress(_currentAnalysisJobId!, status: 'error', errorMessageToSet: e.toString());
         } catch (fsError) {
            if (kDebugMode) print("Failed to update job status to error after initial failure: $fsError");
         }
       }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildSelectedCvChip(PlatformFile file, int index) {
    final theme = Theme.of(context);
    return Chip(
      key: ValueKey(file.identifier ?? file.name ?? 'file_$index'),
      avatar: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.9),
        child: Text((index + 1).toString(), style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      label: Text(file.name ?? 'Unknown File', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      onDeleted: _isProcessing ? null : () {
        setState(() {
          _pickedCVs.removeAt(index);
           _processingStatusMessage = _pickedCVs.isNotEmpty ? '${_pickedCVs.length} CV(s) ready for analysis.' : 'Select CVs to begin analysis.';
           if(_pickedCVs.isEmpty) {
             _currentProgress = 0.0;
             _filesSuccessfullyProcessed = 0;
             _filesFailedProcessing = 0;
             _progressAnimationController.value = 0.0;
           }
        });
      },
      deleteIconColor: theme.colorScheme.error.withOpacity(0.8),
      backgroundColor: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.chipBorderRadius),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5))
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canStartAnalysis = !_isProcessing && _pickedCVs.isNotEmpty;
    final bool analysisAttempted = _filesSuccessfullyProcessed > 0 || _filesFailedProcessing > 0;
    final bool analysisCompleted = !_isProcessing && analysisAttempted && (_filesSuccessfullyProcessed + _filesFailedProcessing == _pickedCVs.length) && _pickedCVs.isNotEmpty;


    return Scaffold(
      appBar: AppBar(
        title: const Text("New CVs Analysis"),
        actions: [
          if (_isProcessing)
            IconButton(
              icon: const Icon(Icons.cancel_presentation_rounded),
              tooltip: "Cancel Processing",
              onPressed: () {
                setState(() {
                  _isProcessing = false;
                });
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Analyzing CVs for Job:", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(widget.selectedJD.title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    if (widget.selectedJD.experienceLevel != null && widget.selectedJD.experienceLevel!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text("Experience Level: ${widget.selectedJD.experienceLevel}", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _isProcessing ? null : _pickCVs,
              label: const Text("Select CVs (PDF, IMG, TXT)"),
               style: theme.elevatedButtonTheme.style?.copyWith(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.disabled)) return Colors.grey.shade400; // Adjusted disabled color for light theme
                    return theme.colorScheme.secondary;
                  },
                ),
                foregroundColor: MaterialStateProperty.all(theme.colorScheme.onSecondary),
                padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
              )
            ),
            const SizedBox(height: 16),
            if (_pickedCVs.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Padding(
                      padding: const EdgeInsets.symmetric(vertical:8.0),
                      child: Text("${_pickedCVs.length} CV(s) selected:", style: theme.textTheme.titleMedium),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _pickedCVs.length,
                        itemBuilder: (context, index) {
                          return _buildSelectedCvChip(_pickedCVs[index], index);
                        },
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                      ),
                    ),
                  ],
                ),
              )
            else if (!_isProcessing)
              Expanded(
                child: Center(
                  child: Opacity(
                    opacity: 0.7,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_copy_outlined, size: 70, color: theme.colorScheme.primary.withOpacity(0.6)),
                        const SizedBox(height: 16),
                        Text("No CVs selected yet.", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7))),
                        Text("Click 'Select CVs' to begin.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.6))),
                      ],
                    ),
                  ),
                )
              ),

            if (_isProcessing || analysisAttempted) ...[
              const SizedBox(height: 20),
              Text(_processingStatusMessage, style: theme.textTheme.bodyLarge?.copyWith(
                  color: _processingStatusMessage.toLowerCase().contains("error") || _filesFailedProcessing > 0
                         ? theme.colorScheme.error
                         : (_processingStatusMessage.toLowerCase().contains("complete") ? Colors.green.shade600 : theme.colorScheme.primary) // Use green.shade600 for light theme
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                  animation: _progressAnimationController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                        value: _progressAnimationController.value,
                        minHeight: 10,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _filesFailedProcessing > 0 && _progressAnimationController.value > 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary
                        ),
                        borderRadius: BorderRadius.circular(5),
                    );
                  }
              ),
              const SizedBox(height: 6),
              Text(
                "${(_currentProgress * 100).toStringAsFixed(0)}% Complete (${_filesSuccessfullyProcessed + _filesFailedProcessing}/${_pickedCVs.length})",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
              ),
              if (analysisAttempted && _filesFailedProcessing > 0)
                 Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text(
                    "Success: $_filesSuccessfullyProcessed, Failed: $_filesFailedProcessing",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: _filesFailedProcessing > 0 ? theme.colorScheme.error : Colors.green.shade600) // Use green.shade600
                  ),
                 ),
              const SizedBox(height: 20),
            ],

            if (analysisCompleted && _createdAnalysisJob != null)
                ElevatedButton.icon(
                  icon: Icon(Icons.fact_check_outlined, color: theme.colorScheme.onSecondary),
                  label: Text("View Analysis Results", style: TextStyle(color: theme.colorScheme.onSecondary)),
                  onPressed: () {
                     Navigator.pushReplacementNamed(
                      context,
                      AnalysisJobDetailScreen.routeName,
                      arguments: _createdAnalysisJob!.id!,
                    );
                  },
                  style: theme.elevatedButtonTheme.style?.copyWith(
                    backgroundColor: MaterialStateProperty.all(Colors.green.shade600),
                    minimumSize: MaterialStateProperty.all(const Size(double.infinity, 52)),
                  )
                )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_outline_rounded),
                onPressed: canStartAnalysis ? _startFullAnalysisProcess : null,
                label: Text(_isProcessing ? "Processing..." : "Start Full Analysis (${_pickedCVs.length} CVs)"),
                style: theme.elevatedButtonTheme.style?.copyWith(
                   minimumSize: MaterialStateProperty.all(const Size(double.infinity, 52)),
                )
              ),
          ],
        ),
      ),
    );
  }
}