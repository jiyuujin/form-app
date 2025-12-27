import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key});

  Future<void> _launchBlog() async {
    final uri = Uri.parse('https://blog.nekohack.me/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 24),
              Text(
                'ご回答ありがとうございました！',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'アンケートが正常に送信されました',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _launchBlog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('ブログに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}