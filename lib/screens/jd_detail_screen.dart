// 📁 screens/jd_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:recruitswift/config/app_config.dart';
import '../models/job_description.dart';
import 'new_analysis_setup_screen.dart';
import 'add_edit_jd_screen.dart';
import '../services/auth_service.dart';

class JDDetailScreen extends StatefulWidget {
  static const routeName = '/jdDetail';
  final JobDescription jobDescription;

  const JDDetailScreen({super.key, required this.jobDescription});

  @override
  State<JDDetailScreen> createState() => _JDDetailScreenState();
}

class _JDDetailScreenState extends State<JDDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildDetailSection(BuildContext context, String title, String? content, {IconData? icon, bool isSummary = false}) {
    if (content == null || content.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: theme.colorScheme.primary, size: 22),
              if (icon != null) const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSummary ? theme.colorScheme.surfaceVariant.withOpacity(0.7) : theme.colorScheme.surfaceVariant.withOpacity(0.4), // Use surfaceVariant
              borderRadius: BorderRadius.circular(AppConfig.inputBorderRadius - 2),
            ),
            child: Text(
              content.trim(),
              style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(isSummary ? 0.95 : 0.85), // Use onSurfaceVariant
                    fontStyle: isSummary ? FontStyle.italic : FontStyle.normal,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailListSection(BuildContext context, String title, List<String> items, {IconData? icon}) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: theme.colorScheme.primary, size: 22),
              if (icon != null) const SizedBox(width: 8),
              Text(
                title,
                 style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right_alt_rounded, size: 20, color: theme.colorScheme.primary.withOpacity(0.8)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.trim(), style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.colorScheme.onBackground.withOpacity(0.9)))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final JobDescription currentJobDescription = widget.jobDescription;
    final bool canEdit = authService.getCurrentUserId() == currentJobDescription.userId;
    final theme = Theme.of(context);

    Color statusChipColor;
    IconData statusChipIcon;
    switch (currentJobDescription.status.toLowerCase()) {
        case 'active': statusChipColor = Colors.green.shade600; statusChipIcon = Icons.play_circle_fill_rounded; break;
        case 'closed': statusChipColor = Colors.red.shade600; statusChipIcon = Icons.pause_circle_filled_rounded; break;
        case 'draft': default: statusChipColor = Colors.orange.shade600; statusChipIcon = Icons.edit_note_rounded; break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentJobDescription.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_calendar_outlined),
              tooltip: 'Edit Job Description',
              onPressed: () async {
                final updatedJd = await Navigator.pushNamed(
                  context,
                  AddEditJDScreen.routeName,
                  arguments: currentJobDescription
                );
                if (updatedJd is JobDescription && mounted) {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    JDDetailScreen.routeName,
                    arguments: updatedJd
                  );
                }
              }
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              currentJobDescription.title,
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10.0,
              runSpacing: 8.0,
              children: [
                Chip(
                  label: Text(currentJobDescription.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                   backgroundColor: statusChipColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusChipColor),
                  avatar: Icon(statusChipIcon, size: 18, color: statusChipColor),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConfig.chipBorderRadius),
                    side: BorderSide(color: statusChipColor.withOpacity(0.4))
                  )
                ),
                if (currentJobDescription.experienceLevel != null && currentJobDescription.experienceLevel!.isNotEmpty)
                  Chip(
                    label: Text(currentJobDescription.experienceLevel!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.secondary)),
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
                    avatar: Icon(Icons.signal_cellular_alt_rounded, size: 18, color: theme.colorScheme.secondary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                     shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConfig.chipBorderRadius),
                      side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.3))
                    )
                  ),
              ],
            ),
            const SizedBox(height: 24),

            if (currentJobDescription.summary != null && currentJobDescription.summary!.isNotEmpty)
              _buildDetailSection(context, "AI Generated Summary", currentJobDescription.summary, icon: Icons.psychology_outlined, isSummary: true),

            _buildDetailListSection(context, 'Key Requirements', currentJobDescription.keyRequirements, icon: Icons.checklist_rtl_rounded),
            _buildDetailListSection(context, 'Primary Responsibilities', currentJobDescription.responsibilities, icon: Icons.work_history_outlined),
            _buildDetailListSection(context, 'Required Skills', currentJobDescription.requiredSkills, icon: Icons.construction_outlined),

            _buildDetailSection(context, 'Full Original Description', currentJobDescription.fullText, icon: Icons.notes_outlined),

            const SizedBox(height: 24),
            Divider(color: theme.colorScheme.outline.withOpacity(0.5)), // Use outline color
            const SizedBox(height: 12),
            Text(
              'Created: ${DateFormat.yMMMd().add_jm().format(currentJobDescription.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.65)),
            ),
            if (currentJobDescription.updatedAt != null && currentJobDescription.updatedAt!.isAfter(currentJobDescription.createdAt))
              Text(
                'Last Updated: ${DateFormat.yMMMd().add_jm().format(currentJobDescription.updatedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.65)),
              ),
          ],
        ),
      ),
      floatingActionButton: currentJobDescription.status.toLowerCase() == 'active' || currentJobDescription.status.toLowerCase() == 'draft'
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(
                context,
                NewAnalysisSetupScreen.routeName,
                arguments: currentJobDescription,
              );
            },
            label: const Text('Start New CV Analysis'),
            icon: const Icon(Icons.batch_prediction_outlined),
          )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}