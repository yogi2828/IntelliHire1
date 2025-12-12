// 📁 screens/analysis_job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:recruitswift/config/app_config.dart';
import '../services/firestore_service.dart';
import '../services/email_service.dart';
import '../models/analysis_job.dart';
import '../models/analysis_result.dart';
import 'analysis_job_list_screen.dart' show StringAnalysisJobExtension;

class AnalysisJobDetailScreen extends StatefulWidget {
  static const routeName = '/analysisJobDetail';
  final String analysisJobId;

  const AnalysisJobDetailScreen({super.key, required this.analysisJobId});

  @override
  State<AnalysisJobDetailScreen> createState() => _AnalysisJobDetailScreenState();
}

class _AnalysisJobDetailScreenState extends State<AnalysisJobDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final EmailService _emailService = EmailService();
  AnalysisJob? _analysisJob;
  bool _isLoadingJob = true;
  String? _jobError;

  final Set<String> _selectedCandidateIds = {};
  bool _isBulkSelectMode = false;

  @override
  void initState() {
    super.initState();
    _loadAnalysisJob();
  }

  Future<void> _loadAnalysisJob() async {
    if (!mounted) return;
    setState(() {
      _isLoadingJob = true;
      _jobError = null;
    });
    try {
      final job = await _firestoreService.getAnalysisJob(widget.analysisJobId);
      if (mounted) {
        setState(() {
          _analysisJob = job;
          _isLoadingJob = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jobError = "Error loading analysis job: ${e.toString()}";
          _isLoadingJob = false;
        });
      }
    }
  }

  void _toggleCandidateSelection(String candidateId) {
    setState(() {
      if (_selectedCandidateIds.contains(candidateId)) {
        _selectedCandidateIds.remove(candidateId);
      } else {
        _selectedCandidateIds.add(candidateId);
      }
      if (_selectedCandidateIds.isEmpty) {
        _isBulkSelectMode = false;
      } else {
        _isBulkSelectMode = true;
      }
    });
  }
  void _clearSelection() {
    setState(() {
      _selectedCandidateIds.clear();
      _isBulkSelectMode = false;
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade700,
    ));
  }

  Future<void> _updateCandidateShortlistStatus(AnalysisResult candidate, bool newStatus) async {
    try {
      final updatedCandidate = candidate.copyWith(isShortlisted: newStatus);
      await _firestoreService.updateAnalysisResult(widget.analysisJobId, updatedCandidate);
      _loadAnalysisJob();
      _showSnackbar('${candidate.candidateName} ${newStatus ? "shortlisted" : "removed from shortlist"}.');
    } catch (e) {
      _showSnackbar('Error updating shortlist status: ${e.toString()}', isError: true);
    }
  }

  Future<void> _sendBulkEmails(EmailPurpose purpose, List<AnalysisResult> allResults) async {
    if (_selectedCandidateIds.isEmpty) {
      _showSnackbar("No candidates selected for email.", isError: true);
      return;
    }
    if (_analysisJob == null) {
       _showSnackbar("Analysis job data not loaded.", isError: true);
      return;
    }

    final List<AnalysisResult> candidatesToSend = allResults
        .where((r) => _selectedCandidateIds.contains(r.id))
        .toList();

    if (candidatesToSend.isEmpty) {
      _showSnackbar("Selected candidates not found in current results.", isError: true);
      return;
    }

    final bool? confirmSend = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Bulk Email (${purpose.toString().split('.').last.capitalizeWords()})'),
          content: Text('Are you sure you want to send ${purpose.toString().split('.').last.toLowerCase()} emails to ${_selectedCandidateIds.length} selected candidate(s) for "${_analysisJob!.jobTitle}"?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              child: Text('Send Emails', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmSend != true) return;


    _showSnackbar("Sending emails to ${candidatesToSend.length} candidates...", isError: false);

    try {
      final emailStatuses = await _emailService.sendEmailsToCandidates(
        candidates: candidatesToSend,
        jobTitle: _analysisJob!.jobTitle,
        emailPurpose: purpose,
      );

      List<String> successfullySentIds = [];
      List<String> failedToSendIds = [];
      emailStatuses.forEach((candidateId, status) {
        if (status == 'sent') {
          successfullySentIds.add(candidateId);
        } else {
          failedToSendIds.add(candidateId);
        }
      });

      if (successfullySentIds.isNotEmpty) {
        await _firestoreService.batchUpdateEmailStatus(
          widget.analysisJobId,
          successfullySentIds,
          '${purpose.toString().split('.').last.toLowerCase()}_sent',
          setInterviewRequested: (purpose == EmailPurpose.invitationToInterview)
        );
      }
      if (failedToSendIds.isNotEmpty) {
         await _firestoreService.batchUpdateEmailStatus(
          widget.analysisJobId,
          failedToSendIds,
          '${purpose.toString().split('.').last.toLowerCase()}_failed',
          setInterviewRequested: false
        );
      }

      _showSnackbar("${successfullySentIds.length} emails sent. ${failedToSendIds.length} failed.", isError: failedToSendIds.isNotEmpty);
      _clearSelection();
    } catch (e) {
      _showSnackbar("Error sending emails: ${e.toString()}", isError: true);
    }
  }

  Widget _buildLocalStatusChip(BuildContext context, String status) {
    final theme = Theme.of(context);
    Color chipColor; IconData chipIcon; Color textColor;
    switch (status.toLowerCase()) {
      case 'completed': chipColor = Colors.green.shade600; textColor = Colors.white; chipIcon = Icons.check_circle_outline_rounded; break;
      case 'processing': chipColor = Colors.blue.shade500; textColor = Colors.white; chipIcon = Icons.hourglass_top_rounded; break;
      case 'processing_with_errors': chipColor = Colors.orange.shade600; textColor = Colors.white; chipIcon = Icons.warning_amber_rounded; break;
      case 'completed_with_errors': chipColor = Colors.amber.shade700; textColor = Colors.black; chipIcon = Icons.error_outline_rounded; break;
      case 'error': chipColor = theme.colorScheme.error; textColor = theme.colorScheme.onError; chipIcon = Icons.dangerous_outlined; break;
      case 'cancelled': chipColor = Colors.grey.shade600; textColor = Colors.white; chipIcon = Icons.cancel_outlined; break;
      default: chipColor = theme.colorScheme.secondary.withOpacity(0.7);textColor = theme.colorScheme.onSecondary; chipIcon = Icons.help_outline_rounded;
    }
    return Chip(
      avatar: Icon(chipIcon, color: textColor, size: 16),
      label: Text(status.capitalizeWords(), style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500)),
      backgroundColor: chipColor.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_analysisJob?.jobTitle ?? "Analysis Details"),
        actions: [
          if (_isBulkSelectMode)
            IconButton(
              icon: const Icon(Icons.deselect_rounded),
              tooltip: "Clear Selection",
              onPressed: _clearSelection,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Data",
            onPressed: (){
               _loadAnalysisJob();
               if(mounted) setState((){});
            }
          ),
        ],
      ),
      body: _isLoadingJob
          ? const Center(child: CircularProgressIndicator())
          : _jobError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_jobError!, style: TextStyle(color: theme.colorScheme.error))))
              : _analysisJob == null
                  ? const Center(child: Text("Analysis job not found."))
                  : Column(
                      children: [
                        _buildJobSummaryCard(theme),
                        if (_isBulkSelectMode && _selectedCandidateIds.isNotEmpty)
                           StreamBuilder<List<AnalysisResult>>( // StreamBuilder here to get latest results for bulk actions
                              stream: _firestoreService.getAnalysisResultsStream(widget.analysisJobId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.active && snapshot.hasData) {
                                  return _buildBulkActionToolbar(theme, snapshot.data!); // Pass results to toolbar
                                }
                                return const SizedBox.shrink(); // Hide toolbar if no data or loading
                              },
                           ),
                        Expanded(child: _buildResultsList(theme)),
                      ],
                    ),
    );
  }

  Widget _buildJobSummaryCard(ThemeData theme) {
    double progress = 0;
    if (_analysisJob!.totalCVsToProcess > 0) {
      progress = _analysisJob!.cvsProcessedCount / _analysisJob!.totalCVsToProcess;
    } else if (_analysisJob!.status.toLowerCase() == 'completed' || _analysisJob!.status.toLowerCase() == 'completed_with_errors') {
        progress = 1.0;
    }


    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius)), // Apply card border radius
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded( // Use Expanded to prevent overflow
                  child: Text("Summary: ${_analysisJob!.jobTitle}", style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8), // Add spacing
                _buildLocalStatusChip(context, _analysisJob!.status),
              ],
            ),
            const SizedBox(height: 10),
            if (_analysisJob!.status.toLowerCase() == 'processing' || (_analysisJob!.status.toLowerCase().contains("error") && progress < 1.0) || (_analysisJob!.status.toLowerCase() == 'completed' && progress < 1.0)) ...[
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                 valueColor: AlwaysStoppedAnimation<Color>(
                    _analysisJob!.status.toLowerCase().contains("error") ? theme.colorScheme.error : theme.colorScheme.primary
                  ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CVs: ${_analysisJob!.cvsProcessedCount} / ${_analysisJob!.totalCVsToProcess}", style: theme.textTheme.bodyMedium),
                Text("Shortlisted: ${_analysisJob!.shortlistedCount}", style: theme.textTheme.bodyMedium?.copyWith(color: AppConfig.accentColor, fontWeight: FontWeight.w500)), // Use accent color
              ],
            ),
            if (_analysisJob!.errorMessage != null && _analysisJob!.errorMessage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.error.withOpacity(0.8), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: ${_analysisJob!.errorMessage}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error.withOpacity(0.9), fontStyle: FontStyle.italic),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
             Text("Last Updated: ${DateFormat.yMMMd().add_jm().format(_analysisJob!.updatedAt ?? _analysisJob!.createdAt)}", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionToolbar(ThemeData theme, List<AnalysisResult> allResults) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isBulkSelectMode ? 60.0 : 0.0, // Animate height
      curve: Curves.easeInOut,
      child: OverflowBox( // Allows children to exceed parent bounds during animation
        maxHeight: 60.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.9), // Slightly more opaque
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text("${_selectedCandidateIds.length} Selected", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              Tooltip(
                message: "Email Interview Invitation",
                child: IconButton(icon: Icon(Icons.mail_outline_rounded, color: AppConfig.accentColor), onPressed: () => _sendBulkEmails(EmailPurpose.invitationToInterview, allResults)), // Pass allResults
              ),
              Tooltip(
                message: "Email Application Under Review",
                child: IconButton(icon: Icon(Icons.hourglass_empty_rounded, color: theme.colorScheme.secondary), onPressed: () => _sendBulkEmails(EmailPurpose.applicationUnderReview, allResults)), // Pass allResults
              ),
              Tooltip(
                message: "Email Not Selected",
                child: IconButton(icon: Icon(Icons.cancel_schedule_send_outlined, color: theme.colorScheme.error), onPressed: () => _sendBulkEmails(EmailPurpose.applicationNotSelected, allResults)), // Pass allResults
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildResultsList(ThemeData theme) {
    return StreamBuilder<List<AnalysisResult>>(
      stream: _firestoreService.getAnalysisResultsStream(widget.analysisJobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _analysisJob != null) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error loading results: ${snapshot.error}", style: TextStyle(color: theme.colorScheme.error))));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No candidate results found for this analysis job yet.")));
        }
        final results = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final candidate = results[index];
            final bool isSelected = _selectedCandidateIds.contains(candidate.id);
            return _buildCandidateCard(theme, candidate, isSelected, results);
          },
        );
      },
    );
  }

  Widget _buildCandidateCard(ThemeData theme, AnalysisResult candidate, bool isSelected, List<AnalysisResult> allResults) {
    Color scoreColor = candidate.matchScore >= 0.8 ? AppConfig.accentColor : candidate.matchScore >= AppConfig.defaultShortlistingThreshold ? AppConfig.warningColor : theme.colorScheme.error;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isSelected ? 6 : 2, // Increased elevation when selected
      color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : theme.cardTheme.color, // Highlight if selected
      child: InkWell(
        onTap: _isBulkSelectMode ? () => _toggleCandidateSelection(candidate.id) : () {
           _showCandidateDetailDialog(context, candidate);
        },
        onLongPress: () {
          setState(() {
            _isBulkSelectMode = true;
            _toggleCandidateSelection(candidate.id);
          });
        },
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (_isBulkSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) => _toggleCandidateSelection(candidate.id),
                  activeColor: theme.colorScheme.primary,
                ),
              if (_isBulkSelectMode) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.candidateName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(candidate.candidateEmail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text("CV: ${candidate.cvFileName}", style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star_half_rounded, color: scoreColor, size: 20),
                        const SizedBox(width: 4),
                        Text("Match: ${(candidate.matchScore * 100).toStringAsFixed(1)}%", style: theme.textTheme.titleMedium?.copyWith(color: scoreColor, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Chip( // Use Chip for Shortlisted status
                          label: Text(candidate.isShortlisted ? "Shortlisted" : "Not Shortlisted", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                          backgroundColor: candidate.isShortlisted ? AppConfig.accentColor.withOpacity(0.2) : theme.colorScheme.surfaceVariant,
                          labelStyle: TextStyle(color: candidate.isShortlisted ? AppConfig.accentColor : theme.colorScheme.onSurfaceVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                     if (candidate.matchSummary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text("Summary: ${candidate.matchSummary}", style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch(
                    value: candidate.isShortlisted,
                    onChanged: (value) => _updateCandidateShortlistStatus(candidate, value),
                    activeColor: AppConfig.accentColor,
                    inactiveThumbColor: theme.colorScheme.outline, // Use outline for inactive thumb
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showCandidateDetailDialog(BuildContext context, AnalysisResult candidate) {
    final theme = Theme.of(context);
    Color scoreColor = candidate.matchScore >= 0.8 ? AppConfig.accentColor : candidate.matchScore >= AppConfig.defaultShortlistingThreshold ? AppConfig.warningColor : theme.colorScheme.error;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(candidate.candidateName, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDialogDetailRow(theme, Icons.email_outlined, "Email", candidate.candidateEmail),
                _buildDialogDetailRow(theme, Icons.insert_drive_file_outlined, "CV File", candidate.cvFileName),
                _buildDialogDetailRow(theme, Icons.star_rate_rounded, "Match Score", "${(candidate.matchScore * 100).toStringAsFixed(1)}%", valueColor: scoreColor),
                const SizedBox(height: 8),
                Text("Match Summary:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                  child: Text(candidate.matchSummary.isNotEmpty ? candidate.matchSummary : "No AI summary available.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 10),
                Text("Extracted Skills:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                candidate.extractedSkills.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                      child: Wrap(spacing: 6, runSpacing: 4, children: candidate.extractedSkills.map((skill) => Chip(label: Text(skill, style: const TextStyle(fontSize: 10)), padding: const EdgeInsets.all(2), visualDensity: VisualDensity.compact)).toList()),
                    )
                  : const Padding(padding: EdgeInsets.only(top: 4.0, left: 4.0), child: Text("No skills extracted.", style: TextStyle(fontStyle: FontStyle.italic))),
                const SizedBox(height: 10),
                 Text("Experience Summary:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                 Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                  child: Text(candidate.extractedExperienceSummary.isNotEmpty ? candidate.extractedExperienceSummary : "No AI experience summary.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text("Shortlisted: ", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    StatefulBuilder(
                      builder: (BuildContext context, StateSetter setStateDialog) {
                        return Switch(
                          value: candidate.isShortlisted,
                          onChanged: (value) async {
                            await _updateCandidateShortlistStatus(candidate, value);
                            setStateDialog(() {
                              candidate.isShortlisted = value;
                            });
                          },
                           activeColor: AppConfig.accentColor,
                        );
                      }
                    ),
                  ],
                ),
                 _buildDialogDetailRow(theme, Icons.send_outlined, "Email Status", candidate.emailSentStatus.capitalizeWords()),

              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogDetailRow(ThemeData theme, IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text("$label: ", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: valueColor ?? theme.colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}