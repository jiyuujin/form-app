import 'package:flutter/foundation.dart';

class PerformanceUtils {
  static Map<String, dynamic> getOptimizedImageSettings() {
    return {
      'cacheWidth': kIsWeb ? 800 : 400,
      'cacheHeight': kIsWeb ? 600 : 300,
      'quality': kDebugMode ? 100 : 85,
    };
  }

  static int getOptimalListItemCount() {
    return kIsWeb ? 50 : 20;
  }

  static Duration getCacheDuration() {
    return const Duration(minutes: 15);
  }

  static bool shouldCompressData() {
    return !kDebugMode;
  }
}