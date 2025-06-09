import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/models/survey.dart';

class RealtimeService {
  static Stream<List<Survey>> watchSurveysByOrganization(String organizationId) {
    return FirebaseFirestore.instance
        .collection('surveys')
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Survey.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  static Stream<List<SurveyResponse>> watchSurveyResponses(String surveyId) {
    return FirebaseFirestore.instance
        .collection('survey_responses')
        .where('surveyId', isEqualTo: surveyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SurveyResponse.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  static Stream<Map<String, dynamic>> watchSurveyAnalytics(String surveyId) {
    return watchSurveyResponses(surveyId).map((responses) {
      final totalResponses = responses.length;
      
      if (totalResponses == 0) {
        return {'totalResponses': 0, 'questionAnalytics': {}};
      }

      final questionAnalytics = <String, dynamic>{};

      for (final response in responses) {
        response.answers.forEach((questionId, answer) {
          if (!questionAnalytics.containsKey(questionId)) {
            questionAnalytics[questionId] = <String, int>{};
          }

          final answerStr = answer.toString();
          questionAnalytics[questionId][answerStr] = 
              (questionAnalytics[questionId][answerStr] ?? 0) + 1;
        });
      }

      return {
        'totalResponses': totalResponses,
        'questionAnalytics': questionAnalytics,
      };
    });
  }
}