import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/in_memory_token_storage.dart';
import 'package:test/core/network/token_storage.dart';
import 'package:test/core/network/user_preferences_remote_data_source.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/domain/entities/appearance_preference.dart';
import 'package:test/features/appearance/domain/repositories/appearance_repository.dart';
import 'package:test/features/appearance/domain/usecases/appearance_usecases.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/profile/presentation/controllers/profile_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

typedef _ResponseHandler = FutureOr<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handle);

  final _ResponseHandler handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => await handle(options, requestStream);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

String? _bearer(RequestOptions options) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      return entry.value?.toString();
    }
  }
  return null;
}

class _CapturedRequest {
  String? path;
  String? method;
  Object? body;
  String? bearer;
}

Future<_CapturedRequest> _sendWithFakeAdapter(
  Future<void> Function(UserPreferencesRemoteDataSource remote) send, {
  Object response = const <String, dynamic>{'ok': true},
}) async {
  final captured = _CapturedRequest();
  final dio = Dio()
    ..httpClientAdapter = _FakeAdapter((options, _) async {
      captured.path = options.path;
      captured.method = options.method;
      captured.body = options.data;
      captured.bearer = _bearer(options);
      return _json(200, response);
    });
  final storage = InMemoryTokenStorage();
  await storage.writeTokens(
    const AuthTokens(accessToken: 'token-123', refreshToken: 'refresh-123'),
  );
  final remote = UserPreferencesRemoteDataSource(
    DioApiService(
      dio: dio,
      tokenStorage: storage,
      baseUrl: 'https://api.example.com/api/v1',
    ),
  );
  await send(remote);
  return captured;
}

class _FakeAppearanceRepository implements AppearanceRepository {
  String? activeAccountId = '6';
  final Map<String, AppearancePreference> stored =
      <String, AppearancePreference>{};
  final Map<String, bool> pending = <String, bool>{};
  final List<String> themeCalls = <String>[];

  Future<void> Function(String hexColor)? onThemeUpdate;

  @override
  Future<String?> getActiveAccountId() async => activeAccountId;

  @override
  Future<void> setActiveAccount(String accountId) async {
    activeAccountId = accountId;
  }

  @override
  Future<void> clearActiveAccount() async {
    activeAccountId = null;
  }

  @override
  Future<AppearancePreference?> getPreference(String accountId) async =>
      stored[accountId];

  @override
  Future<bool> hasPendingSync(String accountId) async =>
      pending[accountId] ?? false;

  @override
  Future<AppearancePreference> savePreference(
    String accountId,
    AppearancePreference preference, {
    bool markPendingSync = false,
  }) async {
    stored[accountId] = preference;
    pending[accountId] = markPendingSync;
    activeAccountId = accountId;
    return preference;
  }

  @override
  Future<void> updateThemeColor(String hexColor) async {
    themeCalls.add(hexColor);
    await onThemeUpdate?.call(hexColor);
  }

  @override
  Future<AppearancePreference> resetPreference(String accountId) async {
    stored.remove(accountId);
    pending.remove(accountId);
    return AppearancePreference.defaults();
  }
}

class _FakePreferencesRemote extends UserPreferencesRemoteDataSource {
  _FakePreferencesRemote()
    : super(
        DioApiService(
          tokenStorage: InMemoryTokenStorage(),
          baseUrl: 'https://api.example.com/api/v1',
        ),
      );

  final List<String> themeCalls = <String>[];
  final List<bool> notificationCalls = <bool>[];

  Future<void> Function(String hexColor)? onThemeUpdate;
  Future<void> Function(bool enabled)? onNotificationUpdate;

  @override
  Future<void> updateThemeColor(String hexColor) async {
    themeCalls.add(hexColor);
    await onThemeUpdate?.call(hexColor);
  }

  @override
  Future<void> updateNotificationsEnabled(bool enabled) async {
    notificationCalls.add(enabled);
    await onNotificationUpdate?.call(enabled);
  }
}

