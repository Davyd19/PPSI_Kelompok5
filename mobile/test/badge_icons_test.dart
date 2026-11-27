import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/badge_icons.dart';

void main() {
  test('badge icon catalog matches web and safely supports legacy values', () {
    final source = File(
      '../frontend_web/src/utils/badge-icons.js',
    ).readAsStringSync();
    final codes =
        jsonDecode(
              source.substring(
                source.indexOf('['),
                source.lastIndexOf(']') + 1,
              ),
            )
            as List;
    expect(badgeIcons.keys.toSet(), codes.toSet());
    expect(badgeIcons.length, 24);
    expect(badgeIcon('trophy'), Icons.emoji_events_outlined);
    expect(badgeIcon('legacy-icon'), badgeIcon(null));
  });
}
