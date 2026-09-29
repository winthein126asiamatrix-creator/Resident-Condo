import 'package:flutter/material.dart';

/// Shared colour palette used across the resident app.
///
/// The palette mirrors the values already used by the original screens so the
/// new modules stay visually consistent with dashboard, payments and
/// facilities.
abstract final class AppPalette {
  static const brand = Color(0xFF0F766E);
  static const brandDark = Color(0xFF0B5A54);
  static const brandSoft = Color(0xFFD6EEE8);
  static const brandTint = Color(0xFFE6F3EF);
  static const brandOnDark = Color(0xFFBFE8DF);
  static const brandOnDarkMuted = Color(0xFFD8F3EC);

  static const ink = Color(0xFF1D2B2A);
  static const muted = Color(0xFF71807D);
  static const mutedStrong = Color(0xFF52635F);
  static const faint = Color(0xFF9AA9A5);
  static const border = Color(0xFFE6EEEB);
  static const surface = Color(0xFFF7FAF9);
  static const surfaceMuted = Color(0xFFF4F8F7);

  static const success = Color(0xFF087F5B);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFC2410C);
  static const accent = Color(0xFFE07A5F);
  static const accentSoft = Color(0xFFFCE8DF);
  static const info = Color(0xFF5B4CC4);
  static const infoSoft = Color(0xFFEAE8FA);
  static const amberSoft = Color(0xFFFFF1D6);

  static const heroShadow = <BoxShadow>[
    BoxShadow(color: Color(0x1A0F766E), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0A163A36), blurRadius: 16, offset: Offset(0, 5)),
  ];

  static const titleStyle = TextStyle(
    color: ink,
    fontSize: 25,
    fontWeight: FontWeight.w800,
  );

  static const subtitleStyle = TextStyle(color: muted);
}
