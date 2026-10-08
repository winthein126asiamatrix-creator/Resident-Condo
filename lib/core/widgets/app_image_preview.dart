import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_theme_tokens.dart';

/// A photo attached to a request, shown as a tappable card.
///
/// Tapping opens the full screen viewer, so the details page stays short and the
/// resident can still look at the photo properly. Uses the same surface,
/// radius and border as the rest of the app's cards.
class AppImagePreview extends StatelessWidget {
  const AppImagePreview({
    required this.path,
    required this.caption,
    this.height = 180,
    super.key,
  });

  /// Location of the image on the device.
  final String path;

  /// File name, shown under the image.
  final String caption;

  /// Enough to read the photo without making the page long.
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Semantics(
      button: true,
      image: true,
      label: '$caption, attached photo. Opens a larger preview.',
      child: Material(
        color: tokens.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showAppImageViewer(
            context: context,
            path: path,
            caption: caption,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: _LocalImage(path: path),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_outlined,
                      size: 15,
                      color: tokens.muted,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.zoom_out_map_rounded,
                      size: 15,
                      color: tokens.faint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen preview with pinch to zoom, pan and an obvious way out.
///
/// [InteractiveViewer] is part of Flutter, so this needs no extra package.
Future<void> showAppImageViewer({
  required BuildContext context,
  required String path,
  required String caption,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (routeContext, animation, secondaryAnimation) =>
          _AppImageViewer(path: path, caption: caption),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _AppImageViewer extends StatelessWidget {
  const _AppImageViewer({required this.path, required this.caption});

  final String path;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: _LocalImage(path: path, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    // Large enough to hit comfortably with one thumb.
                    IconButton(
                      key: const Key('image-viewer-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close preview',
                      iconSize: 26,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A local file rendered with a graceful fallback, so a missing or unreadable
/// file never breaks the page.
class _LocalImage extends StatelessWidget {
  const _LocalImage({required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      // A missing or unreadable file must not break the page.
      errorBuilder: (context, error, stackTrace) => const _ImageFallback(),
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) {
          return child;
        }
        // A still placeholder rather than a spinner: a local file appears in a
        // frame or two, so an animation here would only add noise.
        return const _ImageFallback(loading: true);
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return ColoredBox(
      color: tokens.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              loading
                  ? Icons.image_outlined
                  : Icons.image_not_supported_outlined,
              size: 30,
              color: tokens.faint,
            ),
            if (!loading) ...[
              const SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: TextStyle(color: tokens.muted, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
