import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Largest file the app will try to upload (the server has its own limit as well).
const kMaxAttachmentBytes = 10 * 1024 * 1024;

/// Lets the user pick one file from the phone. Returns null when cancelled.
/// Throws a readable message when the file is too large.
Future<File?> pickAttachment() async {
  final r = await FilePicker.pickFiles();
  final path = r?.files.single.path;
  if (path == null) return null;
  final file = File(path);
  if (await file.length() > kMaxAttachmentBytes) {
    throw Exception('That file is larger than 10 MB.');
  }
  return file;
}
