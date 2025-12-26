import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared/models/survey.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<List<Organization>> getOrganizations() async {
    try {
      final snapshot = await _firestore.collection('organizations').get();
      return snapshot.docs
          .map((doc) => Organization.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to load organizations: $e');
    }
  }

  static Future<List<Survey>> getSurveysByOrganization(String organizationId) async {
    final snapshot = await _firestore
        .collection('surveys')
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .get();
    print('surveys fetched: ${snapshot.docs.length}');
    return snapshot.docs
        .map((doc) => Survey.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  static Future<void> createSurvey(Survey survey) async {
    try {
      await _firestore.collection('surveys').doc(survey.id).set(survey.toJson());
    } catch (e) {
      throw Exception('Failed to create survey: $e');
    }
  }

  static Future<void> addSurvey(Map<String, dynamic> data) async {
    try {
      final doc = _firestore.collection('surveys').doc();
      await doc.set({...data, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to add survey: $e');
    }
  }

  static Future<void> deleteSurvey(String surveyId) async {
    try {
      await _firestore.collection('surveys').doc(surveyId).delete();
    } catch (e) {
      throw Exception('Failed to delete survey: $e');
    }
  }

  static Future<void> submitSurveyResponse(SurveyResponse response) async {
    try {
      await _firestore
          .collection('survey_responses')
          .doc(response.id)
          .set(response.toJson());
    } catch (e) {
      throw Exception('Failed to submit response: $e');
    }
  }

  static Future<List<SurveyResponse>> getSurveyResponses(String surveyId) async {
    try {
      final snapshot = await _firestore
          .collection('survey_responses')
          .where('surveyId', isEqualTo: surveyId)
          .get();

      return snapshot.docs
          .map((doc) => SurveyResponse.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to load responses: $e');
    }
  }

  static Future<Survey?> getSurveyById(String surveyId) async {
    final doc =
        await FirebaseFirestore.instance.collection('surveys').doc(surveyId).get();

    if (!doc.exists) return null;

    return Survey.fromJson({
      ...doc.data()!,
      'id': doc.id,
    });
  }

  static Future<Map<String, dynamic>> getSurveyAnalytics(String surveyId) async {
    try {
      final responses = await getSurveyResponses(surveyId);
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
    } catch (e) {
      throw Exception('Failed to load analytics: $e');
    }
  }

  static Future<void> updateSurvey(String surveyId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('surveys').doc(surveyId).update(data);
    } catch (e) {
      throw Exception('Failed to update survey: $e');
    }
  }
}
