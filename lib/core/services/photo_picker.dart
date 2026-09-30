import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// A photo the resident attached to a request.
///
/// Only the local file and its name are held: the repository does not upload
/// attachments yet, so the request carries the names and the app keeps the paths
/// around for the preview.
class AttachedPhoto {
  const AttachedPhoto({required this.path, required this.name});

  /// Path of the picked file on the device.
  final String path;

  /// File name, sent along with the request.
  final String name;
}

/// Outcome of a single pick attempt.
///
/// A cancelled picker is not an error: the resident simply changed their mind,
/// so it gets its own case and the form is left untouched.
class PhotoPickResult {
  const PhotoPickResult.success(AttachedPhoto this.photo) : error = null;

  const PhotoPickResult.cancelled() : photo = null, error = null;

  const PhotoPickResult.failure(this.error) : photo = null;

  final AttachedPhoto? photo;

  /// Resident facing message when the pick could not be completed, typically a
  /// denied permission or a device without a usable camera.
  final String? error;
}

/// Picks a photo from the device. Implemented over `image_picker` so screens
/// depend on this small interface and tests can supply their own.
abstract interface class PhotoPicker {
  Future<PhotoPickResult> pick(ImageSource source);
}

class DevicePhotoPicker implements PhotoPicker {
  const DevicePhotoPicker();

  @override
  Future<PhotoPickResult> pick(ImageSource source) async {
    final isCamera = source == ImageSource.camera;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        // Full resolution photos are pointless for a maintenance report and
        // cost a lot of memory on a low end phone.
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) {
        return const PhotoPickResult.cancelled();
      }
      return PhotoPickResult.success(
        AttachedPhoto(path: file.path, name: file.name),
      );
    } on PlatformException catch (error) {
      return PhotoPickResult.failure(
        _messageFor(error.code, isCamera: isCamera),
      );
    } catch (_) {
      return PhotoPickResult.failure(
        isCamera
            ? 'The camera is unavailable right now.'
            : 'Unable to open your photos right now.',
      );
    }
  }

  /// Turns the plugin error codes into something a resident can act on.
  String _messageFor(String code, {required bool isCamera}) {
    switch (code) {
      case 'camera_access_denied':
      case 'photo_access_denied':
        return isCamera
            ? 'Camera access is off. Enable it in your device settings to take a photo.'
            : 'Photo access is off. Enable it in your device settings to attach a photo.';
      case 'camera_access_restricted':
        return 'Camera access is restricted on this device.';
      case 'no_available_camera':
        return 'No camera was found on this device.';
      default:
        return isCamera
            ? 'The camera is unavailable right now.'
            : 'Unable to open your photos right now.';
    }
  }
}
