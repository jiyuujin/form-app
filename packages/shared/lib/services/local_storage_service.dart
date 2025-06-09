import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    await _prefs?.setString('user_preferences', json.encode(preferences));
  }

  static Map<String, dynamic> getUserPreferences() {
    final prefsString = _prefs?.getString('user_preferences');
    if (prefsString != null) {
      return json.decode(prefsString);
    }
    return {};
  }

  static Future<void> saveDraftResponse(String surveyId, Map<String, dynamic> answers) async {
    await _prefs?.setString('draft_${surveyId}', json.encode(answers));
  }

  static Map<String, dynamic>? getDraftResponse(String surveyId) {
    final draftString = _prefs?.getString('draft_${surveyId}');
    if (draftString != null) {
      return json.decode(draftString);
    }
    return null;
  }

  static Future<void> clearDraftResponse(String surveyId) async {
    await _prefs?.remove('draft_${surveyId}');
  }

  static Future<void> markSurveyCompleted(String surveyId) async {
    final completed = getCompletedSurveys();
    completed.add(surveyId);
    await _prefs?.setStringList('completed_surveys', completed);
  }

  static List<String> getCompletedSurveys() {
    return _prefs?.getStringList('completed_surveys') ?? [];
  }

  static Future<void> saveSelectedOrganization(String organizationId) async {
    await _prefs?.setString('selected_organization', organizationId);
  }

  static String? getSelectedOrganization() {
    return _prefs?.getString('selected_organization');
  }
}