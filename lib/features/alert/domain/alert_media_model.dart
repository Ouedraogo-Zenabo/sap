//import 'package:file_picker/file_picker.dart';
import 'dart:io';        // pour File (mobile)
import 'dart:typed_data'; // pour Uint8List (web)

enum MediaType { image, video }

class AlertMedia {
  final MediaType type;
  final File? file;          // mobile
  final Uint8List? bytes;    // web
  final String name;
  final String id;
  final String url;
  final String typeme;

  AlertMedia({
    required this.type,
    this.file,
    this.bytes,
    required this.name,
    required this.id,
    required this.url,
    required this.typeme,
  });
}

