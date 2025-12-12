// 📁 screens/analysis_job_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/analysis_job.dart';
import 'analysis_job_detail_screen.dart';
import '../config/app_config.dart';

extension StringAnalysisJobExtension on String {
  String capitalizeWords() {
    if (trim().isEmpty) return "";
    return trim().split(RegExp(r'[\s_]+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

class AnalysisJobListScreen extends StatefulWidget {
  static const routeName = '/analysisJobList';
  const AnalysisJobListScreen({super.key});

  @override
  State<AnalysisJobListScreen> createState() => _AnalysisJobListScreenState();
}

class _AnalysisJobListScreenState extends State<AnalysisJobListScreen> with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  bool get wantKeepAlive => true;

  Future<void> _deleteAnalysisJob(BuildContext context, AnalysisJob job) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the analysis for "${job.jobTitle}"? This will also delete all ${job.totalCVsToProcess} associated candidate results and cannot be undone.'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true && job.id != null) {
      try {
        await _firestoreService.deleteAnalysisJob(job.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Analysis job "${job.jobTitle}" deleted successfully.'), backgroundColor: Colors.green.shade700),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting analysis job: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    }
  }

  Widget _buildStatusChip(BuildContext context, String status, {bool isSmall = false}) {
    final theme = Theme.of(context);
    Color chipColor;
    Color textColor;
    IconData chipIcon;

    switch (status.toLowerCase()) {
      case 'completed':
        chipColor = Colors.green.shade600; textColor = Colors.white; chipIcon = Icons.check_circle_outline_rounded; break;
      case 'processing':
        chipColor = Colors.blue.shade500; textColor = Colors.white; chipIcon = Icons.hourglass_top_rounded; break;
      case 'processing_with_errors':
        chipColor = Colors.orange.shade600; textColor = Colors.white; chipIcon = Icons.warning_amber_rounded; break;
      case 'completed_with_errors':
        chipColor = Colors.amber.shade700; textColor = Colors.black; chipIcon = Icons.error_outline_rounded; break;
      case 'error':
        chipColor = theme.colorScheme.error; textColor = theme.colorScheme.onError; chipIcon = Icons.dangerous_outlined; break;
      case 'cancelled':
        chipColor = Colors.grey.shade600; textColor = Colors.white; chipIcon = Icons.cancel_outlined; break;
      case 'pending_upload': default:
        chipColor = theme.colorScheme.secondary.withOpacity(0.7); textColor = theme.colorScheme.onSecondary; chipIcon = Icons.upload_file_rounded;
    }

    return Chip(
      avatar: Icon(chipIcon, color: textColor, size: isSmall ? 14 : 16),
      label: Text(
        StringAnalysisJobExtension(status).capitalizeWords(),
        style: TextStyle(fontSize: isSmall ? 10 : 11, color: textColor, fontWeight: FontWeight.w500)
      ),
      backgroundColor: chipColor.withOpacity(0.85),
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 6.0 : 8.0, vertical: isSmall ? 2.0 : 3.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.chipBorderRadius),
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_history_rounded, size: 100, color: theme.colorScheme.primary.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text(
              'No Analysis History',
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.85)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a new CV analysis from a Job Description. Your past and ongoing analyses will appear here.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisJobCard(BuildContext context, AnalysisJob job) {
    final theme = Theme.of(context);
    double progress = 0;
    if (job.totalCVsToProcess > 0) {
      progress = job.cvsProcessedCount / job.totalCVsToProcess;
    } else if (job.status.toLowerCase() == 'completed' || job.status.toLowerCase() == 'completed_with_errors') {
      progress = 1.0;
    }


    return Card(
      child: InkWell(
        onTap: () {
          if (job.id != null) {
            Navigator.pushNamed(context, AnalysisJobDetailScreen.routeName, arguments: job.id!);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Error: Analysis job ID is missing.'), backgroundColor: theme.colorScheme.error),
             );
          }
        },
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.jobTitle,
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.error.withOpacity(0.8)),
                    tooltip: 'Delete Analysis Job',
                    onPressed: () => _deleteAnalysisJob(context, job),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(context, job.status),
                   Text(
                    'CVs: ${job.cvsProcessedCount} / ${job.totalCVsToProcess}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (job.status.toLowerCase() == 'processing' ||
                  (job.status.toLowerCase() == 'processing_with_errors' && progress < 1.0) ||
                  (job.status.toLowerCase() == 'completed_with_errors' && progress < 1.0 && job.totalCVsToProcess > 0) ||
                  (job.status.toLowerCase() == 'completed' && progress < 1.0 && job.totalCVsToProcess > 0)
                 ) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    job.status.toLowerCase().contains("error") ? theme.colorScheme.error : theme.colorScheme.primary
                  ),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                 const SizedBox(height: 4),
                 Align(
                    alignment: Alignment.centerRight,
                    child: Text("${(progress * 100).toStringAsFixed(0)}%", style: theme.textTheme.bodySmall)
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shortlisted: ${job.shortlistedCount}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade600, fontWeight: FontWeight.w500), // Use green.shade600
                  ),
                  Text(
                    'Created: ${DateFormat.yMMMd().add_jm().format(job.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
                  ),
                ],
              ),
              if (job.errorMessage != null && job.errorMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.error.withOpacity(0.8), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: ${job.errorMessage}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error.withOpacity(0.9), fontStyle: FontStyle.italic),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: StreamBuilder<List<AnalysisJob>>(
        stream: _firestoreService.getAnalysisJobsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             print("Error in AnalysisJobListScreen StreamBuilder: ${snapshot.error}");
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: ${snapshot.error.toString()}', style: TextStyle(color: Theme.of(context).colorScheme.error))));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context);
          }
          final analysisJobs = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async { setState(() {}); },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              itemCount: analysisJobs.length,
              itemBuilder: (context, index) {
                 return _buildAnalysisJobCard(context, analysisJobs[index]);
              },
            ),
          );
        },
      ),
    );
  }
}