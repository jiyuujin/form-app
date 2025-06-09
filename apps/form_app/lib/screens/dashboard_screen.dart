import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared/services/firebase_service.dart';
import 'package:shared/models/survey.dart';

class DashboardScreen extends StatefulWidget {
  final String organizationId;

  const DashboardScreen({super.key, required this.organizationId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Survey> _surveys = [];
  final Map<String, Map<String, dynamic>> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _surveys = await FirebaseService.getSurveysByOrganization(widget.organizationId);

      for (final survey in _surveys) {
        final analytics = await FirebaseService.getSurveyAnalytics(survey.id);
        _analytics[survey.id] = analytics;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('アンケート管理ダッシュボード'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _surveys.length,
        itemBuilder: (context, index) {
          final survey = _surveys[index];
          final analytics = _analytics[survey.id] ?? {};
          final totalResponses = analytics['totalResponses'] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    survey.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('回答数: $totalResponses'),
                  const SizedBox(height: 16),
                  if (totalResponses > 0) ...[
                    const Text('回答分析:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildAnalyticsChart(survey, analytics),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsChart(Survey survey, Map<String, dynamic> analytics) {
    final questionAnalytics = analytics['questionAnalytics'] as Map<String, dynamic>? ?? {};

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: survey.questions.length,
        itemBuilder: (context, index) {
          final question = survey.questions[index];
          final questionData = questionAnalytics[question.id] as Map<String, dynamic>? ?? {};

          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: questionData.entries.map((entry) {
                        final value = entry.value as int;
                        return PieChartSectionData(
                          value: value.toDouble(),
                          title: '${entry.key}\n($value)',
                          radius: 50,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}