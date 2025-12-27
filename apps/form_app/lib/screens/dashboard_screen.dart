import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared/models/survey.dart';
import 'package:shared/services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  final String surveyId;

  const DashboardScreen({super.key, required this.surveyId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Survey? _survey;
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _survey = await FirebaseService.getSurveyById(widget.surveyId);
      _analytics = await FirebaseService.getSurveyAnalytics(widget.surveyId);
      if (_survey == null) {
        _showSnackBar('アンケートが見つかりません');
      }
    } catch (e) {
      _showSnackBar('データの読み込みに失敗しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  void _addQuestion() async {
    if (_survey == null) return;
    final newQuestion = await showDialog<Question>(
      context: context,
      builder: (_) => const QuestionDialog(),
    );
    if (newQuestion != null) {
      setState(() {
        _survey!.questions.add(newQuestion);
      });
      await _saveChanges();
    }
  }

  void _editQuestion(int index) async {
    if (_survey == null) return;
    final edited = await showDialog<Question>(
      context: context,
      builder: (_) => QuestionDialog(question: _survey!.questions[index]),
    );
    if (edited != null) {
      setState(() {
        _survey!.questions[index] = edited;
      });
      await _saveChanges();
    }
  }

  void _deleteQuestion(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('質問を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && _survey != null) {
      setState(() {
        _survey!.questions.removeAt(index);
      });
      await _saveChanges();
    }
  }

  Future<void> _saveChanges() async {
    if (_survey == null) return;

    final surveyData = _survey!.toJson();
    surveyData['questions'] = _survey!.questions.map((q) => q.toJson()).toList();

    await FirebaseService.updateSurvey(_survey!.id, surveyData);
    _loadData();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('質問を保存しました')));
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
        appBar: AppBar(title: const Text('アンケートダッシュボード')),
        body: const Center(child: Text('アンケートが見つかりません')),
      );
    }

    final totalResponses = _analytics['totalResponses'] ?? 0;
    final questionAnalytics =
        _analytics['questionAnalytics'] as Map<dynamic, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(_survey!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addQuestion,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _survey!.questions.isEmpty
            ? const Center(child: Text('質問がまだありません'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _survey!.questions.length,
                itemBuilder: (context, index) {
                  final q = _survey!.questions[index];
                  final data =
                      questionAnalytics[q.id] as Map<String, dynamic>? ?? {};

                  Widget content;
                  if (q.type == QuestionType.text) {
                    // デバッグ: データ構造を確認
                    print('Text question data: $data');
                    
                    // 複数のキー名を試す
                    List<dynamic> responses = [];
                    if (data.containsKey('responses')) {
                      responses = data['responses'] as List<dynamic>? ?? [];
                    } else if (data.containsKey('answers')) {
                      responses = data['answers'] as List<dynamic>? ?? [];
                    } else {
                      // データ全体をリストとして取得を試みる
                      responses = data.values
                          .where((v) => v is String)
                          .toList();
                    }
                    
                    content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.text,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (responses.isEmpty)
                          Text('回答なし (取得データ: ${data.keys.join(", ")})')
                        else
                          ...responses.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('- ${r.toString()}'),
                              )).toList(),
                      ],
                    );
                  } else {
                    final sections = data.entries
                        .where((e) => e.value is int)
                        .map((e) => PieChartSectionData(
                              value: (e.value as int).toDouble(),
                              title: '${e.key}\n(${e.value})',
                              radius: 50,
                            ))
                        .toList();
                    content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.text,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        sections.isEmpty
                            ? const Text('回答なし')
                            : SizedBox(
                                height: 200,
                                child: PieChart(PieChartData(sections: sections)),
                              ),
                      ],
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: content,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editQuestion(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteQuestion(index),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class QuestionDialog extends StatefulWidget {
  final Question? question;
  const QuestionDialog({super.key, this.question});
  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  late TextEditingController _textController;
  QuestionType _type = QuestionType.text;
  bool _isRequired = false;
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _textController = TextEditingController(text: widget.question!.text);
      _type = widget.question!.type;
      _isRequired = widget.question!.isRequired;
      _options = widget.question!.options ?? [];
    } else {
      _textController = TextEditingController();
    }
  }

  void _save() {
    if (_textController.text.isEmpty) return;

    final newQuestion = Question(
      id: widget.question?.id ?? UniqueKey().toString(),
      text: _textController.text,
      type: _type,
      options: _type == QuestionType.multipleChoice ? _options : null,
      isRequired: _isRequired,
    );

    Navigator.pop(context, newQuestion);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question != null ? '質問を編集' : '新しい質問'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: '質問内容'),
            ),
            const SizedBox(height: 8),
            DropdownButton<QuestionType>(
              value: _type,
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
              items: QuestionType.values
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toString().split('.').last),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('必須'),
                Checkbox(
                    value: _isRequired,
                    onChanged: (v) => setState(() => _isRequired = v ?? false))
              ],
            ),
            if (_type == QuestionType.multipleChoice) ...[
              const SizedBox(height: 8),
              Column(
                children: _options
                    .asMap()
                    .entries
                    .map(
                      (entry) => Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  initialValue: entry.value,
                                  onChanged: (v) => _options[entry.key] = v)),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() => _options.removeAt(entry.key));
                            },
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
              TextButton(
                  onPressed: () => setState(() => _options.add('')),
                  child: const Text('選択肢を追加')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

extension SurveyCopy on Survey {
  Survey copyWith({List<Question>? questions}) {
    return Survey(
      id: id,
      title: title,
      description: description,
      organizationId: organizationId,
      questions: questions ?? this.questions,
      createdAt: createdAt,
      endAt: endAt,
      isActive: isActive,
    );
  }
}
