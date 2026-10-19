import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/session_token_storage.dart';
import 'package:test/core/network/token_storage.dart';
import 'package:test/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:test/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:test/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';
import 'package:test/features/auth/domain/repositories/auth_repository.dart';
import 'package:test/features/auth/domain/usecases/auth_usecases.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';

/// A durable store the test can inspect, standing in for the platform keychain.
///
/// The real `SecureTokenStorage` cannot be used here: with no plugin registered
/// its reads return null and its writes report failure, so a remembered pair
/// would look as though it had never been written.
class _FakeDurableStore implements TokenStorage {
  AuthTokens? _tokens;

  bool get hasPair => _tokens != null;

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<bool> writeTokens(AuthTokens tokens) async {
    _tokens = tokens;
    return true;
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }
}

/// Serves the two endpoints the auth flow calls, so the real
/// [AuthRemoteDataSource] and [TokenParser] run unmodified.
Dio _mockApiDio() {
  const loginBody = <String, Object?>{
    'id': 15,
    'username': 'emilys',
    'email': 'emily.johnson@example.com',
    'firstName': 'Emily',
    'lastName': 'Johnson',
    'gender': 'female',
    'image': 'https://example.com/emily.png',
    'accessToken': 'access-abc',
    'refreshToken': 'refresh-xyz',
  };
  const meBody = <String, Object?>{
    'id': 15,
    'username': 'emilys',
    'email': 'emily.johnson@example.com',
    'firstName': 'Emily',
    'lastName': 'Johnson',
    'gender': 'female',
    'image': 'https://example.com/emily.png',
  };

  final dio = Dio(BaseOptions(baseUrl: 'https://dummyjson.com'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: options.path == ApiEndPoints.login ? loginBody : meBody,
          ),
        );
      },
    ),
  );
  return dio;
}

/// Wires the repository exactly as `AuthBinding` does: one switchable store
/// shared by the repository and the HTTP client.
AuthRepositoryImpl _buildRepository(_FakeDurableStore durable) {
  final storage = SessionTokenStorage(durable);
  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSource(
      DioApiService(
        tokenStorage: storage,
        dio: _mockApiDio(),
        // Injected rather than resolved from the build's flavor, which a test
        // run has none of.
        baseUrl: 'https://dummyjson.com',
      ),
    ),
    localDataSource: AuthLocalDataSource(),
    tokenStorage: storage,
  );
}

const _signIn = SignInRequest(username: 'emilys', password: 'emilyspass');

void main() {
  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // The real data source pretty-prints every payload it handles, which buries
    // the test output. Nothing here is asserting on the log.
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  group('Remember Me', () {
    test('on: the pair reaches the keychain, so a restart restores it', () async {
      final durable = _FakeDurableStore();
      final repository = _buildRepository(durable);

      final session = await repository.signIn(_signIn);
      expect(session.rememberMe, isTrue);
      expect(durable.hasPair, isTrue);

      // A restart is a new process: a fresh container over the same keychain.
      final restarted = _buildRepository(durable);
      final restored = await restarted.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.displayName, 'Emily Johnson');
    });

    test('off: the pair never reaches the keychain, so a restart cannot restore',
        () async {
      final durable = _FakeDurableStore();
      final repository = _buildRepository(durable);

      final session = await repository.signIn(
        const SignInRequest(username: 'emilys', password: 'emilyspass', rememberMe: false),
      );
      expect(session.rememberMe, isFalse);
      expect(
        durable.hasPair,
        isFalse,
        reason: 'an unremembered pair must not be readable after a restart',
      );

      // While this process lives the session is fully usable: the pair is
      // readable and /auth/me validates it.
      final live = await repository.restoreSession();
      expect(live, isNotNull);

      // A restart is a new process: nothing durable, nothing to restore.
      final restarted = _buildRepository(durable);
      expect(await restarted.restoreSession(), isNull);
    });

    test('off after on: the previously remembered pair is dropped', () async {
      final durable = _FakeDurableStore();
      final repository = _buildRepository(durable);

      await repository.signIn(_signIn);
      expect(durable.hasPair, isTrue);

      await repository.signIn(const SignInRequest(username: 'emilys', password: 'emilyspass', rememberMe: false));
      expect(durable.hasPair, isFalse);
    });

    test('logout clears the pair whichever mode was used', () async {
      final durable = _FakeDurableStore();
      final repository = _buildRepository(durable);

      await repository.signIn(_signIn);
      await repository.signOut();
      expect(durable.hasPair, isFalse);
    });
  });

  group('SessionTokenStorage', () {
    test('clearTokens clears both backings', () async {
      final durable = _FakeDurableStore();
      final storage = SessionTokenStorage(durable);

      await storage.useSession(persistent: false);
      await storage.writeTokens(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      await storage.useSession(persistent: true);
      await storage.writeTokens(
        const AuthTokens(accessToken: 'b', refreshToken: 's'),
      );

      await storage.clearTokens();

      expect(durable.hasPair, isFalse);
      expect(await storage.readTokens(), isNull);
    });
  });

  group('AuthController', () {
    test('defaults Remember Me on and sends it with the request', () async {
      final repository = _RecordingRepository();
      final controller = AuthController(AuthUseCases(repository));

      expect(controller.rememberMe.value, isTrue);

      controller.usernameController.text = 'emilys';
      controller.passwordController.text = 'emilyspass';

      await controller.signIn();
      expect(repository.lastRequest!.rememberMe, isTrue);

      controller.toggleRememberMe();
      expect(controller.rememberMe.value, isFalse);

      await controller.signIn();
      expect(repository.lastRequest!.rememberMe, isFalse);
    });
  });
}

/// Captures the sign-in request so the controller's Remember Me value can be
/// asserted without a network.
class _RecordingRepository implements AuthRepository {
  SignInRequest? lastRequest;

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    lastRequest = request;
    return AuthSession(
      username: request.username,
      displayName: 'Emily Johnson',
      rememberMe: request.rememberMe,
    );
  }

  @override
  Future<AuthSession> updateMe() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() => throw UnimplementedError();

  @override
  Future<void> persistSession(AuthSession session) =>
      throw UnimplementedError();
}
