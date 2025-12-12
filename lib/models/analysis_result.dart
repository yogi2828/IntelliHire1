import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:recruitswift/config/app_config.dart';

class AnalysisResult {
  final String id;
  final String analysisJobId;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final String cvFileName;
  final String? cvFileUrl; // This will be set to null if local saving is removed
  final List<String> extractedSkills;
  final String extractedExperienceSummary;
  final double matchScore;
  final String matchSummary;
  bool isShortlisted;
  bool interviewRequested;
  String emailSentStatus;
  final DateTime analyzedAt;
  String? notes;

  AnalysisResult({
    required this.id,
    required this.analysisJobId,
    required this.candidateId,
    this.candidateName = 'Unknown Candidate',
    this.candidateEmail = 'no_email@example.com',
    required this.cvFileName,
    this.cvFileUrl, // Made explicitly nullable
    List<String>? extractedSkills,
    this.extractedExperienceSummary = 'AI summary not available.',
    required this.matchScore,
    this.matchSummary = 'AI match explanation not available.',
    bool? isShortlisted,
    this.interviewRequested = false,
    this.emailSentStatus = 'pending_action',
    DateTime? analyzedAt,
    this.notes,
  }) : extractedSkills = extractedSkills ?? [],
       analyzedAt = analyzedAt ?? DateTime.now(),
       this.isShortlisted = isShortlisted ?? (matchScore >= AppConfig.defaultShortlistingThreshold);


  factory AnalysisResult.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
     if (data == null) {
      if (kDebugMode) print("AnalysisResult.fromFirestore: Data is null for snapshot ID: ${snapshot.id}");
      throw Exception("AnalysisResult data is null in Firestore snapshot!");
    }

    List<String> _getStringList(dynamic listData) {
      if (listData is List) {
        return listData.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      return [];
    }
    double score = (data['matchScore'] as num?)?.toDouble() ?? 0.0;

    return AnalysisResult(
      id: snapshot.id,
      analysisJobId: data['analysisJobId'] as String? ?? '',
      candidateId: data['candidateId'] as String? ?? snapshot.id,
      candidateName: data['candidateName'] as String? ?? 'Unknown Candidate',
      candidateEmail: data['candidateEmail'] as String? ?? 'no_email@example.com',
      cvFileName: data['cvFileName'] as String? ?? 'N/A',
      cvFileUrl: data['cvFileUrl'] as String?, // Remains nullable
      extractedSkills: _getStringList(data['extractedSkills']),
      extractedExperienceSummary: data['extractedExperienceSummary'] as String? ?? 'AI summary not available.',
      matchScore: score,
      matchSummary: data['matchSummary'] as String? ?? 'AI match explanation not available.',
      isShortlisted: data['isShortlisted'] as bool? ?? (score >= AppConfig.defaultShortlistingThreshold),
      interviewRequested: data['interviewRequested'] as bool? ?? false,
      emailSentStatus: data['emailSentStatus'] as String? ?? 'pending_action',
      analyzedAt: (data['analyzedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'analysisJobId': analysisJobId,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'cvFileName': cvFileName,
      'extractedExperienceSummary': extractedExperienceSummary,
      'matchScore': matchScore.clamp(0.0, 1.0),
      'matchSummary': matchSummary,
      'isShortlisted': isShortlisted,
      'interviewRequested': interviewRequested,
      'emailSentStatus': emailSentStatus,
      'analyzedAt': Timestamp.fromDate(analyzedAt),
    };
    // Handle optional fields correctly: omit if null/empty, or use FieldValue.delete for updates if needed.
    // For 'add' operations, omitting is preferred over FieldValue.delete().
    if (cvFileUrl != null && cvFileUrl!.isNotEmpty) {
      data['cvFileUrl'] = cvFileUrl;
    }
    if (extractedSkills.isNotEmpty) {
      data['extractedSkills'] = extractedSkills;
    }
    if (notes != null && notes!.isNotEmpty) {
      data['notes'] = notes;
    }
    return data;
  }

  AnalysisResult copyWith({
    String? id,
    String? analysisJobId,
    String? candidateId,
    String? candidateName,
    String? candidateEmail,
    String? cvFileName,
    ValueGetter<String?>? cvFileUrl, // Use ValueGetter to allow setting to null
    List<String>? extractedSkills,
    String? extractedExperienceSummary,
    double? matchScore,
    String? matchSummary,
    bool? isShortlisted,
    bool? interviewRequested,
    String? emailSentStatus,
    DateTime? analyzedAt,
    ValueGetter<String?>? notes, // Use ValueGetter to allow setting to null
  }) {
    final newMatchScore = matchScore ?? this.matchScore;
    final newIsShortlisted = isShortlisted ?? (newMatchScore >= AppConfig.defaultShortlistingThreshold);

    return AnalysisResult(
      id: id ?? this.id,
      analysisJobId: analysisJobId ?? this.analysisJobId,
      candidateId: candidateId ?? this.candidateId,
      candidateName: candidateName ?? this.candidateName,
      candidateEmail: candidateEmail ?? this.candidateEmail,
      cvFileName: cvFileName ?? this.cvFileName,
      cvFileUrl: cvFileUrl != null ? cvFileUrl() : this.cvFileUrl,
      extractedSkills: extractedSkills ?? List.from(this.extractedSkills),
      extractedExperienceSummary: extractedExperienceSummary ?? this.extractedExperienceSummary,
      matchScore: newMatchScore,
      matchSummary: matchSummary ?? this.matchSummary,
      isShortlisted: newIsShortlisted,
      interviewRequested: interviewRequested ?? this.interviewRequested,
      emailSentStatus: emailSentStatus ?? this.emailSentStatus,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      notes: notes != null ? notes() : this.notes,
    );
  }
}