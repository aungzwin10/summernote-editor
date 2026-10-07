import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Map<String, dynamic>? decodeWebMessage(web.MessageEvent event) {
  final rawData = event.data?.dartify();
  if (rawData is! String) return null;

  try {
    final decoded = jsonDecode(rawData);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
