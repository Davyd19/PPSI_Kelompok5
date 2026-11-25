import 'package:flutter/material.dart';

/// Shared dimensions for all active mobile modules; colors live in theme.dart.
abstract final class SchoolDesign {
  static const String fontFamily = 'Roboto';
  static const double pageInset = 16;
  static const double gap = 12;
  static const double cardRadius = 16;
  static const double controlRadius = 12;
  static const double dialogRadius = 20;
  static const double touchTarget = 48;
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(cardRadius),
  );
}
