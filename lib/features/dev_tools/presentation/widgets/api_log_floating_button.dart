import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/network/api_log_store.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/haptics.dart';

/// The draggable dev entry point to the API log viewer.
///
/// It is mounted once by the root `GetMaterialApp.builder`, in a stack above
/// the navigator. Sitting there means every route, dialog and bottom sheet
/// shares the same button without any screen needing to know about it.
class ApiLogFloatingButton extends StatefulWidget {
  const ApiLogFloatingButton({super.key});

  @override
  State<ApiLogFloatingButton> createState() => _ApiLogFloatingButtonState();
}

class _ApiLogFloatingButtonState extends State<ApiLogFloatingButton> {
  static const double _size = 46;
  static const double _edge = 10;

  Offset? _position;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ApiLogStore>()) {
      return const SizedBox.shrink();
    }

    final store = Get.find<ApiLogStore>();
    return Obx(() {
      if (!store.isOverlayVisible.value) {
        return const SizedBox.shrink();
      }
      return _buildButton(context);
    });
  }

  Widget _buildButton(BuildContext context) {
    final media = MediaQuery.of(context);
    final current = _currentPosition(media);
    final clamped = _clamp(current, media);

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onTap: _openLogs,
        onDoubleTap: _hideOverlay,
        onPanUpdate: (details) {
          setState(() {
            _position = _clamp((_position ?? current) + details.delta, media);
          });
        },
        // This widget lives above the navigator's Overlay, so it must not use
        // Tooltip. Semantics keeps it labelled without requiring an Overlay.
        child: Semantics(
          label: 'API logs',
          button: true,
          child: Material(
            color: Color.alphaBlend(
              Colors.black.withValues(alpha: 0.22),
              AppThemeTokens.of(context).brand,
            ),
            elevation: 6,
            shadowColor: Colors.black54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppPalette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _currentPosition(MediaQueryData media) {
    final right = media.size.width - _size - _edge;
    final top = (media.size.height * 0.62).clamp(
      _minTop(media),
      _maxTop(media),
    );
    return _position ?? Offset(right, top.toDouble());
  }

  Offset _clamp(Offset position, MediaQueryData media) {
    return Offset(
      position.dx
          .clamp(
            _edge,
            (media.size.width - _size - _edge).clamp(_edge, double.infinity),
          )
          .toDouble(),
      position.dy.clamp(_minTop(media), _maxTop(media)).toDouble(),
    );
  }

  double _minTop(MediaQueryData media) => media.padding.top + _edge;

  double _maxTop(MediaQueryData media) =>
      (media.size.height -
              media.padding.bottom -
              media.viewInsets.bottom -
              _size -
              _edge)
          .clamp(_minTop(media), double.infinity)
          .toDouble();

  void _openLogs() {
    vibrateNow();
    if (Get.currentRoute == AppRoutes.apiLogs) {
      return;
    }
    Get.toNamed<void>(AppRoutes.apiLogs);
  }

  void _hideOverlay() {
    vibrateNow();
    if (!Get.isRegistered<ApiLogStore>()) {
      return;
    }
    Get.find<ApiLogStore>().hideOverlay();
  }
}
