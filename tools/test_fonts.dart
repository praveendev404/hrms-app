// Loads the real Roboto + Material icon fonts into flutter_test (which otherwise draws every
// letter as a wide square), so layouts match a device.
import 'dart:io';

import 'package:flutter/services.dart';

const kFontDir = 'D:/flutter/bin/cache/artifacts/material_fonts';

Future<void> loadTestFonts() async {
  Future<ByteData> bytes(String f) async => ByteData.sublistView(await File('$kFontDir/$f').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final f in Directory(kFontDir).listSync().whereType<File>()) {
    final name = f.path.split(RegExp(r'[\\/]')).last.toLowerCase();
    if (name.startsWith('roboto-') && name.endsWith('.ttf')) roboto.addFont(bytes(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}

