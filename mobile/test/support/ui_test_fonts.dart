import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadUiTestFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages =
      (jsonDecode(await config.readAsString())
              as Map<String, dynamic>)['packages']
          as List;
  final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
    (p) => p['name'] == 'flutter',
  );
  final root = Directory.fromUri(
    config.uri.resolve(flutter['rootUri'] as String),
  ).uri;
  final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
  for (final entry in {
    'Roboto': ['roboto-regular.ttf', 'roboto-bold.ttf'],
    'MaterialIcons': ['materialicons-regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      final file = File.fromUri(fonts.resolve(name));
      loader.addFont(
        Future.value(ByteData.sublistView(await file.readAsBytes())),
      );
    }
    await loader.load();
  }
}