AuthUser _user({bool? notificationsEnabled, String? themeColor}) {
  return AuthUser(
    id: 6,
    name: 'Owner One',
    phone: '0811111111',
    role: 'owner',
    themeColor: themeColor,
    notificationsEnabled: notificationsEnabled,
  );
}

void main() {
  group('preferences endpoint', () {
    test(
      'theme colour sends PATCH /me/preferences with only theme_color',
      () async {
        final request = await _sendWithFakeAdapter(
          (remote) => remote.updateThemeColor('#2196F3'),
        );

        expect(request.method, 'PATCH');
        expect(request.path, ApiEndPoints.preferences);
        expect(request.body, <String, Object?>{'theme_color': '#2196F3'});
        expect(request.bearer, 'Bearer token-123');
      },
    );

    test(
      'enabling notifications sends only notifications_enabled: true',
      () async {
        final request = await _sendWithFakeAdapter(
          (remote) => remote.updateNotificationsEnabled(true),
        );

        expect(request.method, 'PATCH');
        expect(request.path, ApiEndPoints.preferences);
        expect(request.body, <String, Object?>{'notifications_enabled': true});
      },
    );

    test(
      'disabling notifications sends only notifications_enabled: false',
      () async {
        final request = await _sendWithFakeAdapter(
          (remote) => remote.updateNotificationsEnabled(false),
        );

        expect(request.body, <String, Object?>{'notifications_enabled': false});
      },
    );

    test('fetching preferences GETs /me/preferences with the bearer', () async {
      late Map<String, dynamic> preferences;
      final request = await _sendWithFakeAdapter(
        (remote) async {
          preferences = await remote.fetchPreferences();
        },
        response: <String, dynamic>{
          'theme_color': '#0EA5E9',
          'notifications_enabled': true,
        },
      );

      expect(request.method, 'GET');
      expect(request.path, ApiEndPoints.preferences);
      expect(request.bearer, 'Bearer token-123');
      expect(preferences['theme_color'], '#0EA5E9');
      expect(preferences['notifications_enabled'], isTrue);
    });
  });

  group('appearance preference sync', () {
    late _FakeAppearanceRepository repository;
    late AppearanceController controller;

    setUp(() {
      repository = _FakeAppearanceRepository();
      controller = AppearanceController(AppearanceUseCases(repository));
    });

    test('applying a new colour sends its #RRGGBB value', () async {
      final sky = AppColorSeeds.all.firstWhere((seed) => seed.id == 'sky');

      controller.selectPreset(sky);
      final applied = await controller.applyTheme();

      expect(applied, isTrue);
      expect(repository.themeCalls, <String>['#0EA5E9']);
      expect(repository.stored['6']?.seedColor, sky.color);
      expect(repository.pending['6'], isFalse);
    });

    test('switching brightness mode sends no request', () async {
      controller.selectBrightnessMode(AppBrightnessMode.dark);

      final applied = await controller.applyTheme();

      expect(applied, isTrue);
      expect(repository.themeCalls, isEmpty);
      expect(repository.stored['6']?.brightnessMode, AppBrightnessMode.dark);
    });

    test('an unchanged colour sends no request', () async {
      await controller.applyTheme();

      expect(repository.themeCalls, isEmpty);
    });

    test('a failed request restores the previous colour', () async {
      repository.onThemeUpdate = (_) async {
        throw const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      };
      final sky = AppColorSeeds.all.firstWhere((seed) => seed.id == 'sky');

      controller.selectPreset(sky);
      final applied = await controller.applyTheme();

      expect(applied, isFalse);
      expect(controller.errorMessage.value, isNotNull);
      expect(controller.saved.value.seedColor, AppColorSeeds.defaultSeed.color);
      expect(
        repository.stored['6']?.seedColor,
        AppColorSeeds.defaultSeed.color,
      );
      expect(repository.pending['6'], isFalse);
    });

    test('rapid colour changes keep the latest selection', () async {
      final sky = AppColorSeeds.all.firstWhere((seed) => seed.id == 'sky');
      final green = AppColorSeeds.all.firstWhere((seed) => seed.id == 'green');
      final firstRequest = Completer<void>();
      repository.onThemeUpdate = (hexColor) {
        if (hexColor == '#0EA5E9') {
          return firstRequest.future;
        }
        return Future<void>.value();
      };

      controller.selectPreset(sky);
      final first = controller.applyTheme();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      controller.selectPreset(green);
      final second = controller.applyTheme();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(repository.themeCalls, <String>['#0EA5E9']);

      firstRequest.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);

      expect(repository.themeCalls, <String>['#0EA5E9', '#16A34A']);
      expect(controller.saved.value.seedColor, green.color);
    });

    test('a fresh backend colour replaces the local cache', () async {
      await controller.applyAuthenticatedUser(
        accountId: '6',
        backendThemeColor: '#2196F3',
      );

      expect(controller.saved.value.seedColor, const Color(0xFF2196F3));
      expect(repository.stored['6']?.hexLabel, '#2196F3');
    });
  });

  group('notification preference sync', () {
    late SessionController session;
    late _FakePreferencesRemote remote;
    late ProfileController controller;

    setUp(() {
      session = SessionController();
      remote = _FakePreferencesRemote();
      controller = ProfileController(session, preferencesRemote: remote);
    });

    test('initializes from the authenticated user', () {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: false));

      expect(controller.notificationsEnabled.value, isFalse);
    });

    test('enabling notifications sends true', () async {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: false));

      final updated = await controller.toggleNotifications(true);

      expect(updated, isTrue);
      expect(controller.notificationsEnabled.value, isTrue);
      expect(remote.notificationCalls, <bool>[true]);
    });

    test('disabling notifications sends false', () async {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: true));

      final updated = await controller.toggleNotifications(false);

      expect(updated, isTrue);
      expect(controller.notificationsEnabled.value, isFalse);
      expect(remote.notificationCalls, <bool>[false]);
    });

    test('an unchanged toggle sends no request', () async {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: true));

      final updated = await controller.toggleNotifications(true);

      expect(updated, isTrue);
      expect(remote.notificationCalls, isEmpty);
    });

    test('a successful toggle keeps the shared session in step', () async {
      final user = _user(notificationsEnabled: true);
      session.setSession(user);
      controller.applyAuthenticatedUser(user);

      await controller.toggleNotifications(false);

      expect(session.currentUser?.notificationsEnabled, isFalse);
      controller.applyAuthenticatedUser(session.currentUser!);
      expect(controller.notificationsEnabled.value, isFalse);
    });

    test('a failed request restores the previous value', () async {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: true));
      remote.onNotificationUpdate = (_) async {
        throw const ApiException(
          'Server error.',
          kind: ApiFailureKind.server,
          statusCode: 500,
        );
      };

      final updated = await controller.toggleNotifications(false);

      expect(updated, isFalse);
      expect(controller.notificationsEnabled.value, isTrue);
      expect(controller.notificationPreferenceError.value, isNotNull);
    });

    test('rapid toggles keep the latest value', () async {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: false));
      final firstRequest = Completer<void>();
      remote.onNotificationUpdate = (enabled) {
        if (enabled) {
          return firstRequest.future;
        }
        return Future<void>.value();
      };

      final first = controller.toggleNotifications(true);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final second = controller.toggleNotifications(false);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(remote.notificationCalls, <bool>[true]);

      firstRequest.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);

      expect(remote.notificationCalls, <bool>[true, false]);
      expect(controller.notificationsEnabled.value, isFalse);
    });

    test('a session without the field keeps the local value', () {
      controller.applyAuthenticatedUser(_user(notificationsEnabled: false));

      controller.applyAuthenticatedUser(_user());

      expect(controller.notificationsEnabled.value, isFalse);
    });
  });
}
