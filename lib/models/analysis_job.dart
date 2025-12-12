// 📁 models/analysis_job.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class AnalysisJob {
  final String? id;
  final String jdId;
  final String jobTitle;
  final String userId;
  final DateTime createdAt;
  DateTime? updatedAt;
  String status;
  int totalCVsToProcess;
  int cvsProcessedCount;
  int shortlistedCount;
  String? errorMessage;

  AnalysisJob({
    this.id,
    required this.jdId,
    required this.jobTitle,
    required this.userId,
    DateTime? createdAt,
    this.updatedAt,
    this.status = 'pending_upload',
    this.totalCVsToProcess = 0,
    this.cvsProcessedCount = 0,
    this.shortlistedCount = 0,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AnalysisJob.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) {
      if (kDebugMode) print("AnalysisJob.fromFirestore: Data is null for snapshot ID: ${snapshot.id}");
      throw Exception("AnalysisJob data is null in Firestore snapshot!");
    }

    return AnalysisJob(
      id: snapshot.id,
      jdId: data['jdId'] as String? ?? '',
      jobTitle: data['jobTitle'] as String? ?? 'Untitled Job Analysis',
      userId: data['userId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'pending_upload',
      totalCVsToProcess: (data['totalCVsToProcess'] as num?)?.toInt() ?? 0,
      cvsProcessedCount: (data['cvsProcessedCount'] as num?)?.toInt() ?? 0,
      shortlistedCount: (data['shortlistedCount'] as num?)?.toInt() ?? 0,
      errorMessage: data['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'jdId': jdId,
      'jobTitle': jobTitle,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'status': status,
      'totalCVsToProcess': totalCVsToProcess,
      'cvsProcessedCount': cvsProcessedCount,
      'shortlistedCount': shortlistedCount,
    };
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      data['errorMessage'] = errorMessage;
    }
    return data;
  }

  AnalysisJob copyWith({
    String? id,
    String? jdId,
    String? jobTitle,
    String? userId,
    DateTime? createdAt,
    ValueGetter<DateTime?>? updatedAt,
    String? status,
    int? totalCVsToProcess,
    int? cvsProcessedCount,
    int? shortlistedCount,
    ValueGetter<String?>? errorMessage,
  }) {
    return AnalysisJob(
      id: id ?? this.id,
      jdId: jdId ?? this.jdId,
      jobTitle: jobTitle ?? this.jobTitle,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
      status: status ?? this.status,
      totalCVsToProcess: totalCVsToProcess ?? this.totalCVsToProcess,
      cvsProcessedCount: cvsProcessedCount ?? this.cvsProcessedCount,
      shortlistedCount: shortlistedCount ?? this.shortlistedCount,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}