import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

/// Generates a random identifier for editor views and visibility keys.
String getRandString(int len) {
  final random = Random.secure();
  final values = List<int>.generate(len, (_) => random.nextInt(255));
  return base64UrlEncode(values);
}

/// Formatting state at the current editor selection.
class EditorSettings {
  const EditorSettings({
    required this.parentElement,
    required this.fontName,
    required this.fontSize,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.isStrikethrough,
    required this.isSuperscript,
    required this.isSubscript,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.isUl,
    required this.isOl,
    required this.isAlignLeft,
    required this.isAlignCenter,
    required this.isAlignRight,
    required this.isAlignJustify,
    required this.lineHeight,
    required this.textDirection,
  });

  final String parentElement;
  final String fontName;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final bool isSuperscript;
  final bool isSubscript;
  final Color foregroundColor;
  final Color backgroundColor;
  final bool isUl;
  final bool isOl;
  final bool isAlignLeft;
  final bool isAlignCenter;
  final bool isAlignRight;
  final bool isAlignJustify;
  final double lineHeight;
  final TextDirection textDirection;
}

/// Converts the selection-state message emitted by the embedded editor into
/// the public callback model.
EditorSettings editorSettingsFromMap(Map<String, dynamic> json) {
  final font = _boolList(json['font'], 3);
  final miscFont = _boolList(json['miscFont'], 3);
  final colors = _stringList(json['color'], 2);
  final paragraph = _boolList(json['paragraph'], 2);
  final align = _boolList(json['align'], 4);
  final fontSize = _toDouble(json['fontSize'], fallback: 3);
  final lineHeightValue = json['lineHeight']?.toString() ?? '';

  return EditorSettings(
    parentElement: json['style']?.toString() ?? '',
    fontName: (json['fontName']?.toString() ?? '').replaceAll('"', ''),
    fontSize: fontSize,
    isBold: font[0],
    isItalic: font[1],
    isUnderline: font[2],
    isStrikethrough: miscFont[0],
    isSuperscript: miscFont[1],
    isSubscript: miscFont[2],
    foregroundColor: _parseCssColor(colors[0], Colors.black),
    backgroundColor: _parseCssColor(colors[1], Colors.yellow),
    isUl: paragraph[0],
    isOl: paragraph[1],
    isAlignLeft: align[0],
    isAlignCenter: align[1],
    isAlignRight: align[2],
    isAlignJustify: align[3],
    lineHeight: lineHeightValue == 'normal'
        ? 1
        : _toDouble(lineHeightValue.replaceAll('px', ''), fallback: 1),
    textDirection: json['direction'] == 'rtl'
        ? TextDirection.rtl
        : TextDirection.ltr,
  );
}

List<bool> _boolList(dynamic value, int length) {
  final values = value is List ? value : const [];
  return List<bool>.generate(
    length,
    (index) => index < values.length && values[index] == true,
  );
}

List<String> _stringList(dynamic value, int length) {
  final values = value is List ? value : const [];
  return List<String>.generate(
    length,
    (index) => index < values.length ? '${values[index] ?? ''}' : '',
  );
}

double _toDouble(dynamic value, {required double fallback}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

Color _parseCssColor(String value, Color fallback) {
  final color = value.trim().toLowerCase();
  final rgb = RegExp(r'^rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(color);
  if (rgb != null) {
    return Color.fromARGB(
      255,
      int.parse(rgb.group(1)!),
      int.parse(rgb.group(2)!),
      int.parse(rgb.group(3)!),
    );
  }

  final hex = color.replaceFirst('#', '');
  if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)) {
    return Color(int.parse(hex, radix: 16) + 0xff000000);
  }
  return fallback;
}

/// JavaScript that can be invoked in the web editor by name.
class WebScript {
  const WebScript({required this.name, required this.script})
    : assert(name != '' && script != '');

  final String name;
  final String script;
}
