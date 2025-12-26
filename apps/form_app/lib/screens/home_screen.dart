import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/survey.dart';
import 'package:shared/services/firebase_service.dart';
import 'package:shared/services/local_storage_service.dart';

final surveysProvider = FutureProvider<List<Survey>>((ref) async {
  final orgId = LocalStorageService.getSelectedOrganization();
  if (orgId == null) throw Exception('No organization selected');
  return FirebaseService.getSurveysByOrganization(orgId);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _addSurvey(BuildContext context, WidgetRef ref) async {
    final orgId = LocalStorageService.getSelectedOrganization();
    if (orgId == null) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新しいアンケートを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'タイトル'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '説明'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('作成')),
        ],
      ),
    );

    if (result == true) {
      final newSurvey = Survey(
        id: UniqueKey().toString(),
        title: titleController.text,
        description: descriptionController.text,
        organizationId: orgId,
        questions: [],
        createdAt: DateTime.now(),
        endAt: null,
        isActive: true,
      );

      await FirebaseService.addSurvey(newSurvey.toJson());
      ref.invalidate(surveysProvider); // Provider をリフレッシュ
    }
  }

  Future<void> _deleteSurvey(BuildContext context, WidgetRef ref, Survey survey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('アンケートを削除しますか？'),
        content: Text(survey.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseService.deleteSurvey(survey.id);
      ref.invalidate(surveysProvider); // Provider をリフレッシュ
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveysAsync = ref.watch(surveysProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('アンケート一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addSurvey(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: surveysAsync.when(
        data: (surveys) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: surveys.length,
          itemBuilder: (context, index) {
            final survey = surveys[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(survey.title),
                subtitle: Text(survey.description),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => context.go('/survey/${survey.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSurvey(context, ref, survey),
                    ),
                  ],
                ),
                onTap: () => context.go('/dashboard/${survey.id}'),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
    );
  }
}
