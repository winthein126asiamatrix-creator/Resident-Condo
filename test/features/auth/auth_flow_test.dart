import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData;
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/in_memory_token_storage.dart';
import 'package:test/core/network/token_refresher.dart';
import 'package:test/core/network/token_storage.dart';
import 'package:test/core/network/user_preferences_remote_data_source.dart';
import 'package:test/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:test/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';
import 'package:test/features/auth/domain/repositories/auth_repository.dart';
import 'package:test/features/auth/domain/usecases/auth_usecases.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';
import 'package:test/features/session/domain/entities/resident_session.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

const _oldAccess = 'old-access-token';
const _newAccess = 'new-access-token';
const _oldRefresh = 'old-refresh-token';
const _newRefresh = 'new-refresh-token';

AuthTokens _tokens({
  String accessToken = _oldAccess,
  String refreshToken = _oldRefresh,
}) => AuthTokens(accessToken: accessToken, refreshToken: refreshToken);

AuthUser _user({int id = 6, String name = 'Owner One', String role = 'owner'}) {
  return AuthUser(
    id: id,
    name: name,
    phone: '0811111111',
    role: role,
    email: 'owner$id@example.com',
    unit: const AuthUnit(
      id: 1,
      label: 'Tower A · Unit 1205',
      tower: 'Tower A',
      number: '1205',
    ),
  );
}

Map<String, dynamic> _userJson(AuthUser user) => user.toJson();

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.tokens]);

  AuthTokens? tokens;
  int writes = 0;
  int clears = 0;

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<bool> writeTokens(AuthTokens value) async {
    writes++;
    tokens = value;
    return true;
  }

  @override
  Future<void> clearTokens() async {
    clears++;
    tokens = null;
  }
}

class _FakeRemote extends AuthRemoteDataSource {
  _FakeRemote()
    : super(
        DioApiService(
          tokenStorage: InMemoryTokenStorage(),
          baseUrl: 'https://api.example.com',
        ),
      );

  int signInCalls = 0;
  int updateMeCalls = 0;
  int logoutCalls = 0;
  int refreshCalls = 0;

  Future<AuthResult> Function(SignInRequest request)? onSignIn;
  Future<AuthUser> Function()? onUpdateMe;

  @override
  Future<AuthResult> signIn(SignInRequest request) {
    signInCalls++;
    final handler = onSignIn;
    if (handler == null) {
      return Future<AuthResult>.value(AuthResult(tokens: _tokens()));
    }
    return handler(request);
  }

  @override
  Future<AuthUser> updateMe() {
    updateMeCalls++;
    final handler = onUpdateMe;
    return handler == null ? Future<AuthUser>.value(_user()) : handler();
  }

  @override
  Future<void> logout({
    required String refreshToken,
    required String deviceId,
  }) async {
    logoutCalls++;
  }

  @override
  Future<AuthTokens?> refresh(String refreshToken) async {
    refreshCalls++;
    return null;
  }
}

class _FakePreferencesRemote extends UserPreferencesRemoteDataSource {
  _FakePreferencesRemote()
    : super(
        DioApiService(
          tokenStorage: InMemoryTokenStorage(),
          baseUrl: 'https://api.example.com',
        ),
      );

  int fetchCalls = 0;
  Map<String, dynamic> response = const <String, dynamic>{};
  Object? error;

  @override
  Future<Map<String, dynamic>> fetchPreferences() async {
    fetchCalls++;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return response;
  }
}

class _FakeLocal extends AuthLocalDataSource {
  _FakeLocal() : super(null);

  AuthSession? persisted;
  int persistCalls = 0;
  int signOutCalls = 0;

  @override
  Future<void> persistSession(AuthSession session) async {
    persistCalls++;
    persisted = session;
  }

  @override
  Future<AuthSession?> restoreSession() async => persisted;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    persisted = null;
  }
}

class _FakeCache extends ApiCacheStore {
  // One database instance keeps drift from warning about multiple connections;
  // every method that would touch it is overridden below.
  static final AppCacheDatabase _database = AppCacheDatabase();

  _FakeCache() : super(_database);

  final entries = <String, CachedApiEntry>{};

  @override
  Future<CachedApiEntry?> read(String key) async => entries[key];

  @override
  Future<void> save({
    required String key,
    String? accountKey,
    required Object payload,
  }) async {
    entries[key] = CachedApiEntry(
      key: key,
      accountKey: accountKey,
      payloadJson: jsonEncode(payload),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearAll() async => entries.clear();
}

_FakeCache _cacheWith(AuthUser user) {
  final cache = _FakeCache();
  cache.entries['auth.me'] = CachedApiEntry(
    key: 'auth.me',
    accountKey: user.id.toString(),
    payloadJson: jsonEncode(user.toJson()),
    updatedAt: DateTime.now(),
  );
  return cache;
}

AuthRepositoryImpl _repository(
  _FakeRemote remote,
  _MemoryTokenStorage tokens, {
  _FakeLocal? local,
  _FakePreferencesRemote? preferences,
  _FakeCache? cache,
}) {
  return AuthRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local ?? _FakeLocal(),
    tokenStorage: tokens,
    cacheStore: cache,
    preferencesRemote: preferences,
  );
}

class _UnusedRepository implements AuthRepository {
  const _UnusedRepository();

