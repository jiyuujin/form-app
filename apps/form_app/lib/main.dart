import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_app/screens/home_screen.dart';
import 'package:form_app/screens/organization_selection_screen.dart';
import 'package:form_app/screens/signin_screen.dart';
import 'package:form_app/screens/survey_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/firebase_service.dart';
import 'package:shared/services/local_storage_service.dart';

import 'firebase_options.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final authStateProvider = StreamProvider((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorageService.init();

  runApp(const ProviderScope(child: FormApp()));
}

class FormApp extends ConsumerWidget {
  const FormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Form App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    redirect: (context, state) {
      final isLoggedIn = authState.asData?.value != null;
      final isOnLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLoginPage) return '/login';
      if (isLoggedIn && isOnLoginPage) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OrganizationSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const SigninScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/survey/:id',
        builder: (context, state) => SurveyScreen(
          surveyId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
