import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_app/screens/dashboard_screen.dart';
import 'package:form_app/screens/home_screen.dart';
import 'package:form_app/screens/organization_selection_screen.dart';
import 'package:form_app/screens/signin_screen.dart';
import 'package:form_app/screens/splash_screen.dart';
import 'package:form_app/screens/survey_screen.dart';
import 'package:form_app/screens/thank_you_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/firebase_service.dart';
import 'package:shared/services/local_storage_service.dart';

import 'firebase_options.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

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

  // Web のみハッシュなし URL
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

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
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;

      // 🔴 auth 確定前は必ず splash
      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isLoggedIn = authState.value != null;
      // ログイン不要ルート
      final isPublicRoute =
          location == '/signin' || 
          location.startsWith('/survey/') ||
          location == '/thank-you';  // ← ここに追加

      // splash からの遷移先制御
      if (location == '/splash') {
        return isLoggedIn ? '/' : '/signin';
      }

      // 未ログインで signin にリダイレクト
      if (!isLoggedIn && !isPublicRoute) {
        return '/signin';
      }

      // ログイン済で signin へアクセスした場合トップへ
      if (isLoggedIn && location == '/signin') {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const OrganizationSelectionScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SigninScreen(),
      ),
      GoRoute(
        path: '/dashboard/:id',
        builder: (context, state) => DashboardScreen(
          surveyId: state.pathParameters['id']!,
        ),
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
      GoRoute(
        path: '/thank-you',
        builder: (context, state) => const ThankYouScreen(),
      ),
    ],
  );
});
