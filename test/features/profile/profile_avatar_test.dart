import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:test/core/services/photo_picker.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';
import 'package:test/features/auth/domain/repositories/auth_repository.dart';
import 'package:test/features/auth/domain/usecases/auth_usecases.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';
import 'package:test/features/profile/presentation/controllers/profile_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

AuthUser _user() {
  return const AuthUser(
    id: 6,
    name: 'Owner One',
    phone: '0811111111',
    role: 'owner',
    avatarUrl: 'https://example.com/avatar.png',
  );
}

AttachedPhoto _photo({
  String name = 'avatar.png',
  String? mimeType = 'image/png',
  int? sizeBytes = 1024,
}) {
  return AttachedPhoto(
    path: '/tmp/$name',
    name: name,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
  );
}

class _FakePhotoPicker implements PhotoPicker {
  _FakePhotoPicker(this.result);

  PhotoPickResult result;
  int calls = 0;
  ImageSource? source;
  Completer<void>? gate;

  @override
  Future<PhotoPickResult> pick(ImageSource source) async {
    calls++;
    this.source = source;
    await gate?.future;
    return result;
  }
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

class _FakeAuthController extends AuthController {
  _FakeAuthController() : super(const AuthUseCases(_UnusedRepository()));

  bool result = true;
  String? failureMessage;
  int calls = 0;
  String? filePath;
  String? filename;
  String? mimeType;

  @override
  Future<bool> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) async {
    calls++;
    this.filePath = filePath;
    this.filename = filename;
    this.mimeType = mimeType;
    if (!result) {
      avatarUploadError.value = failureMessage ?? 'Upload failed';
    }
    return result;
  }
}

void main() {
  test('uploads a gallery photo and passes its metadata through', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(
      PhotoPickResult.success(_photo(sizeBytes: 2048)),
    );
    final auth = _FakeAuthController();
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final uploaded = await controller.pickAndUploadAvatar();

    expect(uploaded, isTrue);
    expect(picker.calls, 1);
    expect(picker.source, ImageSource.gallery);
    expect(auth.calls, 1);
    expect(auth.filePath, '/tmp/avatar.png');
    expect(auth.filename, 'avatar.png');
    expect(auth.mimeType, 'image/png');
    expect(controller.avatarError.value, isNull);
    expect(controller.isPickingAvatar.value, isFalse);
  });

  test('a cancelled picker changes nothing and reports no error', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(const PhotoPickResult.cancelled());
    final auth = _FakeAuthController();
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final uploaded = await controller.pickAndUploadAvatar();

    expect(uploaded, isFalse);
    expect(auth.calls, 0);
    expect(controller.avatarError.value, isNull);
  });

  test('picker failures are shown to the resident', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(
      const PhotoPickResult.failure('Photo access is off.'),
    );
    final auth = _FakeAuthController();
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final uploaded = await controller.pickAndUploadAvatar();

    expect(uploaded, isFalse);
    expect(auth.calls, 0);
    expect(controller.avatarError.value, 'Photo access is off.');
  });

  test('rejects an unsupported image before uploading', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(
      PhotoPickResult.success(
        _photo(name: 'avatar.gif', mimeType: 'image/gif'),
      ),
    );
    final auth = _FakeAuthController();
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final uploaded = await controller.pickAndUploadAvatar();

    expect(uploaded, isFalse);
    expect(auth.calls, 0);
    expect(controller.avatarError.value, 'photoUnsupported');
  });

  test('rejects an image larger than the avatar limit', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(
      PhotoPickResult.success(
        _photo(sizeBytes: ProfileController.maxAvatarBytes + 1),
      ),
    );
    final auth = _FakeAuthController();
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final uploaded = await controller.pickAndUploadAvatar();

    expect(uploaded, isFalse);
    expect(auth.calls, 0);
    expect(controller.avatarError.value, 'photoTooLarge');
  });

  test('an upload failure surfaces the auth reason', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(PhotoPickResult.success(_photo()));
    final auth = _FakeAuthController()
      ..result = false
      ..failureMessage = 'Upload rejected';
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final uploaded = await controller.pickAndUploadAvatar();

    expect(uploaded, isFalse);
    expect(controller.avatarError.value, 'Upload rejected');
  });

  test('ignores a tap while a photo is being picked or uploaded', () async {
    final session = SessionController()..setSession(_user());
    final picker = _FakePhotoPicker(PhotoPickResult.success(_photo()))
      ..gate = Completer<void>();
    final auth = _FakeAuthController();
    final controller = ProfileController(
      session,
      photoPicker: picker,
      authController: auth,
    );

    final first = controller.pickAndUploadAvatar();
    expect(await controller.pickAndUploadAvatar(), isFalse);
    picker.gate!.complete();
    expect(await first, isTrue);
    expect(picker.calls, 1);

    auth.isUploadingAvatar.value = true;
    expect(await controller.pickAndUploadAvatar(), isFalse);
    expect(picker.calls, 1);
  });
}