  @override
  Future<AuthSession> signIn(SignInRequest request) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> fetchCurrentUser() => throw UnimplementedError();

  @override
  Future<AuthSession> updateMe() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  }) => throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() => throw UnimplementedError();

  @override
  Future<void> persistSession(AuthSession session) =>
      throw UnimplementedError();
}

class _FakeUseCases extends AuthUseCases {
  _FakeUseCases() : super(const _UnusedRepository());

  int signInCalls = 0;
  int fetchCalls = 0;
  int persistCalls = 0;
  int signOutCalls = 0;
  int uploadAvatarCalls = 0;
  int updateProfileCalls = 0;

  Future<AuthSession> Function(SignInRequest request)? onSignIn;
  Future<AuthSession> Function()? onFetchCurrentUser;
  Future<void> Function()? onSignOut;
  Future<void> Function(String filePath, String filename, String? mimeType)?
  onUploadAvatar;
  Future<AuthUser> Function(AuthUser currentUser, Map<String, Object?> changes)?
  onUpdateProfile;

  AuthSession? persisted;
  String? uploadedFilePath;
  String? uploadedFilename;
  String? uploadedMimeType;
  AuthUser? updateProfileCurrentUser;
  Map<String, Object?>? updateProfileChanges;

  @override
  Future<AuthSession> signIn(SignInRequest request) {
    signInCalls++;
    final handler = onSignIn;
    if (handler == null) {
      throw StateError('No sign-in handler configured.');
    }
    return handler(request);
  }

  @override
  Future<AuthSession> fetchCurrentUser() {
    fetchCalls++;
    final handler = onFetchCurrentUser;
    if (handler == null) {
      throw StateError('No current-user handler configured.');
    }
    return handler();
  }

  @override
  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) async {
    uploadAvatarCalls++;
    uploadedFilePath = filePath;
    uploadedFilename = filename;
    uploadedMimeType = mimeType;
    await onUploadAvatar?.call(filePath, filename, mimeType);
  }

  @override
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  }) {
    updateProfileCalls++;
    updateProfileCurrentUser = currentUser;
    updateProfileChanges = changes;
    final handler = onUpdateProfile;
    if (handler == null) {
      throw StateError('No profile-update handler configured.');
    }
    return handler(currentUser, changes);
  }

  @override
  Future<void> persistSession(AuthSession session) async {
    persistCalls++;
    persisted = session;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await onSignOut?.call();
  }
}

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

