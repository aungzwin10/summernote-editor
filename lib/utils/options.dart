import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:summernote_editor/summernote_editor.dart';

/// Options that modify the editor and its behavior.
class SummernoteEditorOptions {
  const SummernoteEditorOptions({
    this.autoAdjustHeight = true,
    this.androidUseHybridComposition = true,
    this.adjustHeightForKeyboard = true,
    this.characterLimit,
    this.customOptions = '',
    this.disabled = false,
    this.filePath,
    this.hint,
    this.initialText,
    this.inputType = SummernoteInputType.text,
    this.mobileContextMenu,
    this.mobileLongPressDuration,
    this.mobileInitialScripts,
    this.webInitialScripts,
    this.shouldEnsureVisible = false,
    this.spellCheck = false,
  });

  /// A fixed-height editor will automatically adjust its height when the
  /// keyboard is active to prevent the keyboard overlapping the editor.
  /// Content-height editors already let the surrounding Flutter scrollable
  /// reveal the focused editor, so this option is only applied when
  /// [autoAdjustHeight] is false.
  final bool adjustHeightForKeyboard;

  /// Whether Android should use hybrid composition for the editor WebView.
  final bool androidUseHybridComposition;

  /// Continuously tracks the rendered Summernote editor height, removes inner
  /// vertical scrolling, and lets the surrounding Flutter scrollable own
  /// vertical gestures.
  final bool autoAdjustHeight;

  /// Maximum number of text characters accepted by the editor.
  final int? characterLimit;

  /// Additional Summernote initialization properties.
  ///
  /// The value is inserted directly into Summernote's JavaScript options
  /// object and must end with a comma when it is non-empty. It can be used to
  /// replace the package's default built-in Summernote toolbar.
  final String customOptions;

  /// Whether the editor starts disabled.
  final bool disabled;

  /// Optional custom HTML template containing an element with ID
  /// `summernote-2` and the documented insertion comments.
  final String? filePath;

  /// Placeholder shown while the editor is empty.
  final String? hint;

  /// Initial editor HTML.
  final String? initialText;

  /// Virtual keyboard type used by the editable element.
  final SummernoteInputType inputType;

  /// Context menu used for selected text on mobile.
  final ContextMenu? mobileContextMenu;

  /// Duration before a mobile long press is recognized.
  final Duration? mobileLongPressDuration;

  /// Scripts injected when the mobile WebView is created.
  final UnmodifiableListView<UserScript>? mobileInitialScripts;

  /// Named scripts that can be invoked in the web editor.
  final UnmodifiableListView<WebScript>? webInitialScripts;

  /// Whether focusing the editor should reveal it in the nearest Flutter
  /// scrollable.
  final bool shouldEnsureVisible;

  /// Whether browser spellchecking is enabled in the editable area.
  final bool spellCheck;
}

/// Layout options for the editor widget.
class OtherOptions {
  const OtherOptions({
    this.decoration = const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      border: Border.fromBorderSide(
        BorderSide(color: Color(0xffececec), width: 1),
      ),
    ),
    this.height = 400,
  });

  /// Decoration surrounding the complete Summernote editor.
  final BoxDecoration decoration;

  /// Total editor height when [SummernoteEditorOptions.autoAdjustHeight] is false.
  /// With auto height enabled this is the loading height until the rendered
  /// Summernote toolbar and content have been measured.
  final double height;
}
