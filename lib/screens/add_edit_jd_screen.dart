// 📁 screens/add_edit_jd_screen.dart
import 'package:flutter/material.dart';
import '../models/job_description.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';

class AddEditJDScreen extends StatefulWidget {
  static const routeName = '/addEditJD';
  final JobDescription? jobDescription;

  const AddEditJDScreen({super.key, this.jobDescription});

  @override
  State<AddEditJDScreen> createState() => _AddEditJDScreenState();
}

class _AddEditJDScreenState extends State<AddEditJDScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _fullTextController;
  String _selectedStatus = 'active';
  bool _isLoading = false;
  String _loadingMessage = 'Processing...';

  final FirestoreService _firestoreService = FirestoreService();
  final GeminiService _geminiService = GeminiService();
  final AuthService _authService = AuthService();

  final List<String> _jdStatuses = ['active', 'closed', 'draft'];

  bool get _isEditMode => widget.jobDescription != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.jobDescription?.title ?? '');
    _fullTextController = TextEditingController(text: widget.jobDescription?.fullText ?? '');
    _selectedStatus = widget.jobDescription?.status ?? 'active';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _fullTextController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }


  Future<void> _saveJobDescription() async {
    FocusScope.of(context).unfocus();
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null) {
      _showErrorSnackbar('Error: Not authenticated. Please log in again.');
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Analyzing Job Description with AI... This may take a moment.';
      });

      String title = _titleController.text.trim();
      String fullText = _fullTextController.text.trim();

      try {
        final aiProcessedData = await _geminiService.processJobDescriptionText(fullText);

        if (aiProcessedData.containsKey('error')) {
          _showErrorSnackbar('AI Processing Error: ${aiProcessedData['error']}. JD will be saved without full AI analysis.');
        }

        setState(() {
          _loadingMessage = _isEditMode ? 'Updating Job Description...' : 'Saving Job Description...';
        });

        JobDescription jdToSave;
        if (!_isEditMode) {
          jdToSave = JobDescription(
            title: title,
            fullText: fullText,
            userId: currentUserId,
            summary: aiProcessedData['summary'] as String?,
            keyRequirements: (aiProcessedData['keyRequirements'] as List<dynamic>?)?.cast<String>().toList() ?? [],
            responsibilities: (aiProcessedData['responsibilities'] as List<dynamic>?)?.cast<String>().toList() ?? [],
            requiredSkills: (aiProcessedData['requiredSkills'] as List<dynamic>?)?.cast<String>().toList() ?? [],
            experienceLevel: aiProcessedData['experienceLevel'] as String?,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: _selectedStatus,
          );
          await _firestoreService.addJobDescription(jdToSave);
          _showSuccessSnackbar('Job Description added and analyzed!');
        } else {
          if (widget.jobDescription!.userId != currentUserId) {
             _showErrorSnackbar('Error: You are not authorized to edit this Job Description.');
              if (mounted) setState(() => _isLoading = false);
              return;
          }
          jdToSave = widget.jobDescription!.copyWith(
            title: title,
            fullText: fullText,
            summary: () => aiProcessedData['summary'] as String?,
            keyRequirements: (aiProcessedData['keyRequirements'] as List<dynamic>?)?.cast<String>().toList() ?? widget.jobDescription!.keyRequirements,
            responsibilities: (aiProcessedData['responsibilities'] as List<dynamic>?)?.cast<String>().toList() ?? widget.jobDescription!.responsibilities,
            requiredSkills: (aiProcessedData['requiredSkills'] as List<dynamic>?)?.cast<String>().toList() ?? widget.jobDescription!.requiredSkills,
            experienceLevel: () => aiProcessedData['experienceLevel'] as String?,
            updatedAt: () => DateTime.now(),
            status: _selectedStatus,
          );
          await _firestoreService.updateJobDescription(jdToSave);
           _showSuccessSnackbar('Job Description updated and re-analyzed!');
        }
        if (mounted) {
          Navigator.pop(context, jdToSave);
        }
      } catch (e) {
        print("Error saving/processing JD: $e");
        _showErrorSnackbar('Failed to save Job Description: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Job Description' : 'Add New Job Description'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Job Title*',
                  hintText: 'e.g., Senior Flutter Developer',
                  prefixIcon: Icon(Icons.title_rounded, color: theme.inputDecorationTheme.prefixIconColor),
                ),
                style: theme.textTheme.bodyLarge,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Job title is required';
                  if (value.trim().length < 5) return 'Job title should be at least 5 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _fullTextController,
                decoration: InputDecoration(
                  labelText: 'Full Job Description Text*',
                  hintText: 'Paste the complete job description here. AI will analyze this text to extract key details.',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 0),
                    child: Icon(Icons.description_outlined, color: theme.inputDecorationTheme.prefixIconColor),
                  ),
                ),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                maxLines: 15,
                minLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Full job description is required';
                  if (value.trim().length < 100) {
                     return 'Job description seems too short (min 100 characters). Provide more details for better AI analysis.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(
                    _selectedStatus == 'active' ? Icons.play_circle_fill_rounded :
                    _selectedStatus == 'closed' ? Icons.pause_circle_filled_rounded : Icons.pending_actions_rounded,
                    color: theme.inputDecorationTheme.prefixIconColor
                  ),
                ),
                items: _jdStatuses.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status[0].toUpperCase() + status.substring(1), style: theme.textTheme.bodyLarge),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedStatus = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            _loadingMessage,
                            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      icon: Icon(_isEditMode ? Icons.save_alt_outlined : Icons.add_circle_outline_rounded),
                      onPressed: _saveJobDescription,
                      label: Text(_isEditMode ? 'Update & Re-analyze JD' : 'Save & Analyze with AI'),
                      style: theme.elevatedButtonTheme.style?.copyWith(
                        minimumSize: MaterialStateProperty.all(const Size(double.infinity, 52)),
                      )
                    ),
            ],
          ),
        ),
      ),
    );
  }
}