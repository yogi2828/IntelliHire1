// 📁 screens/jd_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:recruitswift/models/job_description.dart';
import 'package:recruitswift/services/firestore_service.dart';
import 'package:recruitswift/screens/add_edit_jd_screen.dart';
import 'package:recruitswift/screens/jd_detail_screen.dart';
import 'package:recruitswift/config/app_config.dart';

class JDListScreen extends StatefulWidget {
  static const routeName = '/jdList';
  const JDListScreen({super.key});

  @override
  State<JDListScreen> createState() => _JDListScreenState();
}

class _JDListScreenState extends State<JDListScreen> with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  bool get wantKeepAlive => true;

  Future<void> _deleteJobDescription(BuildContext context, JobDescription jd) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the job description for "${jd.title}"? This action cannot be undone and might affect related analyses if not handled carefully.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false)
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true && jd.id != null) {
      try {
        await _firestoreService.deleteJobDescription(jd.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job Description "${jd.title}" deleted.'),
              backgroundColor: Colors.green.shade700,
            )
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting JD: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
          );
        }
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add_rounded, size: 100, color: theme.colorScheme.primary.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text(
              'No Job Descriptions Yet',
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.85)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Tap the "Add JD" button below to create your first job description and start leveraging AI for your recruitment!',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Create First JD'),
              onPressed: () {
                 Navigator.pushNamed(context, AddEditJDScreen.routeName);
              },
              style: theme.elevatedButtonTheme.style?.copyWith(
                padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              )
            )
          ],
        ),
      ),
    );
  }

  Widget _buildJDCard(BuildContext context, JobDescription jd) {
    final theme = Theme.of(context);
    Color statusColor;
    IconData statusIcon;
    switch (jd.status.toLowerCase()) {
      case 'active':
        statusColor = Colors.green.shade400; statusIcon = Icons.play_circle_outline_rounded; break;
      case 'closed':
        statusColor = Colors.red.shade400; statusIcon = Icons.pause_circle_outline_rounded; break;
      case 'draft':
      default:
        statusColor = Colors.orange.shade400; statusIcon = Icons.pending_actions_rounded;
    }

    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, JDDetailScreen.routeName, arguments: jd),
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
                      jd.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error.withOpacity(0.8)),
                    tooltip: 'Delete JD',
                    onPressed: () => _deleteJobDescription(context, jd),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                jd.summary != null && jd.summary!.isNotEmpty
                    ? jd.summary!
                    : (jd.fullText.length > 120 ? '${jd.fullText.substring(0, 120)}...' : jd.fullText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8), height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                       Chip(
                        avatar: Icon(statusIcon, size: 16, color: statusColor),
                        label: Text(jd.status.toUpperCase(), style: theme.chipTheme.labelStyle?.copyWith(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        backgroundColor: statusColor.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConfig.chipBorderRadius),
                          side: BorderSide(color: statusColor.withOpacity(0.3))
                        ),
                      ),
                      if (jd.experienceLevel != null && jd.experienceLevel!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Chip(
                          avatar: Icon(Icons.leaderboard_outlined, size: 16, color: theme.chipTheme.iconTheme?.color ?? theme.colorScheme.primary),
                          label: Text(jd.experienceLevel!, style: theme.chipTheme.labelStyle?.copyWith(fontSize: 11)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          backgroundColor: theme.chipTheme.backgroundColor?.withOpacity(0.7),
                        ),
                      ]
                    ],
                  ),
                  Text(
                    'Created: ${DateFormat.yMMMd().format(jd.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                  ),
                ],
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
      body: StreamBuilder<List<JobDescription>>(
        stream: _firestoreService.getJobDescriptionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error in JDListScreen StreamBuilder: ${snapshot.error}");
            return Center(child: Text('Error loading JDs: ${snapshot.error?.toString()}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context);
          }

          final jds = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
              itemCount: jds.length,
              itemBuilder: (context, index) {
                final jd = jds[index];
                return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _buildJDCard(context, jd),
                );
              },
            ),
          );
        },
      ),
    );
  }
}