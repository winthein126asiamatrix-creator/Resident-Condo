import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/features/appearance/data/datasources/appearance_local_data_source.dart';
import 'package:test/features/appearance/data/repositories/appearance_repository_impl.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/domain/entities/appearance_preference.dart';
import 'package:test/features/appearance/domain/usecases/appearance_usecases.dart';

/// The storage contract, exercised against a real (mock-backed)
/// [SharedPreferences] instance rather than an in-memory stand-in.
///
/// This is what makes "the colour survives a restart" true: the value has to
/// come back out of the same keys it was written to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('persistence', () {
    test('a colour survives a restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      // First launch: the resident picks Violet and switches to Dark.
      final firstLaunch = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );
      await firstLaunch.savePreference(
        const AppearancePreference(
          seedColor: Color(0xFF7C3AED),
          presetId: 'violet',
          brightnessMode: AppBrightnessMode.dark,
        ),
      );

      // Second launch: a brand new data source over the same storage, which is
      // exactly what a cold app start does.
      final afterRestart = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );
      final restored = await afterRestart.getPreference();

      expect(restored.seedColor, const Color(0xFF7C3AED));
      expect(restored.presetId, 'violet');
      expect(restored.brightnessMode, AppBrightnessMode.dark);
      expect(restored.label, 'Violet');
    });

    test('a custom colour round trips and reports no preset', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final useCases = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );

      const handPicked = Color(0xFF3F7F8C);
      await useCases.savePreference(
        const AppearancePreference(
          seedColor: handPicked,
          brightnessMode: AppBrightnessMode.light,
        ),
      );

      final restored = await useCases.getPreference();

      expect(restored.seedColor, handPicked);
      expect(restored.presetId, isNull);
      expect(restored.isCustomColor, isTrue);
      expect(restored.label, '#3F7F8C');
    });

    test('choosing a custom colour clears a previously saved preset name', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final useCases = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );

      await useCases.savePreference(
        const AppearancePreference(
          seedColor: Color(0xFF7C3AED),
          presetId: 'violet',
          brightnessMode: AppBrightnessMode.system,
        ),
      );
      // A custom pick must not still be labelled "Violet" after a restart.
      await useCases.savePreference(
        const AppearancePreference(
          seedColor: Color(0xFF3F7F8C),
          brightnessMode: AppBrightnessMode.system,
        ),
      );

      final restored = await useCases.getPreference();
      expect(restored.presetId, isNull);
      expect(restored.label, '#3F7F8C');
    });

    test('reset clears storage back to the shipped default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final useCases = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );

      await useCases.savePreference(
        const AppearancePreference(
          seedColor: Color(0xFFDC2626),
          presetId: 'red',
          brightnessMode: AppBrightnessMode.dark,
        ),
      );

      final reset = await useCases.resetPreference();
      expect(reset, AppearancePreference.defaults());

      // And a fresh read confirms the keys really are gone.
      final afterRestart = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );
      expect(await afterRestart.getPreference(), AppearancePreference.defaults());
    });

    test('an empty store yields the default rather than throwing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final useCases = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );

      expect(
        await useCases.getPreference(),
        AppearancePreference.defaults(),
      );
    });

    test('an unreadable stored mode falls back instead of crashing', () async {
      // A value written by a future version, or corrupted by hand.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appearance.seed_color': 0xFF0F766E,
        'appearance.brightness_mode': 'sepia',
      });

      final useCases = AppearanceUseCases(
        AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      );
      final restored = await useCases.getPreference();

      expect(restored.seedColor, const Color(0xFF0F766E));
      expect(restored.brightnessMode, AppBrightnessMode.system);
    });
  });
}