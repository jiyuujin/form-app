import 'dart:convert';
import 'dart:html' as html;

import 'package:csv/csv.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared/models/survey.dart';
import 'package:shared/services/firebase_service.dart';

class SurveyDetailsScreen extends StatefulWidget {
  final Survey survey;

  const SurveyDetailsScreen({super.key, required this.survey});

  @override
  State<SurveyDetailsScreen> createState() => _SurveyDetailsScreenState();
}

class _SurveyDetailsScreenState extends State<SurveyDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SurveyResponse> _responses = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final responses = await FirebaseService.getSurveyResponses(widget.survey.id);
      final analytics = await FirebaseService.getSurveyAnalytics(widget.survey.id);
      
      setState(() {
        _responses = responses;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (_responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートするデータがありません')),
      );
      return;
    }

    try {
      // CSVヘッダーを作成
      final headers = ['回答ID', '送信日時', ...widget.survey.questions.map((q) => q.text)];
      
      // データ行を作成
      final rows = _responses.map((response) {
        final row = [
          response.id,
          response.submittedAt.toIso8601String(),
        ];
        
        for (final question in widget.survey.questions) {
          final answer = response.answers[question.id]?.toString() ?? '';
          row.add(answer);
        }
        
        return row;
      }).toList();

      // CSV形式に変換
      final csvData = const ListToCsvConverter().convert([headers, ...rows]);
      
      // ファイルダウンロード
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        // ..attribute['download'] = '${widget.survey.title}_responses.csv'
        ..setAttribute('download', '${widget.survey.title}_responses.csv')
        ..click();
      
      html.Url.revokeObjectUrl(url);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVファイルをダウンロードしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.survey.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'CSVエクスポート',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概要', icon: Icon(Icons.analytics)),
            Tab(text: '回答', icon: Icon(Icons.table_chart)),
            Tab(text: 'グラフ', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildResponsesTab(),
          _buildChartsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final totalResponses = _analytics['totalResponses'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'アンケート情報',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('タイトル', widget.survey.title),
                  _buildInfoRow('説明', widget.survey.description),
                  _buildInfoRow('作成日', widget.survey.createdAt.toString().split(' ')[0]),
                  _buildInfoRow('質問数', '${widget.survey.questions.length}問'),
                  _buildInfoRow('回答数', '$totalResponses件'),
                  _buildInfoRow('ステータス', widget.survey.isActive ? 'アクティブ' : '非アクティブ'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '質問一覧',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ...widget.survey.questions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            child: Text('${index + 1}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question.text,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  _getQuestionTypeText(question.type),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsesTab() {
    if (_responses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('まだ回答がありません'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        columns: [
          const DataColumn2(label: Text('回答ID'), size: ColumnSize.S),
          const DataColumn2(label: Text('送信日時'), size: ColumnSize.M),
          ...widget.survey.questions.map((question) =>
            DataColumn2(
              label: Text(
                question.text,
                overflow: TextOverflow.ellipsis,
              ),
              size: ColumnSize.L,
            ),
          ),
        ],
        rows: _responses.map((response) {
          return DataRow2(
            cells: [
              DataCell(Text(response.id.substring(0, 8))),
              DataCell(Text(
                '${response.submittedAt.month}/${response.submittedAt.day} ${response.submittedAt.hour}:${response.submittedAt.minute.toString().padLeft(2, '0')}',
              )),
              ...widget.survey.questions.map((question) {
                final answer = response.answers[question.id]?.toString() ?? '-';
                return DataCell(
                  Text(
                    answer.length > 20 ? '${answer.substring(0, 20)}...' : answer,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartsTab() {
    final questionAnalytics = _analytics['questionAnalytics'] as Map<String, dynamic>? ?? {};
    
    if (questionAnalytics.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('分析データがありません'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: widget.survey.questions.length,
        itemBuilder: (context, index) {
          final question = widget.survey.questions[index];
          final questionData = questionAnalytics[question.id] as Map<String, dynamic>? ?? {};
          
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildQuestionChart(question, questionData),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionChart(Question question, Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('データなし'));
    }

    switch (question.type) {
      case QuestionType.multipleChoice:
      case QuestionType.yesNo:
        return PieChart(
          PieChartData(
            sections: data.entries.map((entry) {
              final value = entry.value as int;
              final total = data.values.fold<int>(0, (sum, v) => sum + (v as int));
              final percentage = (value / total * 100).round();
              
              return PieChartSectionData(
                value: value.toDouble(),
                title: '$percentage%',
                color: _getColorForIndex(data.keys.toList().indexOf(entry.key)),
                radius: 50,
              );
            }).toList(),
          ),
        );
      
      case QuestionType.rating:
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: data.values.fold<int>(0, (max, v) => v > max ? v : max).toDouble(),
            barGroups: data.entries.map((entry) {
              final index = int.tryParse(entry.key) ?? 0;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (entry.value as int).toDouble(),
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              );
            }).toList(),
          ),
        );
      
      default:
        return const Center(child: Text('グラフ表示不可'));
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getQuestionTypeText(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return '選択式';
      case QuestionType.text:
        return 'テキスト';
      case QuestionType.rating:
        return '評価';
      case QuestionType.yesNo:
        return 'Yes/No';
    }
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }
}