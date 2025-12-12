// 📁 models/job_description.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class JobDescription {
  final String? id; // Firestore document ID
  final String title;
  final String fullText; // The raw, full text of the job description
  final String userId; // ID of the user who owns this JD

  // Fields to be populated by GeminiService
  String? summary;
  List<String> keyRequirements; // Initialize with empty list
  List<String> responsibilities; // Initialize with empty list
  List<String> requiredSkills; // Initialize with empty list
  String? experienceLevel;

  final DateTime createdAt;
  DateTime? updatedAt;
  String status; // e.g., "active", "closed", "draft"

  JobDescription({
    this.id,
    required this.title,
    required this.fullText,
    required this.userId,
    this.summary,
    List<String>? keyRequirements, // Nullable in constructor
    List<String>? responsibilities,
    List<String>? requiredSkills,
    this.experienceLevel,
    DateTime? createdAt, // Nullable for flexibility, defaults to now
    this.updatedAt,
    this.status = 'active', // Default status
  })  : createdAt = createdAt ?? DateTime.now(),
        keyRequirements = keyRequirements ?? [], // Ensure lists are non-null
        responsibilities = responsibilities ?? [],
        requiredSkills = requiredSkills ?? [];


  factory JobDescription.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) {
      if (kDebugMode) {
        print("JobDescription.fromFirestore: Data is null for snapshot ID: ${snapshot.id}");
      }
      throw Exception("JobDescription data is null in Firestore snapshot!");
    }

    // Helper to safely cast lists
    List<String> _getStringList(dynamic listData) {
      if (listData is List) {
        return listData.map((e) => e.toString()).toList();
      }
      return [];
    }

    return JobDescription(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled Job',
      fullText: data['fullText'] as String? ?? '',
      userId: data['userId'] as String? ?? '', // Should ideally not be empty
      summary: data['summary'] as String?,
      keyRequirements: _getStringList(data['keyRequirements']),
      responsibilities: _getStringList(data['responsibilities']),
      requiredSkills: _getStringList(data['requiredSkills']),
      experienceLevel: data['experienceLevel'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'fullText': fullText,
      'userId': userId,
      // Use FieldValue.delete() for null or empty optional fields to keep Firestore clean
      'summary': summary != null && summary!.isNotEmpty ? summary : FieldValue.delete(),
      'keyRequirements': keyRequirements.isNotEmpty ? keyRequirements : FieldValue.delete(),
      'responsibilities': responsibilities.isNotEmpty ? responsibilities : FieldValue.delete(),
      'requiredSkills': requiredSkills.isNotEmpty ? requiredSkills : FieldValue.delete(),
      'experienceLevel': experienceLevel != null && experienceLevel!.isNotEmpty ? experienceLevel : FieldValue.delete(),
      'createdAt': Timestamp.fromDate(createdAt), // Should always exist
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(), // Use server timestamp for updates
      'status': status,
    };
  }

  // copyWith method for immutable updates
  JobDescription copyWith({
    String? id,
    String? title,
    String? fullText,
    String? userId,
    ValueGetter<String?>? summary, // Use ValueGetter for nullable fields to allow setting to null
    List<String>? keyRequirements,
    List<String>? responsibilities,
    List<String>? requiredSkills,
    ValueGetter<String?>? experienceLevel,
    DateTime? createdAt,
    ValueGetter<DateTime?>? updatedAt,
    String? status,
  }) {
    return JobDescription(
      id: id ?? this.id,
      title: title ?? this.title,
      fullText: fullText ?? this.fullText,
      userId: userId ?? this.userId,
      summary: summary != null ? summary() : this.summary,
      keyRequirements: keyRequirements ?? this.keyRequirements,
      responsibilities: responsibilities ?? this.responsibilities,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      experienceLevel: experienceLevel != null ? experienceLevel() : this.experienceLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
      status: status ?? this.status,
    );
  }
}

