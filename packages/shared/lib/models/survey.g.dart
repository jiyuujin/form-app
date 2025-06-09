// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'survey.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Survey _$SurveyFromJson(Map<String, dynamic> json) => Survey(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      organizationId: json['organizationId'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      endAt: json['endAt'] == null
          ? null
          : DateTime.parse(json['endAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$SurveyToJson(Survey instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'organizationId': instance.organizationId,
      'questions': instance.questions,
      'createdAt': instance.createdAt.toIso8601String(),
      'endAt': instance.endAt?.toIso8601String(),
      'isActive': instance.isActive,
    };

Question _$QuestionFromJson(Map<String, dynamic> json) => Question(
      id: json['id'] as String,
      text: json['text'] as String,
      type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isRequired: json['isRequired'] as bool? ?? false,
    );

Map<String, dynamic> _$QuestionToJson(Question instance) => <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'type': _$QuestionTypeEnumMap[instance.type]!,
      'options': instance.options,
      'isRequired': instance.isRequired,
    };

const _$QuestionTypeEnumMap = {
  QuestionType.multipleChoice: 'multipleChoice',
  QuestionType.text: 'text',
  QuestionType.rating: 'rating',
  QuestionType.yesNo: 'yesNo',
};

SurveyResponse _$SurveyResponseFromJson(Map<String, dynamic> json) =>
    SurveyResponse(
      id: json['id'] as String,
      surveyId: json['surveyId'] as String,
      answers: json['answers'] as Map<String, dynamic>,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      userId: json['userId'] as String?,
    );

Map<String, dynamic> _$SurveyResponseToJson(SurveyResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'surveyId': instance.surveyId,
      'answers': instance.answers,
      'submittedAt': instance.submittedAt.toIso8601String(),
      'userId': instance.userId,
    };

Organization _$OrganizationFromJson(Map<String, dynamic> json) => Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      adminIds:
          (json['adminIds'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$OrganizationToJson(Organization instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'adminIds': instance.adminIds,
    };
