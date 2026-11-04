import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/in_memory_token_storage.dart';
import 'package:test/core/network/token_refresher.dart';
import 'package:test/core/network/token_storage.dart';
import 'package:test/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:test/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';
import 'package:test/features/auth/domain/repositories/auth_repository.dart';
import 'package:test/features/auth/domain/usecases/auth_usecases.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';
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

AuthRepositoryImpl _repository(
  _FakeRemote remote,
  _MemoryTokenStorage tokens, {
  _FakeLocal? local,
}) {
  return AuthRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local ?? _FakeLocal(),
    tokenStorage: tokens,
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
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() => throw UnimplementedError();

  @override
  Future<void> persistSession(AuthSession session) => throw UnimplementedError();
}

class _FakeUseCases extends AuthUseCases {
  _FakeUseCases() : super(const _UnusedRepository());

  int signInCalls = 0;
  int fetchCalls = 0;
  int persistCalls = 0;
  int signOutCalls = 0;

  Future<AuthSession> Function(SignInRequest request)? onSignIn;
  Future<AuthSession> Function()? onFetchCurrentUser;
  Future<void> Function()? onSignOut;

  AuthSession? persisted;

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

typedef _ResponseHandler =
    FutureOr<ResponseBody> Function(
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

    test('temporary /auth/me failure keeps tokens and can be retried',
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
    });

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

    test('confirmed invalid refresh clears tokens and expires the session',
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
    });
  });

  group('controller initialization', () {
    setUp(() {
      Get.reset();
      Get.put<SessionController>(SessionController(), permanent: true);
    });

    tearDown(Get.reset);

    test('signIn saves credentials only and does not fetch current user',
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
    });

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

    test('duplicate initialization reuses the in-flight /auth/me request',
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

      final results = await Future.wait(<Future<AuthSession?>>[first, second]);

      expect(results, hasLength(2));
      expect(useCases.fetchCalls, 1);
      expect(Get.find<SessionController>().currentUser, same(user));
    });

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

    test('a previous account response cannot overwrite the new account',
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
    });
  });
}
