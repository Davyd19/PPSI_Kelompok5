import 'package:flutter/material.dart';

/// Stable catalog codes shared with the web Admin and validated by the API.
const badgeIcons = <String, IconData>{
  'medal': Icons.workspace_premium_outlined,
  'trophy': Icons.emoji_events_outlined,
  'star': Icons.star_outline,
  'school': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'calendar': Icons.calendar_month_outlined,
  'check': Icons.check_circle_outline,
  'clock': Icons.schedule_outlined,
  'shield': Icons.shield_outlined,
  'target': Icons.track_changes,
  'flame': Icons.local_fire_department_outlined,
  'bolt': Icons.bolt_outlined,
  'heart': Icons.favorite_border,
  'leaf': Icons.eco_outlined,
  'flag': Icons.flag_outlined,
  'users': Icons.groups_outlined,
  'music': Icons.music_note_outlined,
  'palette': Icons.palette_outlined,
  'sports': Icons.sports_soccer_outlined,
  'science': Icons.science_outlined,
  'globe': Icons.public,
  'rocket': Icons.rocket_launch_outlined,
  'sun': Icons.wb_sunny_outlined,
  'mountain': Icons.landscape_outlined,
};
IconData badgeIcon(Object? code) =>
    badgeIcons[code?.toString()] ?? badgeIcons['medal']!;
