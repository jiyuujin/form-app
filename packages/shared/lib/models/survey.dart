import 'package:json_annotation/json_annotation.dart';

part 'survey.g.dart';

@JsonSerializable()
class Survey {
  final String id;
  final String title;
  final String description;
  final String organizationId;
  final List<Question> questions;
  final DateTime createdAt;
  final DateTime? endAt;
  final bool isActive;

  Survey({
    required this.id,
    required this.title,
    required this.description,
    required this.organizationId,
    required this.questions,
    required this.createdAt,
    this.endAt,
    this.isActive = true,
  });

  factory Survey.fromJson(Map<String, dynamic> json) => _$SurveyFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyToJson(this);
}

@JsonSerializable()
class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<String>? options;
  final bool isRequired;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.isRequired = false,
  });

  factory Question.fromJson(Map<String, dynamic> json) => _$QuestionFromJson(json);
  Map<String, dynamic> toJson() => _$QuestionToJson(this);
}

enum QuestionType { multipleChoice, text, rating, yesNo }

@JsonSerializable()
class SurveyResponse {
  final String id;
  final String surveyId;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;
  final String? userId;

  SurveyResponse({
    required this.id,
    required this.surveyId,
    required this.answers,
    required this.submittedAt,
    this.userId,
  });

  factory SurveyResponse.fromJson(Map<String, dynamic> json) => 
      _$SurveyResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyResponseToJson(this);
}

@JsonSerializable()
class Organization {
  final String id;
  final String name;
  final String description;
  final List<String> adminIds;

  Organization({
    required this.id,
    required this.name,
    required this.description,
    required this.adminIds,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => 
      _$OrganizationFromJson(json);
  Map<String, dynamic> toJson() => _$OrganizationToJson(this);
}