void main() {
  group('repository login and current user', () {
    test('login saves tokens without loading /auth/me', () async {
      final remote = _FakeRemote();
      final storage = _MemoryTokenStorage();
      final repository = _repository(remote, storage);

      final session = await repository.signIn(
        const SignInRequest(username: 'owner1', password: 'secret'),
      );

      expect(session.username, 'owner1');
      expect(session.user, isNull);
      expect(storage.tokens?.accessToken, _oldAccess);
      expect(storage.tokens?.refreshToken, _oldRefresh);
      expect(storage.writes, 1);
      expect(remote.signInCalls, 1);
      expect(remote.updateMeCalls, 0);
    });

    test('login failure does not save tokens', () async {
      final remote = _FakeRemote()
        ..onSignIn = (_) async => throw const ApiException(
          'Bad credentials',
          kind: ApiFailureKind.unauthorized,
          statusCode: 401,
        );
      final storage = _MemoryTokenStorage();
      final repository = _repository(remote, storage);

      await expectLater(
        repository.signIn(
          const SignInRequest(username: 'owner1', password: 'wrong'),
        ),
        throwsA(isA<ApiException>()),
      );

      expect(storage.tokens, isNull);
      expect(storage.writes, 0);
      expect(remote.updateMeCalls, 0);
    });

    test('current-user is a separate /auth/me operation', () async {
      final remote = _FakeRemote();
      final storage = _MemoryTokenStorage();
      final repository = _repository(remote, storage);

      await repository.signIn(
        const SignInRequest(username: 'owner1', password: 'secret'),
      );
      expect(remote.updateMeCalls, 0);

      final session = await repository.fetchCurrentUser();

      expect(session.user, isA<AuthUser>());
      expect((session.user! as AuthUser).name, 'Owner One');
      expect(remote.updateMeCalls, 1);
    });

    test('successful /auth/me merges /me/preferences', () async {
      final remote = _FakeRemote();
      final preferences = _FakePreferencesRemote()
        ..response = <String, dynamic>{
          'theme_color': '#0ea5e9',
          'notifications_enabled': false,
        };
      final repository = _repository(
        remote,
        _MemoryTokenStorage(),
        preferences: preferences,
      );

      final session = await repository.fetchCurrentUser();

      final user = session.user! as AuthUser;
      expect(preferences.fetchCalls, 1);
      expect(user.themeColor, '#0EA5E9');
      expect(user.notificationsEnabled, isFalse);
      expect(user.name, 'Owner One');
    });

    test('a preference failure does not fail /auth/me', () async {
      final remote = _FakeRemote();
      final preferences = _FakePreferencesRemote()
        ..error = const ApiException(
          'Server error.',
          kind: ApiFailureKind.server,
          statusCode: 500,
        );
      final repository = _repository(
        remote,
        _MemoryTokenStorage(),
        preferences: preferences,
      );

      final session = await repository.fetchCurrentUser();

      final user = session.user! as AuthUser;
      expect(preferences.fetchCalls, 1);
      expect(user.name, 'Owner One');
      expect(user.notificationsEnabled, isNull);
    });

    test(
      'temporary /auth/me failure keeps tokens and can be retried',
      () async {
        final remote = _FakeRemote();
        final storage = _MemoryTokenStorage();
        final local = _FakeLocal();
        final repository = _repository(remote, storage, local: local);
        await repository.signIn(
          const SignInRequest(username: 'owner1', password: 'secret'),
        );

        var attempts = 0;
        remote.onUpdateMe = () async {
          attempts++;
          if (attempts == 1) {
            throw const ApiException(
              'No connection.',
              kind: ApiFailureKind.network,
            );
          }
          return _user();
        };

        await expectLater(
          repository.fetchCurrentUser(),
          throwsA(isA<ApiException>()),
        );

        expect(storage.tokens?.accessToken, _oldAccess);
        expect(storage.tokens?.refreshToken, _oldRefresh);
        expect(storage.clears, 0);
        expect(local.signOutCalls, 0);

        final retried = await repository.fetchCurrentUser();

        expect((retried.user! as AuthUser).name, 'Owner One');
        expect(remote.updateMeCalls, 2);
      },
    );

    test('concurrent current-user requests share one /auth/me call', () async {
      final remote = _FakeRemote();
      final storage = _MemoryTokenStorage();
      final repository = _repository(remote, storage);
      await repository.signIn(
        const SignInRequest(username: 'owner1', password: 'secret'),
      );

      final request = Completer<AuthUser>();
      remote.onUpdateMe = () => request.future;

      final first = repository.fetchCurrentUser();
      final second = repository.fetchCurrentUser();
      await Future<void>.delayed(Duration.zero);

      expect(remote.updateMeCalls, 1);

      request.complete(_user());
      final results = await Future.wait(<Future<AuthSession>>[first, second]);

      expect(results, hasLength(2));
      expect((results.first.user! as AuthUser).name, 'Owner One');
      expect((results.last.user! as AuthUser).name, 'Owner One');
      expect(remote.updateMeCalls, 1);
    });
  });

  group('cache-first session restore', () {
    test('cached profile enters without waiting for /auth/me', () async {
      final user = _user();
      final remote = _FakeRemote()
        ..onUpdateMe = () async => throw StateError('must not call /me');
      final storage = _MemoryTokenStorage(_tokens());
      final cache = _cacheWith(user);
      final repository = _repository(remote, storage, cache: cache);

      final restored = await repository.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.unverified, isTrue);
      expect(restored.isSessionVerified, isFalse);
      expect((restored.user! as AuthUser).id, user.id);
      expect(remote.updateMeCalls, 0);
      expect(storage.tokens, isNotNull);
      expect(storage.clears, 0);
    });

    test('revalidation confirms a cached session against /auth/me', () async {
      final user = _user();
      final remote = _FakeRemote();
      final storage = _MemoryTokenStorage(_tokens());
      final repository = _repository(remote, storage, cache: _cacheWith(user));

      final cached = await repository.restoreSession();
      expect(cached!.unverified, isTrue);
      expect(remote.updateMeCalls, 0);

      final verified = await repository.fetchCurrentUser();

      expect(verified.unverified, isFalse);
      expect(verified.isSessionVerified, isTrue);
      expect(remote.updateMeCalls, 1);
    });

    test('no cached profile validates before restoring', () async {
      final user = _user();
      final remote = _FakeRemote();
      final storage = _MemoryTokenStorage(_tokens());
      final repository = _repository(remote, storage, cache: _FakeCache());

      final restored = await repository.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.unverified, isFalse);
      expect((restored.user! as AuthUser).id, user.id);
      expect(remote.updateMeCalls, 1);
    });

    test(
      'temporary failure keeps tokens when there is no cached profile',
      () async {
        final remote = _FakeRemote()
          ..onUpdateMe = () async => throw const ApiException(
            'No connection.',
            kind: ApiFailureKind.network,
          );
        final storage = _MemoryTokenStorage(_tokens());
        final local = _FakeLocal();
        final repository = _repository(
          remote,
          storage,
          local: local,
          cache: _FakeCache(),
        );

        final restored = await repository.restoreSession();

        expect(restored, isNull);
        expect(storage.tokens, isNotNull);
        expect(storage.clears, 0);
        expect(local.signOutCalls, 0);
      },
    );

    test(
      'temporary server error keeps tokens when there is no cached profile',
      () async {
        final remote = _FakeRemote()
          ..onUpdateMe = () async => throw const ApiException(
            'Backend unavailable.',
            kind: ApiFailureKind.server,
            statusCode: 503,
          );
        final storage = _MemoryTokenStorage(_tokens());
        final repository = _repository(remote, storage, cache: _FakeCache());

        final restored = await repository.restoreSession();

        expect(restored, isNull);
        expect(storage.tokens, isNotNull);
        expect(storage.clears, 0);
      },
    );

    test('a rejected session ends the stored credentials', () async {
      final remote = _FakeRemote()
        ..onUpdateMe = () async => throw const ApiException(
          'Session expired.',
          kind: ApiFailureKind.unauthorized,
          statusCode: 401,
        );
      final storage = _MemoryTokenStorage(_tokens());
      final local = _FakeLocal();
      final repository = _repository(
        remote,
        storage,
        local: local,
        cache: _FakeCache(),
      );

      final restored = await repository.restoreSession();

      expect(restored, isNull);
      expect(storage.tokens, isNull);
      expect(storage.clears, 1);
      expect(local.signOutCalls, 1);
    });

    test('a transport failure hidden inside Dio unknown stays retryable', () {
      final exception = ApiException.from(
        DioException(
          requestOptions: RequestOptions(path: '/me'),
          type: DioExceptionType.unknown,
          error: const SocketException('network unreachable'),
        ),
      );

      expect(exception.kind, ApiFailureKind.network);
      expect(exception.isRetryable, isTrue);
    });
  });

  group('profile update', () {
    test('patches /me with only the changed profile fields', () async {
      final current = _user().copyWith(
        avatarUrl: 'https://example.com/avatar.png',
      );
      String? path;
      String? method;
      Object? body;
      String? bearer;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options, _) async {
          path = options.path;
          method = options.method;
          body = options.data;
          bearer = _bearer(options);
          return _json(200, <String, dynamic>{
            'id': 6,
            'name': 'Server Name',
            'phone': '0999999999',
          });
        });
      final remote = AuthRemoteDataSource(
        DioApiService(
          tokenStorage: _MemoryTokenStorage(_tokens()),
          dio: dio,
          baseUrl: 'https://api.example.com',
        ),
      );

      final updated = await remote.updateProfile(
        currentUser: current,
        changes: <String, Object?>{
          'name': 'Server Name',
          'phone': '0999999999',
        },
      );

      expect(path, ApiEndPoints.me);
      expect(method, 'PATCH');
      expect(bearer, 'Bearer $_oldAccess');
      expect(body, <String, Object?>{
        'name': 'Server Name',
        'phone': '0999999999',
      });
      expect(updated.name, 'Server Name');
      expect(updated.phone, '0999999999');
      expect(updated.email, current.email);
      expect(updated.avatarUrl, current.avatarUrl);
      expect(updated.unit?.label, current.unit?.label);
    });

    test('a success message response merges the submitted fields', () async {
      final current = _user().copyWith(
        avatarUrl: 'https://example.com/avatar.png',
      );
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_, _) async =>
              _json(200, <String, dynamic>{'message': 'Profile updated'}),
        );
      final remote = AuthRemoteDataSource(
        DioApiService(
          tokenStorage: _MemoryTokenStorage(_tokens()),
          dio: dio,
          baseUrl: 'https://api.example.com',
        ),
      );

      final updated = await remote.updateProfile(
        currentUser: current,
        changes: <String, Object?>{
          'name': 'Owner Two',
          'email': 'owner2@example.com',
        },
      );

      expect(updated.name, 'Owner Two');
      expect(updated.email, 'owner2@example.com');
      expect(updated.phone, current.phone);
      expect(updated.avatarUrl, current.avatarUrl);
    });
  });

  group('avatar upload', () {
    test('posts the photo as the avatar multipart field', () async {
      final directory = await Directory.systemTemp.createTemp(
        'condo-avatar-test',
      );
      addTearDown(() async {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          // The multipart stream may still hold the temporary file on Windows.
        }
      });
      final photo = File('${directory.path}/avatar.png')
        ..writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);

      FormData? form;
      String? path;
      String? method;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options, _) async {
          path = options.path;
          method = options.method;
          form = options.data as FormData;
          return ResponseBody.fromString('', 204);
        });
      final remote = AuthRemoteDataSource(
        DioApiService(
          tokenStorage: _MemoryTokenStorage(_tokens()),
          dio: dio,
          baseUrl: 'https://api.example.com',
        ),
      );

      await remote.uploadAvatar(
        filePath: photo.path,
        filename: 'avatar.png',
        mimeType: 'image/png',
      );

      expect(path, ApiEndPoints.avatar);
      expect(method, 'POST');
      expect(form?.files, hasLength(1));
      final part = form!.files.single;
      expect(part.key, 'avatar');
      expect(part.value.filename, 'avatar.png');
      expect(part.value.contentType?.mimeType, 'image/png');
    });
  });

  group('current-user uses the existing refresh interceptor', () {
    test('/auth/me 401 refreshes once and replays the request', () async {
      final storage = _MemoryTokenStorage(_tokens());
      var meCalls = 0;
      var refreshCalls = 0;

      final mainDio = Dio()
        ..httpClientAdapter = _FakeAdapter((options, _) async {
          meCalls++;
          final bearer = _bearer(options);
          if (bearer == 'Bearer $_oldAccess') {
            return _json(401, <String, dynamic>{'message': 'expired'});
          }
          if (bearer == 'Bearer $_newAccess') {
            return _json(200, _userJson(_user()));
          }
          return _json(500, <String, dynamic>{'error': 'unexpected bearer'});
        });
      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = _FakeAdapter((_, _) async {
          refreshCalls++;
          return _json(200, <String, dynamic>{
            'access_token': _newAccess,
            'refresh_token': _newRefresh,
          });
        });
      final service = DioApiService(
        tokenStorage: storage,
        dio: mainDio,
        tokenRefresher: TokenRefresher(refreshDio),
        baseUrl: 'https://api.example.com',
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(service),
        localDataSource: _FakeLocal(),
        tokenStorage: storage,
      );

      final session = await repository.fetchCurrentUser();

      expect((session.user! as AuthUser).name, 'Owner One');
      expect(meCalls, 2);
      expect(refreshCalls, 1);
      expect(storage.tokens?.accessToken, _newAccess);
      expect(storage.tokens?.refreshToken, _newRefresh);
    });

    test(
      'confirmed invalid refresh clears tokens and expires the session',
      () async {
        final storage = _MemoryTokenStorage(_tokens());
        var meCalls = 0;
        var refreshCalls = 0;
        var expired = 0;

        final mainDio = Dio()
          ..httpClientAdapter = _FakeAdapter((_, _) async {
            meCalls++;
            return _json(401, <String, dynamic>{'message': 'expired'});
          });
        final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
          ..httpClientAdapter = _FakeAdapter((_, _) async {
            refreshCalls++;
            return _json(401, <String, dynamic>{'message': 'invalid refresh'});
          });
        final service = DioApiService(
          tokenStorage: storage,
          dio: mainDio,
          tokenRefresher: TokenRefresher(refreshDio),
          baseUrl: 'https://api.example.com',
        );

        final session = SessionController()..setSession(_user());
        Get.put<SessionController>(session, permanent: true);
        addTearDown(Get.reset);
        service.onSessionExpired = () {
          expired++;
          session.clearSession();
        };

        final repository = AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSource(service),
          localDataSource: _FakeLocal(),
          tokenStorage: storage,
        );

        await expectLater(
          repository.fetchCurrentUser(),
          throwsA(isA<ApiException>()),
        );

        expect(meCalls, 1);
        expect(refreshCalls, 1);
        expect(storage.tokens, isNull);
        expect(expired, 1);
        expect(session.currentUser, isNull);
      },
    );
  });

  group('controller initialization', () {
    setUp(() {
      Get.reset();
      Get.put<SessionController>(SessionController(), permanent: true);
    });

    tearDown(Get.reset);

    test(
      'signIn saves credentials only and does not fetch current user',
      () async {
        final useCases = _FakeUseCases()
          ..onSignIn = (request) async => AuthSession(
            username: request.username,
            displayName: request.username,
            rememberMe: request.rememberMe,
          );
        final controller = AuthController(useCases)
          ..usernameController.text = 'owner1'
          ..passwordController.text = 'secret';

        final session = await controller.signIn();

        expect(session, isNotNull);
        expect(session!.user, isNull);
        expect(useCases.fetchCalls, 0);
        expect(controller.isInitializingSession.value, isFalse);
        expect(Get.find<SessionController>().isAuthenticated, isFalse);
      },
    );

    test('login failure leaves the session unauthenticated', () async {
      final useCases = _FakeUseCases()
        ..onSignIn = (_) async => throw const AppException('Bad credentials');
      final controller = AuthController(useCases)
        ..usernameController.text = 'owner1'
        ..passwordController.text = 'wrong';

      final session = await controller.signIn();

      expect(session, isNull);
      expect(controller.errorMessage.value, 'Bad credentials');
      expect(useCases.fetchCalls, 0);
      expect(Get.find<SessionController>().isAuthenticated, isFalse);
    });

    test('fetchCurrentUser updates the existing session', () async {
      final user = _user();
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () async => AuthSession(
          username: user.name,
          displayName: user.displayName,
          rememberMe: true,
          user: user,
        );
      final controller = AuthController(useCases);

      final session = await controller.fetchCurrentUser();

      expect((session!.user! as AuthUser).id, user.id);
      expect(Get.find<SessionController>().currentUser, same(user));
      expect(useCases.persistCalls, 1);
      expect(controller.sessionInitializationError.value, isNull);
    });

    test(
      'duplicate initialization reuses the in-flight /auth/me request',
      () async {
        final user = _user();
        final request = Completer<AuthSession>();
        final useCases = _FakeUseCases()
          ..onFetchCurrentUser = () => request.future;
        final controller = AuthController(useCases);

        final first = controller.fetchCurrentUser();
        final second = controller.fetchCurrentUser();
        expect(useCases.fetchCalls, 1);

        request.complete(
          AuthSession(
            username: user.name,
            displayName: user.displayName,
            rememberMe: true,
            user: user,
          ),
        );

        final results = await Future.wait(<Future<AuthSession?>>[
          first,
          second,
        ]);

        expect(results, hasLength(2));
        expect(useCases.fetchCalls, 1);
        expect(Get.find<SessionController>().currentUser, same(user));
      },
    );

    test('logout during /auth/me cannot restore the old session', () async {
      final user = _user();
      final request = Completer<AuthSession>();
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () => request.future;
      final controller = AuthController(useCases);

      final pending = controller.fetchCurrentUser();
      await controller.signOut();

      request.complete(
        AuthSession(
          username: user.name,
          displayName: user.displayName,
          rememberMe: true,
          user: user,
        ),
      );

      expect(await pending, isNull);
      expect(Get.find<SessionController>().currentUser, isNull);
      expect(controller.isInitializingSession.value, isFalse);
    });

    test(
      'a previous account response cannot overwrite the new account',
      () async {
        final firstUser = _user(id: 6, name: 'Owner One');
        final secondUser = _user(id: 9, name: 'Owner Two');
        final firstRequest = Completer<AuthSession>();
        final secondRequest = Completer<AuthSession>();
        final requests = <Completer<AuthSession>>[firstRequest, secondRequest];
        final useCases = _FakeUseCases()
          ..onSignIn = (request) async => AuthSession(
            username: request.username,
            displayName: request.username,
            rememberMe: request.rememberMe,
          );
        useCases.onFetchCurrentUser = () => requests.removeAt(0).future;
        final controller = AuthController(useCases);

        controller.usernameController.text = 'owner1';
        controller.passwordController.text = 'secret';
        await controller.signIn();
        final firstPending = controller.fetchCurrentUser();

        controller.usernameController.text = 'owner2';
        controller.passwordController.text = 'secret';
        await controller.signIn();
        final secondPending = controller.fetchCurrentUser();

        secondRequest.complete(
          AuthSession(
            username: secondUser.name,
            displayName: secondUser.displayName,
            rememberMe: true,
            user: secondUser,
          ),
        );
        expect((await secondPending)!.user, same(secondUser));

        firstRequest.complete(
          AuthSession(
            username: firstUser.name,
            displayName: firstUser.displayName,
            rememberMe: true,
            user: firstUser,
          ),
        );
        expect(await firstPending, isNull);
        expect(Get.find<SessionController>().currentUser, same(secondUser));
      },
    );

    test('avatar upload refreshes the canonical profile', () async {
      final user = _user().copyWith(
        avatarUrl: 'https://api.example.com/web/image/res.users/6/image_1920',
      );
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () async => AuthSession(
          username: user.name,
          displayName: user.displayName,
          rememberMe: true,
          user: user,
        );
      final controller = AuthController(useCases);

      final uploaded = await controller.uploadAvatar(
        filePath: '/tmp/avatar.png',
        filename: 'avatar.png',
        mimeType: 'image/png',
      );

      expect(uploaded, isTrue);
      expect(controller.isUploadingAvatar.value, isFalse);
      expect(controller.avatarUploadError.value, isNull);
      expect(useCases.uploadAvatarCalls, 1);
      expect(useCases.uploadedFilePath, '/tmp/avatar.png');
      expect(useCases.uploadedFilename, 'avatar.png');
      expect(useCases.uploadedMimeType, 'image/png');
      expect(useCases.fetchCalls, 1);
      expect(
        Get.find<SessionController>().currentUser?.avatarUrl,
        user.avatarUrl,
      );
    });

    test('avatar upload failure keeps the current profile', () async {
      final useCases = _FakeUseCases()
        ..onUploadAvatar = (_, _, _) async =>
            throw const AppException('Upload rejected');
      final controller = AuthController(useCases);

      final uploaded = await controller.uploadAvatar(
        filePath: '/tmp/avatar.png',
        filename: 'avatar.png',
      );

      expect(uploaded, isFalse);
      expect(controller.isUploadingAvatar.value, isFalse);
      expect(controller.avatarUploadError.value, 'Upload rejected');
      expect(useCases.fetchCalls, 0);
      expect(Get.find<SessionController>().currentUser, isNull);
    });

    test(
      'profile update publishes the merged user to the shared session',
      () async {
        final current = _user().copyWith(
          avatarUrl: 'https://example.com/avatar.png',
          themeColor: '#123456',
        );
        final session = Get.find<SessionController>()..setSession(current);
        final useCases = _FakeUseCases()
          ..onUpdateProfile = (user, changes) async => AuthUser.mergeProfile(
            null,
            currentUser: user,
            submitted: changes,
          );
        final controller = AuthController(useCases);

        final updated = await controller.updateProfile(
          name: '  Owner Two  ',
          email: ' owner2@example.com ',
          phone: ' 0999999999 ',
        );

        expect(updated, isTrue);
        expect(useCases.updateProfileCalls, 1);
        expect(useCases.updateProfileChanges, <String, Object?>{
          'name': 'Owner Two',
          'phone': '0999999999',
          'email': 'owner2@example.com',
        });
        expect(useCases.persistCalls, 1);
        expect(useCases.persisted?.user, isA<AuthUser>());
        expect((useCases.persisted?.user! as AuthUser).name, 'Owner Two');
        expect(session.currentUser?.name, 'Owner Two');
        expect(session.currentUser?.email, 'owner2@example.com');
        expect(session.currentUser?.phone, '0999999999');
        expect(session.currentUser?.avatarUrl, current.avatarUrl);
        expect(session.currentUser?.themeColor, current.themeColor);
        expect(controller.isUpdatingProfile.value, isFalse);
        expect(controller.profileUpdateError.value, isNull);
      },
    );

    test('profile update sends only the edited fields', () async {
      final current = _user();
      Get.find<SessionController>().setSession(current);
      final useCases = _FakeUseCases()
        ..onUpdateProfile = (user, changes) async =>
            AuthUser.mergeProfile(null, currentUser: user, submitted: changes);
      final controller = AuthController(useCases);

      final updated = await controller.updateProfile(
        name: current.name,
        email: current.email ?? '',
        phone: '0999999999',
      );

      expect(updated, isTrue);
      expect(useCases.updateProfileChanges, <String, Object?>{
        'phone': '0999999999',
      });
    });

    test(
      'duplicate profile updates are ignored while one is in flight',
      () async {
        final current = _user();
        Get.find<SessionController>().setSession(current);
        final request = Completer<AuthUser>();
        final useCases = _FakeUseCases()
          ..onUpdateProfile = (_, _) => request.future;
        final controller = AuthController(useCases);

        final first = controller.updateProfile(
          name: 'Owner Two',
          email: current.email ?? '',
          phone: current.phone,
        );
        final second = await controller.updateProfile(
          name: 'Owner Three',
          email: current.email ?? '',
          phone: current.phone,
        );

        expect(second, isFalse);
        expect(useCases.updateProfileCalls, 1);

        request.complete(
          AuthUser.mergeProfile(
            null,
            currentUser: current,
            submitted: const <String, Object?>{'name': 'Owner Two'},
          ),
        );
        expect(await first, isTrue);
        expect(Get.find<SessionController>().currentUser?.name, 'Owner Two');
      },
    );

    test(
      'a rejected profile update keeps the current user and reports it',
      () async {
        final current = _user();
        final session = Get.find<SessionController>()..setSession(current);
        final useCases = _FakeUseCases()
          ..onUpdateProfile = (_, _) async => throw const ApiException(
            'Invalid phone',
            kind: ApiFailureKind.validation,
            statusCode: 422,
          );
        final controller = AuthController(useCases);

        final updated = await controller.updateProfile(
          name: 'Owner Two',
          email: 'owner2@example.com',
          phone: 'not-a-phone',
        );

        expect(updated, isFalse);
        expect(useCases.persistCalls, 0);
        expect(controller.profileUpdateError.value, 'profileUpdateInvalid');
        expect(controller.isUpdatingProfile.value, isFalse);
        expect(session.currentUser, same(current));
      },
    );

    test(
      'a profile refresh failure does not undo an accepted upload',
      () async {
        final useCases = _FakeUseCases()
          ..onFetchCurrentUser = () async => throw const ApiException(
            'No connection.',
            kind: ApiFailureKind.network,
          );
        final controller = AuthController(useCases);

        final uploaded = await controller.uploadAvatar(
          filePath: '/tmp/avatar.png',
          filename: 'avatar.png',
        );

        expect(uploaded, isTrue);
        expect(controller.avatarUploadError.value, isNull);
        expect(useCases.uploadAvatarCalls, 1);
        expect(useCases.fetchCalls, 1);
        expect(controller.sessionInitializationError.value, 'No connection.');
      },
    );
  });

  group('cache-first revalidation', () {
    setUp(() {
      Get.reset();
      Get.put<SessionController>(SessionController(), permanent: true);
    });

    tearDown(Get.reset);

    void admitUnverified(AuthUser user) {
      Get.find<SessionController>().setSession(
        user,
        verificationStatus: SessionVerificationStatus.unverified,
      );
    }

    Future<AuthSession> verifiedSession(AuthUser user) async => AuthSession(
      username: user.name,
      displayName: user.displayName,
      rememberMe: true,
      user: user,
    );

    test('a reachable backend confirms the cached session in place', () async {
      final user = _user();
      admitUnverified(user);
      final updated = user.copyWith(phone: '0999999999');
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () => verifiedSession(updated);
      final controller = AuthController(useCases)..isUnverified.value = true;

      await controller.revalidateSession();

      expect(useCases.fetchCalls, 1);
      expect(useCases.persistCalls, 1);
      expect(controller.isUnverified.value, isFalse);
      expect(controller.sessionInitializationError.value, isNull);
      expect(Get.find<SessionController>().currentUser?.phone, '0999999999');
      expect(Get.find<SessionController>().isSessionVerified, isTrue);
    });

    test('a temporary network failure keeps the cached session', () async {
      final user = _user();
      admitUnverified(user);
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () async => throw const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = AuthController(useCases)..isUnverified.value = true;

      await controller.revalidateSession();

      expect(useCases.persistCalls, 0);
      expect(useCases.signOutCalls, 0);
      expect(controller.isUnverified.value, isTrue);
      expect(Get.find<SessionController>().currentUser, same(user));
      expect(Get.find<SessionController>().isSessionVerified, isFalse);
    });

    test('a temporary server error keeps the cached session', () async {
      final user = _user();
      admitUnverified(user);
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () async => throw const ApiException(
          'Backend unavailable.',
          kind: ApiFailureKind.server,
          statusCode: 503,
        );
      final controller = AuthController(useCases)..isUnverified.value = true;

      await controller.revalidateSession();

      expect(useCases.signOutCalls, 0);
      expect(controller.isUnverified.value, isTrue);
      expect(Get.find<SessionController>().currentUser, same(user));
    });

    test(
      'connectivity restoration revalidates after a failed attempt',
      () async {
        final user = _user();
        admitUnverified(user);
        var online = false;
        final useCases = _FakeUseCases()
          ..onFetchCurrentUser = () async {
            if (!online) {
              throw const ApiException(
                'No connection.',
                kind: ApiFailureKind.network,
              );
            }
            return verifiedSession(user);
          };
        final controller = AuthController(useCases)..isUnverified.value = true;

        await controller.revalidateSession();
        expect(controller.isUnverified.value, isTrue);
        expect(Get.find<SessionController>().currentUser, same(user));

        online = true;
        await controller.revalidateSession();
        expect(controller.isUnverified.value, isFalse);
        expect(Get.find<SessionController>().isSessionVerified, isTrue);
      },
    );

    test('a 401 follows the existing logout flow', () async {
      final user = _user();
      admitUnverified(user);
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () async => throw const ApiException(
          'Session expired.',
          kind: ApiFailureKind.unauthorized,
          statusCode: 401,
        );
      final controller = AuthController(useCases)..isUnverified.value = true;

      await controller.revalidateSession();

      expect(useCases.signOutCalls, 1);
      expect(Get.find<SessionController>().currentUser, isNull);
      expect(controller.isUnverified.value, isFalse);
    });

    test('concurrent revalidations share one /auth/me request', () async {
      final user = _user();
      final request = Completer<AuthSession>();
      final useCases = _FakeUseCases()
        ..onFetchCurrentUser = () => request.future;
      final controller = AuthController(useCases);

      final first = controller.revalidateSession();
      final second = controller.revalidateSession();
      expect(useCases.fetchCalls, 1);

      request.complete(await verifiedSession(user));
      await Future.wait(<Future<void>>[first, second]);

      expect(useCases.fetchCalls, 1);
      expect(useCases.persistCalls, 1);
      expect(Get.find<SessionController>().currentUser, same(user));
    });

    test('a late response cannot overwrite a newer login', () async {
      final oldUser = _user(id: 6, name: 'Owner One');
      admitUnverified(oldUser);
      final request = Completer<AuthSession>();
      final useCases = _FakeUseCases();
      useCases.onFetchCurrentUser = () => request.future;
      useCases.onSignIn = (signIn) async => AuthSession(
        username: signIn.username,
        displayName: signIn.username,
        rememberMe: signIn.rememberMe,
      );
      final controller = AuthController(useCases)
        ..isUnverified.value = true
        ..usernameController.text = 'owner2'
        ..passwordController.text = 'secret';

      final pending = controller.revalidateSession();
      await controller.signIn();
      request.complete(await verifiedSession(oldUser));
      await pending;

      expect(Get.find<SessionController>().currentUser, isNull);
      expect(Get.find<SessionController>().isSessionVerified, isFalse);
      expect(controller.isUnverified.value, isFalse);
    });
  });
}
