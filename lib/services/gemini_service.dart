// 📁 services/gemini_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:recruitswift/config/app_config.dart';

class GeminiService {
  // List of API keys to rotate through for potentially better rate limit handling
  final List<String> _apiKeys = AppConfig.geminiApiKeys;
  int _apiKeyIndex = 0;

  // Gets the next API key in a round-robin fashion
  String _getNextApiKey() {
    if (!AppConfig.isGeminiApiKeyConfigured() || _apiKeys.isEmpty) {
      if (kDebugMode) print("GEMINI SERVICE FATAL: API Key is not configured or is a placeholder.");
      throw Exception("Gemini API Key not configured. Cannot make API calls.");
    }
    final key = _apiKeys[_apiKeyIndex];
    _apiKeyIndex = (_apiKeyIndex + 1) % _apiKeys.length; // Move to the next index
    if (kDebugMode) print("GeminiService: Using API Key index: $_apiKeyIndex");
    return key;
  }

  // Gets a GenerativeModel instance using the next available API key
  GenerativeModel _getModel() {
    final apiKey = _getNextApiKey();
    // Using a fast model suitable for text processing
    return GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);
  }

  // Safely parses the JSON response from the Generative AI model
  Map<String, dynamic> _parseGenerativeAiResponse(String rawText, String contextForErrorMessage) {
    String cleanedJson = rawText.trim();
    // Attempt to remove common markdown code block wrappers
    if (cleanedJson.startsWith("```json")) {
      cleanedJson = cleanedJson.substring(7);
      if (cleanedJson.endsWith("```")) cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
    } else if (cleanedJson.startsWith("```")) {
        cleanedJson = cleanedJson.substring(3);
        if (cleanedJson.endsWith("```")) cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
    }
    cleanedJson = cleanedJson.trim(); // Trim again after removing wrappers

    try {
      final decoded = jsonDecode(cleanedJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      // If decoded is not a Map, it's not the expected JSON structure
      throw FormatException("Parsed JSON structure is not a Map for $contextForErrorMessage.");
    } catch (e) {
      // Log detailed error information during development
      if (kDebugMode) print("GeminiService: ($contextForErrorMessage) Error decoding JSON: $e. Raw: '$rawText'. Cleaned: '$cleanedJson'");
      // Re-throw a more user-friendly exception
      throw FormatException("Failed to parse AI response for $contextForErrorMessage. Invalid JSON format. Details: ${e.toString()}");
    }
  }

  // Processes raw job description text to extract structured information
  Future<Map<String, dynamic>> processJobDescriptionText(String jdText) async {
    // Check if API key is configured before making the call
    if (!AppConfig.isGeminiApiKeyConfigured()) {
      // Return a map with an error key and default empty values
      return {
        'error': 'API Key not configured',
        'summary': null,
        'keyRequirements': [],
        'responsibilities': [],
        'requiredSkills': [],
        'experienceLevel': null,
      };
    }
    try {
      final model = _getModel();
      // Construct the prompt for JD analysis, specifying the desired JSON output format
      final prompt = [Content.text(
          'Analyze the following job description text. Extract the following information in a valid JSON format: '
          '1. "summary": A concise summary of the job role (2-4 sentences). '
          '2. "keyRequirements": A list of 5-10 essential qualifications, skills, and experience (e.g., "5+ years Java", "BSc Computer Science"). '
          '3. "responsibilities": A list of 5-10 primary job duties and tasks. '
          '4. "requiredSkills": A list of 5-15 specific technical and soft skills mentioned. '
          '5. "experienceLevel": Suggested experience level (e.g., "Entry Level", "Mid-Senior Level", "Senior Level", "Lead", "Principal"). '
          '\n--- Job Description Text --- \n$jdText'
          '\n--- End of Job Description Text ---'
          '\nProvide ONLY the JSON object in your response, without any surrounding text, comments, or markdown formatting (e.g., ```json ... ```). The JSON should be directly parsable.'
      )];
      final response = await model.generateContent(prompt);

      // Check if the response contains text and is not empty
      if (response.text != null && response.text!.trim().isNotEmpty) {
        // Parse the JSON response
        final decodedResponse = _parseGenerativeAiResponse(response.text!, "JD Processing");
        // Return the extracted data, handling potential nulls or incorrect types
        return {
          'summary': decodedResponse['summary'] as String?,
          // Safely cast lists and filter out empty strings
          'keyRequirements': (decodedResponse['keyRequirements'] as List<dynamic>?)?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList() ?? [],
          'responsibilities': (decodedResponse['responsibilities'] as List<dynamic>?)?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList() ?? [],
          'requiredSkills': (decodedResponse['requiredSkills'] as List<dynamic>?)?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList() ?? [],
          'experienceLevel': decodedResponse['experienceLevel'] as String?,
        };
      }
      // If response text is null or empty, throw an exception
      throw Exception('Failed to process JD: Empty or no text in Gemini response.');
    } catch (e) {
      // Log and return an error map if any exception occurs during processing
      if (kDebugMode) print('GeminiService: Error processing JD: $e');
      return {
        'error': e.toString(),
        'summary': null,
        'keyRequirements': [],
        'responsibilities': [],
        'requiredSkills': [],
        'experienceLevel': null,
      };
    }
  }

  // Extracts text content from a given file (like a CV) using Gemini's multimodal capabilities
  Future<String> extractTextFromCv(Uint8List cvFileBytes, String fileName) async {
     if (!AppConfig.isGeminiApiKeyConfigured()) {
      throw Exception("Gemini API Key not configured. Cannot extract text from CV.");
    }
    final model = _getModel();
    String mimeType;
    // Determine the MIME type based on file extension
    final lowerCaseFileName = fileName.toLowerCase();
    if (lowerCaseFileName.endsWith('.pdf')) mimeType = 'application/pdf';
    else if (lowerCaseFileName.endsWith('.png')) mimeType = 'image/png';
    else if (lowerCaseFileName.endsWith('.jpg') || lowerCaseFileName.endsWith('.jpeg')) mimeType = 'image/jpeg';
    else if (lowerCaseFileName.endsWith('.txt')) {
      // For text files, attempt to decode directly
      try { return utf8.decode(cvFileBytes, allowMalformed: true); }
      catch (e) { try { return latin1.decode(cvFileBytes); }
        catch (e2) { throw Exception("Could not decode TXT file $fileName."); }
      }
    } else {
      // Throw error for unsupported file types
      throw Exception("Unsupported file type for Gemini: $fileName. Supported: PDF, PNG, JPG, JPEG, TXT.");
    }

    // Create multimodal content for the prompt (text instruction + file data)
    final content = [Content.multi([
        TextPart(
          "Extract all textual information from the provided document. This is a CV or resume. "
          "Focus on capturing details like name, contact information (email, phone), summary/objective, "
          "work experience (roles, companies, dates, responsibilities), education (degrees, institutions, dates), "
          "skills (technical, soft), projects, awards, and any other relevant professional information. "
          "Present the extracted text clearly and comprehensively. If the document is an image, perform OCR to get the text."
        ),
        DataPart(mimeType, cvFileBytes), // Include the file bytes and MIME type
      ])];
    try {
      final response = await model.generateContent(content);
      // Return the extracted text if available
      if (response.text != null && response.text!.trim().isNotEmpty) {
        return response.text!.trim();
      }
      // Provide feedback details if the prompt was blocked
      String feedbackDetails = "Possible content filtering or API issue.";
      if (response.promptFeedback?.blockReason != null) {
          feedbackDetails = "Blocked due to: ${response.promptFeedback!.blockReason}. ";
      }
      throw Exception('Failed to extract text from CV ($fileName): Empty response. $feedbackDetails');
    } catch (e) {
      // Log and re-throw exceptions during text extraction
      if (kDebugMode) print('GeminiService: Error extracting text from CV ($fileName): $e');
      throw Exception('Could not extract text from CV ($fileName): ${e.toString()}');
    }
  }

  // Analyzes extracted CV text against structured JD data and provides a match analysis
  Future<Map<String, dynamic>> analyzeAndMatchCv({
    required String cvFileName,
    required String cvText,
    required Map<String, dynamic> jobDescriptionData,
  }) async {
     if (!AppConfig.isGeminiApiKeyConfigured()) {
      // Return error map if API key is not configured
      return {
        'error': 'API Key not configured',
        'candidateName': 'Unknown Candidate',
        'candidateEmail': 'no_email@example.com',
        'extractedSkills': [],
        'extractedExperienceSummary': 'Analysis not performed due to API configuration.',
        'matchScore': 0.0,
        'matchSummary': 'Analysis not performed due to API configuration.',
        'isShortlisted': false,
      };
    }
    try {
      final model = _getModel();
      // Prepare JD details for the prompt
      final jdTitle = jobDescriptionData['title'] ?? 'Not specified';
      final jdSummary = jobDescriptionData['summary'] ?? 'Not specified';
      final jdSkillsList = (jobDescriptionData['requiredSkills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final jdSkills = jdSkillsList.isNotEmpty ? jdSkillsList.join(', ') : 'Not specified';
      final jdExperience = jobDescriptionData['experienceLevel'] ?? 'Not specified';

      // Construct the prompt for CV analysis and matching
      final prompt = [Content.text(
        'Analyze the following candidate CV text against the provided job description details. '
        'Return a valid JSON object with the following fields: '
        '1. "candidateName": (string) The full name of the candidate. Default to "Unknown Candidate" if not found. '
        '2. "candidateEmail": (string) The primary email address of the candidate. Validate if it looks like an email. Default to "email_not_found@example.com" if not found or invalid. '
        '3. "extractedSkills": (list of strings) Key technical and soft skills extracted from the CV relevant to a professional context (around 5-15 skills). '
        '4. "extractedExperienceSummary": (string) A brief summary of the candidate\'s relevant work experience (2-4 key roles or achievements, concise). '
        '5. "matchScore": (number, 0.00 to 1.00) How well the candidate matches the job description. Consider skills, experience, and overall fit. Output as a float with 2 decimal places. '
        '6. "matchSummary": (string) A brief explanation for the match score (2-4 sentences), highlighting strengths and potential gaps against the JD. '
        '7. "isShortlisted": (boolean) Suggest if the candidate should be shortlisted (e.g., true if matchScore >= ${AppConfig.defaultShortlistingThreshold}, false otherwise). '
        '\n--- Job Description Context ---'
        '\nJob Title: $jdTitle'
        '\nJob Summary: $jdSummary'
        '\nKey Requirements & Skills for JD: $jdSkills'
        '\nExpected Experience Level for JD: $jdExperience'
        '\n--- Candidate CV Text (plain text extracted from their resume) ---'
        '\n$cvText'
        '\n--- End of CV Text ---'
        '\nProvide ONLY the JSON object in your response, without any surrounding text, comments, or markdown formatting (e.g., ```json ... ```). The JSON should be directly parsable.'
      )];
      final response = await model.generateContent(prompt);

      // Process the response
      if (response.text != null && response.text!.trim().isNotEmpty) {
        final decodedResponse = _parseGenerativeAiResponse(response.text!, "CV Analysis for $cvFileName");
        // Extract and validate match score
        double matchScore = (decodedResponse['matchScore'] as num?)?.toDouble() ?? 0.0;
        matchScore = matchScore.clamp(0.0, 1.0); // Ensure score is between 0 and 1

        // Return the analysis data
        return {
          // Generate a unique candidate ID (can be improved)
          'candidateId': 'cv_${DateTime.now().microsecondsSinceEpoch}_${cvFileName.hashCode}',
          'candidateName': decodedResponse['candidateName'] as String? ?? 'Unknown from $cvFileName',
          'candidateEmail': decodedResponse['candidateEmail'] as String? ?? 'no_email@example.com',
          'cvFileName': cvFileName,
          // Safely cast lists and filter empty strings
          'extractedSkills': (decodedResponse['extractedSkills'] as List<dynamic>?)?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList() ?? [],
          'extractedExperienceSummary': decodedResponse['extractedExperienceSummary'] as String? ?? 'No AI summary available.',
          'matchScore': matchScore,
          'matchSummary': decodedResponse['matchSummary'] as String? ?? 'No AI explanation available.',
          // Determine shortlisted status based on AI suggestion or default threshold
          'isShortlisted': (decodedResponse['isShortlisted'] as bool?) ?? (matchScore >= AppConfig.defaultShortlistingThreshold),
        };
      }
      // Provide feedback details if the prompt was blocked
      String feedbackDetails = "Possible content filtering or API issue.";
      if (response.promptFeedback?.blockReason != null) {
          feedbackDetails = "Blocked due to: ${response.promptFeedback!.blockReason}. ";
      }
      throw Exception('Failed to analyze CV ($cvFileName): Empty response. $feedbackDetails');
    } catch (e) {
      // Log and return an error map if any exception occurs
      if (kDebugMode) print('GeminiService: Error analyzing CV ($cvFileName): $e');
      return {
        'error': e.toString(),
        'candidateName': 'Unknown Candidate',
        'candidateEmail': 'no_email@example.com',
        'extractedSkills': [],
        'extractedExperienceSummary': 'Analysis failed: ${e.toString()}',
        'matchScore': 0.0,
        'matchSummary': 'Analysis failed: ${e.toString()}',
        'isShortlisted': false,
      };
    }
  }
}