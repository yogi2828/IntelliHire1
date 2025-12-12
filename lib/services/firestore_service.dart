// 📁 services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import '../models/job_description.dart';
import '../models/analysis_job.dart';
import '../models/analysis_result.dart';
import 'auth_service.dart'; // For user ID management

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Helper to get the current authenticated user's ID or throw an exception
  String _getAuthenticatedUserId() {
    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      if (kDebugMode) print("FirestoreService: User not authenticated.");
      throw Exception("User not authenticated. Please log in.");
    }
    return userId;
  }

  // --- Job Description Methods ---

  // Get a stream of Job Descriptions for the current user, ordered by update time
  Stream<List<JobDescription>> getJobDescriptionsStream() {
    try {
      final userId = _getAuthenticatedUserId();
      return _db.collection('jobDescriptions')
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .withConverter<JobDescription>(
            fromFirestore: JobDescription.fromFirestore,
            toFirestore: (JobDescription jd, _) => jd.toFirestore(),
          )
          .snapshots()
          .handleError((error, stackTrace) { // Add stackTrace for better debugging
            if (kDebugMode) print("FirestoreService: Error in getJobDescriptionsStream: $error\n$stackTrace");
            // Return an empty list on error to prevent app crash, but log the error
            return <JobDescription>[];
          })
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    } catch (e) {
       // Catch authentication errors or other sync issues early
       if (kDebugMode) print("FirestoreService: Auth error in getJobDescriptionsStream: $e");
       return Stream.value([]); // Return an empty stream on auth error
    }
  }

  // Add a new Job Description to Firestore
  Future<DocumentReference> addJobDescription(JobDescription jd) async {
    final userId = _getAuthenticatedUserId();
    // Ensure the JD object includes the user ID and timestamps before saving
    final jdWithUser = jd.copyWith(
        userId: userId,
        createdAt: jd.createdAt, // Use existing or default createdAt
        updatedAt: () => DateTime.now() // Set updatedAt to now
    );
    // Ensure all required fields in jdWithUser.toFirestore() are non-null or handled by FieldValue.delete()
    return _db.collection('jobDescriptions').add(jdWithUser.toFirestore());
  }

  // Update an existing Job Description in Firestore
  Future<void> updateJobDescription(JobDescription jd) async {
    final userId = _getAuthenticatedUserId();
    if (jd.id == null) {
      throw Exception("Job Description ID cannot be null for update.");
    }
    // Optional: Server-side check for ownership (good practice, but also rely on security rules)
    // final docSnapshot = await _db.collection('jobDescriptions').doc(jd.id).get();
    // if (!docSnapshot.exists || docSnapshot.data()?['userId'] != userId) {
    //   throw Exception("User not authorized to update this Job Description.");
    // }

    // Create an updated JD object, setting the updatedAt timestamp
    final jdToUpdate = jd.copyWith(updatedAt: () => DateTime.now());
    // Ensure all required fields in jdToUpdate.toFirestore() are non-null or handled by FieldValue.delete()
    return _db.collection('jobDescriptions').doc(jdToUpdate.id).update(jdToUpdate.toFirestore());
  }

  // Delete a Job Description from Firestore
  Future<void> deleteJobDescription(String jdId) async {
    final userId = _getAuthenticatedUserId();
    final docRef = _db.collection('jobDescriptions').doc(jdId);
    // Perform a read before delete to ensure ownership (Firestore security rules are primary defense)
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists || docSnapshot.data()?['userId'] != userId) {
      throw Exception("Job Description not found or user not authorized to delete.");
    }
    return docRef.delete();
  }

  // --- Analysis Job Methods ---

  // Create a new Analysis Job document in Firestore
  Future<DocumentReference<Map<String, dynamic>>> createAnalysisJob(AnalysisJob analysisJob) async {
    final userId = _getAuthenticatedUserId();
    // Ensure the user ID in the provided object matches the authenticated user
    if (userId != analysisJob.userId) {
      throw Exception("User ID mismatch when creating analysis job.");
    }
    // Ensure the analysisJob object passed here has all required fields non-null
    // or that its toFirestore() method handles nulls appropriately (e.g., with FieldValue.delete())
    final jobToCreate = analysisJob.copyWith(
        createdAt: analysisJob.createdAt, // Use existing or default createdAt
        updatedAt: () => DateTime.now() // Set updatedAt to now
    );
     if (kDebugMode) print("FirestoreService: Creating AnalysisJob: ${jobToCreate.toFirestore()}");
    return _db.collection('analysisJobs').add(jobToCreate.toFirestore());
  }

  // Get a stream of Analysis Jobs for the current user, ordered by creation time
  Stream<List<AnalysisJob>> getAnalysisJobsStream() {
     try {
      final userId = _getAuthenticatedUserId();
      return _db.collection('analysisJobs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .withConverter<AnalysisJob>(
            fromFirestore: AnalysisJob.fromFirestore,
            toFirestore: (AnalysisJob job, _) => job.toFirestore(),
          )
          .snapshots()
          .handleError((error, stackTrace) {
            if (kDebugMode) print("FirestoreService: Error in getAnalysisJobsStream: $error\n$stackTrace");
            return <AnalysisJob>[];
          })
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    } catch (e) {
       if (kDebugMode) print("FirestoreService: Auth error in getAnalysisJobsStream: $e");
       return Stream.value([]);
    }
  }

  // Get a specific Analysis Job by its ID
  Future<AnalysisJob?> getAnalysisJob(String analysisJobId) async {
    final userId = _getAuthenticatedUserId();
    final docSnapshot = await _db.collection('analysisJobs').doc(analysisJobId)
        .withConverter<AnalysisJob>(
            fromFirestore: AnalysisJob.fromFirestore,
            toFirestore: (AnalysisJob job, _) => job.toFirestore(),
        ).get();

    if (!docSnapshot.exists) {
        if (kDebugMode) print("FirestoreService: Analysis job $analysisJobId not found.");
        return null;
    }
    final analysisJobData = docSnapshot.data();
    // Verify ownership
    if (analysisJobData != null && analysisJobData.userId != userId) {
      if (kDebugMode) print("FirestoreService: Access denied for AnalysisJob $analysisJobId.");
      throw Exception("User not authorized to access this Analysis Job.");
    }
    return analysisJobData;
  }

  // Update the progress and status of an Analysis Job
  Future<void> updateAnalysisJobProgress(String analysisJobId, {
    int? cvsProcessedIncrement,
    int? shortlistedIncrement,
    String? status,
    String? errorMessageToSet,
    bool clearErrorMessage = false,
  }) async {
    final userId = _getAuthenticatedUserId();
    final jobRef = _db.collection('analysisJobs').doc(analysisJobId);

    // Optional: Verify ownership before updating (rely primarily on security rules)
    // final jobSnapshot = await jobRef.get();
    // if (!jobSnapshot.exists || jobSnapshot.data()?['userId'] != userId) {
    //     throw Exception("Analysis job not found or user not authorized to update progress.");
    // }

    Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp for updates
    };
    if (cvsProcessedIncrement != null && cvsProcessedIncrement != 0) {
      updates['cvsProcessedCount'] = FieldValue.increment(cvsProcessedIncrement.toDouble());
    }
    if (shortlistedIncrement != null && shortlistedIncrement != 0) {
      updates['shortlistedCount'] = FieldValue.increment(shortlistedIncrement.toDouble());
    }
    if (status != null) {
      updates['status'] = status;
    }

    // Handle error message updates
    if (errorMessageToSet != null && errorMessageToSet.isNotEmpty) { // Only set if not empty
      updates['errorMessage'] = errorMessageToSet;
    } else if (clearErrorMessage || (status != null && !status.toLowerCase().contains("error"))) {
      // Clear the error message if explicitly requested or if status indicates no error
      updates['errorMessage'] = FieldValue.delete();
    }

    if (kDebugMode) print("FirestoreService: Updating AnalysisJob $analysisJobId with: $updates");
    return jobRef.update(updates);
  }

  // Delete an Analysis Job and all its associated Analysis Results using a batch write
  Future<void> deleteAnalysisJob(String analysisJobId) async {
    final userId = _getAuthenticatedUserId();
    final jobRef = _db.collection('analysisJobs').doc(analysisJobId);
    // Verify ownership before deleting
    final jobSnapshot = await jobRef.get();
    if (!jobSnapshot.exists || jobSnapshot.data()?['userId'] != userId) {
        throw Exception("Analysis job not found or user not authorized to delete.");
    }

    final WriteBatch batch = _db.batch();
    // Delete all documents in the 'analysisResults' subcollection
    final resultsSnapshot = await jobRef.collection('analysisResults').get();
    for (final docInSubcollection in resultsSnapshot.docs) {
      batch.delete(docInSubcollection.reference);
    }
    // Delete the main Analysis Job document
    batch.delete(jobRef);

    try {
        await batch.commit();
        if (kDebugMode) print("FirestoreService: Successfully deleted AnalysisJob $analysisJobId and its results.");
    } catch (e, stackTrace) {
        if (kDebugMode) print("FirestoreService: Error batch deleting AnalysisJob $analysisJobId: $e\n$stackTrace");
        throw Exception("Failed to delete analysis job and its results: $e");
    }
  }

  // --- Analysis Result Methods ---

  // Add a new Analysis Result to the subcollection of an Analysis Job
  Future<DocumentReference> addAnalysisResult(String analysisJobId, AnalysisResult result) async {
    final userId = _getAuthenticatedUserId();
    // Verify that the parent Analysis Job exists and belongs to the user
    final parentJobDoc = await _db.collection('analysisJobs').doc(analysisJobId).get();
    if (!parentJobDoc.exists || parentJobDoc.data()?['userId'] != userId) {
        throw Exception("User not authorized to add results to AnalysisJob $analysisJobId or job does not exist.");
    }

    // Ensure the result object is valid before sending to Firestore
    // The toFirestore() method in AnalysisResult should handle nulls for optional fields.
    final resultWithJobId = result.copyWith(analysisJobId: analysisJobId);
    if (kDebugMode) print("FirestoreService: Adding AnalysisResult: ${resultWithJobId.toFirestore()} to job $analysisJobId");

    try {
        return _db.collection('analysisJobs').doc(analysisJobId)
                 .collection('analysisResults')
                 .add(resultWithJobId.toFirestore());
    } catch (e, stackTrace) {
        if (kDebugMode) {
            print("FirestoreService: Error adding AnalysisResult to job $analysisJobId: $e\n$stackTrace");
            print("Data attempted to save: ${resultWithJobId.toFirestore()}");
        }
        // Rethrow a more specific error or handle it
        throw Exception("Failed to save analysis result to Firestore: ${e.toString()}");
    }
  }

  // Get a stream of Analysis Results for a specific Analysis Job, ordered by match score
  Stream<List<AnalysisResult>> getAnalysisResultsStream(String analysisJobId) {
    try {
      _getAuthenticatedUserId(); // Ensure user is authenticated before attempting to get stream
    } catch (e) {
      if (kDebugMode) print("FirestoreService: Auth error in getAnalysisResultsStream: $e");
      return Stream.value([]); // Return empty stream on auth error
    }

    return _db.collection('analysisJobs').doc(analysisJobId)
        .collection('analysisResults')
        .orderBy('matchScore', descending: true)
        .withConverter<AnalysisResult>(
          fromFirestore: AnalysisResult.fromFirestore,
          toFirestore: (AnalysisResult res, _) => res.toFirestore(),
        )
        .snapshots()
        .handleError((error, stackTrace) {
          if (kDebugMode) print("FirestoreService: Error in getAnalysisResultsStream for $analysisJobId: $error\n$stackTrace");
          return <AnalysisResult>[];
        })
        .map((snapshot) => snapshot.docs.map((doc) => doc.data().copyWith(id: doc.id)).toList());
  }

  // Update an existing Analysis Result
  Future<void> updateAnalysisResult(String analysisJobId, AnalysisResult result) async {
    final userId = _getAuthenticatedUserId();
    if (result.id.isEmpty) {
      throw Exception("AnalysisResult ID cannot be empty for update.");
    }
    // Verify that the parent Analysis Job exists and belongs to the user
    final parentJobDoc = await _db.collection('analysisJobs').doc(analysisJobId).get();
    if (!parentJobDoc.exists || parentJobDoc.data()?['userId'] != userId) {
        throw Exception("User not authorized to update results for AnalysisJob $analysisJobId or job does not exist.");
    }

    if (kDebugMode) print("FirestoreService: Updating AnalysisResult ${result.id} with: ${result.toFirestore()}");
    await _db.collection('analysisJobs').doc(analysisJobId)
             .collection('analysisResults').doc(result.id)
             .update(result.toFirestore());

    // After updating a result, recalculate the shortlisted count for the parent job
    await _recalculateAnalysisJobShortlistedCount(analysisJobId);
  }

  // Recalculate and update the shortlisted count for an Analysis Job
  Future<void> _recalculateAnalysisJobShortlistedCount(String analysisJobId) async {
    try {
        final resultsSnapshot = await _db.collection('analysisJobs').doc(analysisJobId)
                                     .collection('analysisResults')
                                     .where('isShortlisted', isEqualTo: true)
                                     .get();

        await _db.collection('analysisJobs').doc(analysisJobId).update({
          'shortlistedCount': resultsSnapshot.docs.length,
          'updatedAt': FieldValue.serverTimestamp(), // Update job timestamp
        });
    } catch (e, stackTrace) {
        if (kDebugMode) print("FirestoreService: Error updating shortlisted count for $analysisJobId: $e\n$stackTrace");
    }
  }

  // --- Email Related Methods (Used by EmailService) ---

  // Get a list of candidates for emailing based on their shortlisted status
  Future<List<AnalysisResult>> getCandidatesForEmailing(String analysisJobId, {required bool shortlistedStatus}) async {
    final userId = _getAuthenticatedUserId();
    // Verify ownership of the parent job
    final parentJob = await getAnalysisJob(analysisJobId);
    if (parentJob == null) {
      if (kDebugMode) print("FirestoreService: Unauthorized or job not found for getCandidatesForEmailing: $analysisJobId");
      return []; // Return empty list if job not found or unauthorized
    }
    final snapshot = await _db.collection('analysisJobs').doc(analysisJobId)
        .collection('analysisResults')
        .where('isShortlisted', isEqualTo: shortlistedStatus)
        .withConverter<AnalysisResult>(
          fromFirestore: AnalysisResult.fromFirestore,
          toFirestore: (AnalysisResult res, _) => res.toFirestore(),
        )
        .get();
    // Return a list of AnalysisResult objects, ensuring IDs are included
    return snapshot.docs.map((doc) => doc.data().copyWith(id: doc.id)).toList();
  }

  // Batch update the email status and potentially interview requested status for multiple candidates
  Future<void> batchUpdateEmailStatus(String analysisJobId, List<String> resultIds, String newEmailStatus, {bool? setInterviewRequested}) async {
    final userId = _getAuthenticatedUserId();
    if (resultIds.isEmpty) return; // Nothing to update

    // Verify ownership of the parent job
    final parentJob = await getAnalysisJob(analysisJobId);
    if (parentJob == null) {
      throw Exception("Unauthorized or job not found for batchUpdateEmailStatus: $analysisJobId");
    }

    WriteBatch batch = _db.batch();
    for (String resultId in resultIds) {
      final docRef = _db.collection('analysisJobs').doc(analysisJobId).collection('analysisResults').doc(resultId);
      Map<String, dynamic> updateData = {'emailSentStatus': newEmailStatus};
      if (setInterviewRequested != null) {
        updateData['interviewRequested'] = setInterviewRequested;
      }
      batch.update(docRef, updateData);
    }
    try {
        await batch.commit();
        if (kDebugMode) print("FirestoreService: Batch email status update successful for ${resultIds.length} candidates in job $analysisJobId.");
    } catch (e, stackTrace) {
        if (kDebugMode) print("FirestoreService: Error committing batch email status update for job $analysisJobId: $e\n$stackTrace");
        throw Exception("Failed to batch update email statuses: $e");
    }
  }
}