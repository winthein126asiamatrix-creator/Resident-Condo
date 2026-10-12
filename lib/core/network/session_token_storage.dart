import 'in_memory_token_storage.dart';
import 'token_storage.dart';

/// Routes the session's token pair between durable and in-memory storage.
///
/// The network layer holds a single [TokenStorage] for the whole app: the auth
/// interceptor reads the access token from it on every request, and the refresh
/// interceptor reads the refresh token from it. Remember Me cannot therefore be
/// honoured by giving a session its own store — it has to be honoured by
/// deciding, once per sign-in, which backing store that one instance talks to.
///
/// * Remember Me on: the pair is written to the platform keychain, so it
///   survives a process restart and `AuthRepositoryImpl.restoreSession` finds
///   it on the next launch.
/// * Remember Me off: the pair is held in memory only. It is gone with the
///   process, so a restart has nothing to restore and the resident signs in
///   again — while the app is running, requests and token refresh behave
///   exactly as they do in the remembered case.
///
/// Background and resume are unaffected either way: the process keeps running,
/// so the in-memory pair is still there when the app comes back.
class SessionTokenStorage implements TokenStorage {
  SessionTokenStorage(this._durable);

  /// The platform keychain, where a remembered pair has to live.
  final TokenStorage _durable;

  /// Set while the current session asked not to be remembered.
  InMemoryTokenStorage? _volatile;

  TokenStorage get _active => _volatile ?? _durable;

  /// Points the store at the keychain (Remember Me on) or at a fresh in-memory
  /// holder (Remember Me off).
  ///
  /// Switching to in-memory first drops anything already in the durable store.
  /// Signing in without Remember Me must not leave a pair persisted by an
  /// earlier remembered sign-in behind, or the next launch would restore a
  /// session this sign-in was explicitly told not to keep.
  Future<void> useSession({required bool persistent}) async {
    if (persistent) {
      _volatile = null;
      return;
    }
    await _durable.clearTokens();
    _volatile = InMemoryTokenStorage();
  }

  @override
  Future<AuthTokens?> readTokens() => _active.readTokens();

  @override
  Future<bool> writeTokens(AuthTokens tokens) => _active.writeTokens(tokens);

  @override
  Future<void> clearTokens() async {
    // Both, always. A logout has to end the session whichever backing store it
    // was using, and must not leave the other one holding a usable pair for a
    // session the resident believes has ended.
    await _durable.clearTokens();
    await _volatile?.clearTokens();
  }
}
