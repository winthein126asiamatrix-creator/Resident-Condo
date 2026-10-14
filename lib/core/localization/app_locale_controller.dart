import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reactive source of truth for the application locale.
///
/// The saved code is a standard Flutter language code (`en`, `my` or `zh`).
/// Preference loading is intentionally synchronous-with-fallback: the app is
/// launched with the persisted code already injected, then this controller
/// verifies and repairs it in the background.
class AppLocaleController extends GetxController {
  AppLocaleController({Locale? initialLocale})
    : _locale = Rx<Locale>(initialLocale ?? const Locale('en')) {
    Get.updateLocale(_locale.value);
    Get.forceAppUpdate();
  }

  static const String _storageKey = 'app.locale';

  static const List<String> supportedCodes = <String>['en', 'my', 'zh'];

  final Rx<Locale> _locale;

  Locale get locale => _locale.value;

  Rx<Locale> get localeRx => _locale;

  @override
  void onInit() {
    super.onInit();
    restore();
  }

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_storageKey);
      if (stored != null && supportedCodes.contains(stored)) {
        _locale.value = Locale(stored);
      } else {
        _locale.value = const Locale('en');
      }
    } catch (_) {
      _locale.value = const Locale('en');
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (!supportedCodes.contains(code)) code = 'en';
    final next = Locale(code);
    _locale.value = next;
    // GetMaterialApp alone should follow [locale], but GetX also caches the
    // active locale for lookups, so keep them in sync to avoid requiring a
    // restart.
    Get.updateLocale(next);
    Get.forceAppUpdate();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, code);
    } catch (_) {
      // Keep UI valid even if persistence fails.
    }
  }

  String displayName(String code) {
    switch (code) {
      case 'my':
        return 'မြန်မာ';
      case 'zh':
        return '中文';
      default:
        return 'English';
    }
  }
}
