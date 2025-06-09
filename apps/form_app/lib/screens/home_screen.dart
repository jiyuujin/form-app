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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveysAsync = ref.watch(surveysProvider);
    // final completedSurveys = LocalStorageService.getCompletedSurveys();

    return Scaffold(
      appBar: AppBar(
        title: const Text('アンケート一覧'),
        actions: [
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
            // final isCompleted = completedSurveys.contains(survey.id);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(survey.title),
                subtitle: Text(survey.description),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.go('/survey/${survey.id}'),
                // trailing: isCompleted 
                //     ? const Icon(Icons.check_circle, color: Colors.green)
                //     : const Icon(Icons.arrow_forward_ios),
                // onTap: isCompleted 
                //     ? null 
                //     : () => context.go('/survey/${survey.id}'),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラー: $error'),
        ),
      ),
    );
  }
}