import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../network/dio_api_service.dart';

/// The image formats an avatar endpoint may return.
enum AuthenticatedAvatarFormat { raster, svg }

/// One decoded avatar payload and how it should be rendered.
class AuthenticatedAvatarData {
  const AuthenticatedAvatarData({
    required this.bytes,
    required this.format,
    this.contentType,
  });

  final Uint8List bytes;
  final AuthenticatedAvatarFormat format;
  final String? contentType;
}

/// Fetches avatar bytes through the shared authenticated client.
///
/// The cache is keyed by URL and the in-flight map deduplicates concurrent
/// requests, so a dashboard and a profile mounted together download an avatar
/// once. Failures are not cached, which lets a later attempt recover.
class AuthenticatedAvatarLoader {
  AuthenticatedAvatarLoader(this._service, {this.maxEntries = 32});

  final DioApiService _service;
  final int maxEntries;

  final Map<String, AuthenticatedAvatarData> _cache =
      <String, AuthenticatedAvatarData>{};
  final Map<String, Future<AuthenticatedAvatarData?>> _inFlight =
      <String, Future<AuthenticatedAvatarData?>>{};

  Future<AuthenticatedAvatarData?> load(String url, {bool force = false}) {
    final cached = _cache[url];
    if (cached != null && !force) {
      _cache
        ..remove(url)
        ..[url] = cached;
      return Future<AuthenticatedAvatarData?>.value(cached);
    }

    final pending = _inFlight[url];
    if (pending != null) {
      return pending;
    }

    final future = _download(url);
    _inFlight[url] = future;
    return future.whenComplete(() {
      _inFlight.remove(url);
    });
  }

  /// Drops every cached avatar, for a sign-out or an explicit refresh.
  void clear() => _cache.clear();

  Future<AuthenticatedAvatarData?> _download(String url) async {
    try {
      final response = await _service.getBytes(url);
      final format = detectFormat(response.bytes);
      if (format == null) {
        return null;
      }
      final data = AuthenticatedAvatarData(
        bytes: response.bytes,
        format: format,
        contentType: response.contentType,
      );
      _cache[url] = data;
      _trim();
      return data;
    } catch (_) {
      return null;
    }
  }

  void _trim() {
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Classifies bytes by their signature rather than trusting the status code
  /// or content type, so a JSON or HTML error page is never fed to a decoder.
  static AuthenticatedAvatarFormat? detectFormat(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    if (_looksLikeSvg(bytes)) {
      return AuthenticatedAvatarFormat.svg;
    }
    if (_isPng(bytes) ||
        _isJpeg(bytes) ||
        _isGif(bytes) ||
        _isWebp(bytes) ||
        _isBmp(bytes)) {
      return AuthenticatedAvatarFormat.raster;
    }
    return null;
  }

  static bool _looksLikeSvg(Uint8List bytes) {
    final prefix = bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes;
    final text = utf8
        .decode(prefix, allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .trimLeft();
    if (text.startsWith('<svg')) {
      return true;
    }
    return text.startsWith('<?xml') && text.contains('<svg');
  }

  static bool _isPng(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;

  static bool _isJpeg(Uint8List b) =>
      b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  static bool _isGif(Uint8List b) =>
      b.length >= 6 &&
      b[0] == 0x47 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x38 &&
      (b[4] == 0x37 || b[4] == 0x39) &&
      b[5] == 0x61;

  static bool _isWebp(Uint8List b) =>
      b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50;

  static bool _isBmp(Uint8List b) =>
      b.length >= 2 && b[0] == 0x42 && b[1] == 0x4D;
}

/// Renders an authenticated avatar, falling back to [fallback] while loading,
/// when the URL is empty, and when the response cannot be decoded.
class AuthenticatedAvatar extends StatefulWidget {
  const AuthenticatedAvatar({
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.loader,
    super.key,
  });

  final String? url;
  final Widget fallback;
  final BoxFit fit;

  /// Injectable for tests; the app uses one loader shared by every avatar.
  final AuthenticatedAvatarLoader? loader;

  @override
  State<AuthenticatedAvatar> createState() => _AuthenticatedAvatarState();
}

class _AuthenticatedAvatarState extends State<AuthenticatedAvatar> {
  AuthenticatedAvatarLoader? _loader;
  AuthenticatedAvatarData? _data;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loader = widget.loader ?? _sharedLoader();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.loader != widget.loader) {
      _loader = widget.loader ?? _sharedLoader();
      _data = null;
      _load();
    }
  }

  void _load() {
    final url = widget.url?.trim() ?? '';
    final loader = _loader;
    if (url.isEmpty || loader == null) {
      _data = null;
      return;
    }

    final request = ++_request;
    loader.load(url).then((data) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() => _data = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Center(child: widget.fallback);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight;
        final width = bounded ? constraints.maxWidth : null;
        final height = bounded ? constraints.maxHeight : null;

        if (data.format == AuthenticatedAvatarFormat.svg) {
          return ClipOval(
            child: SvgPicture.memory(
              data.bytes,
              fit: widget.fit,
              width: width,
              height: height,
              placeholderBuilder: (_) => Center(child: widget.fallback),
              errorBuilder: (_, _, _) => Center(child: widget.fallback),
            ),
          );
        }

        return ClipOval(
          child: Image.memory(
            data.bytes,
            fit: widget.fit,
            width: width,
            height: height,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Center(child: widget.fallback),
          ),
        );
      },
    );
  }
}

AuthenticatedAvatarLoader? _sharedLoaderInstance;
DioApiService? _sharedLoaderService;

AuthenticatedAvatarLoader? _sharedLoader() {
  if (!Get.isRegistered<DioApiService>()) {
    return null;
  }
  final service = Get.find<DioApiService>();
  if (!identical(service, _sharedLoaderService)) {
    _sharedLoaderService = service;
    _sharedLoaderInstance = AuthenticatedAvatarLoader(service);
  }
  return _sharedLoaderInstance;
}
