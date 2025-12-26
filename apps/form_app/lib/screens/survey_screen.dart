import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/survey.dart';
import 'package:shared/services/firebase_service.dart';
import 'package:shared/services/local_storage_service.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  final String surveyId;

  const SurveyScreen({super.key, required this.surveyId});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  final Map<String, dynamic> _answers = {};
  Survey? _survey;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSurvey();
    _loadDraftAnswers();
  }

  Future<void> _loadSurvey() async {
    setState(() => _isLoading = true);

    try {
      _survey = await FirebaseService.getSurveyById(widget.surveyId);
    } catch (e) {
      print(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadDraftAnswers() {
    final draft = LocalStorageService.getDraftResponse(widget.surveyId);
    if (draft != null) {
      setState(() => _answers.addAll(draft));
    }
  }

  Future<void> _saveDraft() async {
    await LocalStorageService.saveDraftResponse(widget.surveyId, _answers);
    _showSnackBar('下書きを保存しました');
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  bool _validateCurrentQuestion() {
    final question = _survey!.questions[_currentPage];
    if (question.isRequired &&
        (_answers[question.id] == null ||
         (_answers[question.id] is String &&
          (_answers[question.id] as String).isEmpty))) {
      _showSnackBar('この質問は必須です');
      return false;
    }
    return true;
  }

  bool _validateAll() {
    for (final question in _survey!.questions) {
      if (question.isRequired &&
          (_answers[question.id] == null ||
           (_answers[question.id] is String &&
            (_answers[question.id] as String).isEmpty))) {
        _showSnackBar('未回答の必須質問があります');
        return false;
      }
    }
    return true;
  }

  Future<void> _submitSurvey() async {
    if (_isSubmitting) return;
    if (!_validateAll()) return;

    setState(() => _isSubmitting = true);

    try {
      final completed =
          LocalStorageService.isSurveyCompleted(widget.surveyId);
      if (completed) {
        throw Exception('このアンケートは既に回答済みです');
      }

      final deviceId = await LocalStorageService.deviceId;
      final responseId = '${widget.surveyId}_$deviceId';

      final response = SurveyResponse(
        id: responseId,
        surveyId: widget.surveyId,
        answers: _answers,
        submittedAt: DateTime.now(),
      );

      await FirebaseService.submitSurveyResponse(response);

      await LocalStorageService.markSurveyCompleted(widget.surveyId);
      await LocalStorageService.clearDraftResponse(widget.surveyId);

      _showSnackBar('アンケートを送信しました！');
      if (mounted) context.go('/home');
    } catch (e) {
      _showSnackBar('送信に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_survey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: const Center(child: Text('アンケートが見つかりません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_survey!.title),
        actions: [
          TextButton(
            onPressed: _saveDraft,
            child: const Text('下書き保存'),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const ClampingScrollPhysics(), // スワイプが少し安定
        itemCount: _survey!.questions.length,
        onPageChanged: (page) => setState(() => _currentPage = page),
        itemBuilder: (context, index) {
          final question = _survey!.questions[index];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (index + 1) / _survey!.questions.length,
                  color: Theme.of(context).primaryColor,
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '質問 ${index + 1} / ${_survey!.questions.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (question.isRequired)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          '*必須',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  question.text,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildQuestionWidget(question)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (index > 0)
                      ElevatedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('前へ'),
                      )
                    else
                      const SizedBox(width: 100),
                    if (index < _survey!.questions.length - 1)
                      ElevatedButton(
                        onPressed: _validateCurrentQuestion()
                            ? () => _pageController.nextPage(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                )
                            : null,
                        child: const Text('次へ'),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isSubmitting ? null : _submitSurvey,
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  '送信',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionWidget(Question question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return Column(
          children: question.options!.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _answers[question.id],
              onChanged: (value) {
                setState(() => _answers[question.id] = value);
              },
            );
          }).toList(),
        );

      case QuestionType.text:
        return TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'ここに回答を入力してください',
          ),
          maxLines: 3,
          onChanged: (value) => _answers[question.id] = value,
          controller: TextEditingController(text: _answers[question.id] ?? ''),
        );

      case QuestionType.rating:
        return Column(
          children: [
            Text('評価: ${_answers[question.id] ?? 0}/5'),
            Slider(
              value: (_answers[question.id] ?? 0).toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              onChanged: (value) {
                setState(() => _answers[question.id] = value.toInt());
              },
            ),
          ],
        );

      case QuestionType.yesNo:
        return Column(
          children: [
            RadioListTile<bool>(
              title: const Text('はい'),
              value: true,
              groupValue: _answers[question.id],
              onChanged: (value) {
                setState(() => _answers[question.id] = value);
              },
            ),
            RadioListTile<bool>(
              title: const Text('いいえ'),
              value: false,
              groupValue: _answers[question.id],
              onChanged: (value) {
                setState(() => _answers[question.id] = value);
              },
            ),
          ],
        );
    }
  }
}
