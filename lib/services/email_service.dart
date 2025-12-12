// 📁 services/email_service.dart
import 'package:flutter/foundation.dart'; // For kDebugMode
import '../models/analysis_result.dart';
import '../config/app_config.dart'; // For company name and careers URL

// Enum to define different types of emails that can be sent
enum EmailPurpose {
  invitationToInterview,    // For shortlisted candidates
  applicationUnderReview,   // For candidates not yet shortlisted but not rejected
  applicationNotSelected,   // For rejected candidates
  customCommunication       // For generic or ad-hoc messages (template might be passed)
}

class EmailService {
  // Simulates sending emails.
  // In a real production app, this should be replaced with a secure backend service
  // (e.g., Firebase Functions with Nodemailer, SendGrid API, Mailgun API)
  // to avoid exposing API keys or sending emails directly from the client app.
  Future<Map<String, String>> sendEmailsToCandidates({
    required List<AnalysisResult> candidates,
    required String jobTitle,
    required EmailPurpose emailPurpose,
    String? customSubject, // Optional for custom emails
    String? customBodyTemplate, // Optional for custom emails, use placeholders like {{candidateName}}
  }) async {
    final String companyName = AppConfig.companyName;
    final String companyCareersUrl = AppConfig.companyCareersUrl;

    if (kDebugMode) {
      print("📧 EmailService: Preparing to send ${candidates.length} email(s) of type '$emailPurpose' for job: '$jobTitle' at $companyName.");
    }
    // Map to store the status of each email attempt (candidate.id -> status)
    Map<String, String> emailStatuses = {}; // e.g., "sent", "failed_missing_info", "failed_send_error"

    if (candidates.isEmpty) {
      if (kDebugMode) print("📧 EmailService: No candidates to email for type '$emailPurpose'.");
      return emailStatuses;
    }

    for (var candidate in candidates) {
      // Basic validation for candidate email address
      if (candidate.candidateEmail.isEmpty ||
          !candidate.candidateEmail.contains('@') || // Simple check
          candidate.candidateEmail == 'email_not_found@example.com' || // Check against default placeholders
          candidate.candidateEmail == 'no_email@example.com') {
        if (kDebugMode) print("📧 EmailService: Skipping candidate ${candidate.candidateName} (ID: ${candidate.id}) due to missing/invalid email ('${candidate.candidateEmail}') for type '$emailPurpose'.");
        emailStatuses[candidate.id] = 'failed_missing_info'; // Record failure reason
        continue; // Skip to the next candidate
      }

      String emailSubject;
      String emailBody;

      // Generate email content based on the purpose
      switch (emailPurpose) {
        case EmailPurpose.invitationToInterview:
          emailSubject = "Interview Invitation: $jobTitle at $companyName";
          emailBody = """
Dear ${candidate.candidateName},

We were very impressed with your application for the $jobTitle position at $companyName. Your profile aligns well with what we are looking for.

We would like to invite you to the next stage of our recruitment process, which will be an interview to discuss your background and the role in more detail. Our team will reach out shortly with scheduling options. Please prepare to discuss your experience related to our key requirements.

We look forward to speaking with you.

Best regards,
The Hiring Team
$companyName
""";
          break;
        case EmailPurpose.applicationUnderReview:
          emailSubject = "Update on your application for $jobTitle at $companyName";
          emailBody = """
Dear ${candidate.candidateName},

Thank you for your interest in the $jobTitle position at $companyName and for taking the time to apply.

Your application is currently under careful review by our hiring team. We have received a large number of qualified applications, and the selection process is ongoing. We appreciate your patience and will update you on the status of your application as soon as possible.

Thank you for your understanding.

Best regards,
The Hiring Team
$companyName
""";
          break;
        case EmailPurpose.applicationNotSelected:
          emailSubject = "Regarding your application for $jobTitle at $companyName";
          emailBody = """
Dear ${candidate.candidateName},

Thank you for your interest in the $jobTitle position at $companyName and for taking the time to apply.

While your qualifications are commendable, we have decided to move forward with other candidates whose profiles more closely match the specific requirements of this role at this time. This was a competitive search, and the decision was difficult due to the high caliber of applicants.

We encourage you to visit our careers page at $companyCareersUrl for future openings that may suit your profile.

We wish you the best in your job search.

Best regards,
The Hiring Team
$companyName
""";
          break;
        case EmailPurpose.customCommunication:
          // For custom emails, ensure subject and body template are provided
          if (customSubject == null || customBodyTemplate == null) {
             if (kDebugMode) print("📧 EmailService: Custom email requested but subject or body template is missing for candidate ${candidate.id}.");
             emailStatuses[candidate.id] = 'failed_missing_template';
             continue;
          }
          // Replace placeholders in custom template
          emailSubject = customSubject.replaceAll('{{jobTitle}}', jobTitle).replaceAll('{{companyName}}', companyName);
          emailBody = customBodyTemplate.replaceAll('{{candidateName}}', candidate.candidateName)
                                       .replaceAll('{{jobTitle}}', jobTitle)
                                       .replaceAll('{{companyName}}', companyName)
                                       .replaceAll('{{careersUrl}}', companyCareersUrl);
          break;
      }

      // Simulate the email sending process
      if (kDebugMode) {
        print("📧 EmailService: Simulating sending '$emailPurpose' email to: ${candidate.candidateEmail} for candidate ID: ${candidate.id}");
        // Uncomment the lines below to see the simulated email content in debug console
        // print("Subject: $emailSubject");
        // print("Body:\n$emailBody");
      }

      // Simulate a small, variable network delay
      await Future.delayed(Duration(milliseconds: 100 + DateTime.now().millisecond % 150));
      // Simulate a potential failure (e.g., 10% chance of failure)
      bool emailSentSuccessfully = (DateTime.now().millisecond % 10) != 0;

      if (emailSentSuccessfully) {
        if (kDebugMode) print("✅ EmailService: Successfully 'sent' $emailPurpose email to ${candidate.candidateName} (ID: ${candidate.id}).");
        emailStatuses[candidate.id] = 'sent'; // Record success
      } else {
        if (kDebugMode) print("❌ EmailService: Failed to 'send' $emailPurpose email to ${candidate.candidateName} (ID: ${candidate.id}) due to simulated send error.");
        emailStatuses[candidate.id] = 'failed_send_error'; // Record failure
      }
    }

    if (kDebugMode) print("📧 EmailService: Finished processing '$emailPurpose' email batch for '$jobTitle'. Statuses: $emailStatuses");
    return emailStatuses; // Return the map of statuses
  }
}