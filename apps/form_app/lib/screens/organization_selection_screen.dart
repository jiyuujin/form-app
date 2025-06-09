import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/survey.dart';
import 'package:shared/services/firebase_service.dart';
import 'package:shared/services/local_storage_service.dart';
import 'package:go_router/go_router.dart';

final organizationsProvider = FutureProvider<List<Organization>>((ref) async {
  return FirebaseService.getOrganizations();
});

class OrganizationSelectionScreen extends ConsumerWidget {
  const OrganizationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationsAsync = ref.watch(organizationsProvider);
    final selectedOrgId = LocalStorageService.getSelectedOrganization();

    return Scaffold(
      appBar: AppBar(
        title: const Text('組織を選択'),
        centerTitle: true,
      ),
      body: organizationsAsync.when(
        data: (organizations) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アンケートに参加する組織を選択してください',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: organizations.length,
                  itemBuilder: (context, index) {
                    final org = organizations[index];
                    final isSelected = selectedOrgId == org.id;

                    return Card(
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            org.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          org.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(org.description),
                        trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.arrow_forward_ios),
                        onTap: () async {
                          await LocalStorageService.saveSelectedOrganization(org.id);
                          if (context.mounted) {
                            context.go('/home');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              if (selectedOrgId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('アンケート一覧へ進む'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('組織情報の読み込みに失敗しました'),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(organizationsProvider),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}