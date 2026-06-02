import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);

  static bool get isArabic => notifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = prefs.getBool('is_arabic') ?? true;
  }

  static Future<void> toggle() async {
    notifier.value = !notifier.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_arabic', notifier.value);
  }

  static String t(String key) {
    const ar = <String, String>{
      'home': 'الرئيسية',
      'explore': 'استكشاف',
      'notifications': 'إشعارات',
      'profile': 'حسابي',
      'latest_experiences': 'أحدث التجارب',
      'worth_it': 'يستاهل',
      'want_to_visit': 'أود زيارته',
      'comment': 'تعليق',
      'see_all': 'شاهد الكل',
      'no_results': 'لا توجد نتائج',
      'categories': 'التصنيفات',
    };
    const en = <String, String>{
      'home': 'Home',
      'explore': 'Explore',
      'notifications': 'Notifications',
      'profile': 'Profile',
      'latest_experiences': 'Latest Experiences',
      'worth_it': 'Worth it',
      'want_to_visit': 'Want to visit',
      'comment': 'Comment',
      'see_all': 'See All',
      'no_results': 'No results',
      'categories': 'Categories',
    };
    return isArabic ? (ar[key] ?? key) : (en[key] ?? key);
  }
}
