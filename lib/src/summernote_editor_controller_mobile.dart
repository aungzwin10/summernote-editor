import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:summernote_editor/summernote_editor.dart';
import 'package:summernote_editor/src/summernote_editor_controller_unsupported.dart'
    as unsupported;

/// Controller for mobile
class SummernoteEditorController
    extends unsupported.SummernoteEditorController {
  SummernoteEditorController({
    this.processInputHtml = true,
    this.processNewLineAsBr = false,
    this.processOutputHtml = true,
  });

  /// Determines whether text processing should happen on input HTML, e.g.
  /// whether a new line should be converted to a <br>.
  ///
  /// The default value is false.
  @override
  final bool processInputHtml;

  /// Determines whether newlines (\n) should be written as <br>. This is not
  /// recommended for HTML documents.
  ///
  /// The default value is false.
  @override
  final bool processNewLineAsBr;

  /// Determines whether text processing should happen on output HTML, e.g.
  /// whether <p><br></p> is returned as "". For reference, Summernote uses
  /// that HTML as the default HTML (when no text is in the editor).
  ///
  /// The default value is true.
  @override
  final bool processOutputHtml;

  /// Manages the [InAppWebViewController] for the [SummernoteEditorController]
  InAppWebViewController? _editorController;

  /// Allows the [InAppWebViewController] for the Summernote editor to be accessed
  /// outside of the package itself for endless control and customization.
  @override
  // ignore: unnecessary_getters_setters
  InAppWebViewController? get editorController => _editorController;

  /// Internal method to set the [InAppWebViewController] when webview initialization
  /// is complete
  @override
  // ignore: unnecessary_getters_setters
  set editorController(dynamic controller) =>
      _editorController = controller as InAppWebViewController?;

  /// A function to quickly call a document.execCommand function in a readable format
  @override
  void execCommand(String command, {String? argument}) {
    _evaluateJavascript(
      source:
          'document.execCommand(${jsonEncode(command)}, false, '
          '${argument == null ? 'null' : jsonEncode(argument)});',
    );
  }

  /// Gets the text from the editor and returns it as a [String].
  @override
  Future<String> getText() async {
    var text = await _evaluateJavascript(
      source: "\$('#summernote-2').summernote('code');",
    ) as String?;
    if (processOutputHtml &&
        (text == null ||
            text.isEmpty ||
            text == '<p></p>' ||
            text == '<p><br></p>' ||
            text == '<p><br/></p>'))
      text = '';
    return text ?? '';
  }

  /// Sets the text of the editor. Some pre-processing is applied to convert
  /// [String] elements like "\n" to HTML elements.
  @override
  void setText(String text) {
    text = _processHtml(text);
    _evaluateJavascript(
      source: "\$('#summernote-2').summernote('code', ${jsonEncode(text)});",
    );
  }

  /// Sets the editor to full-screen mode.
  @override
  void setFullScreen() {
    _evaluateJavascript(
      source: '\$("#summernote-2").summernote("fullscreen.toggle");',
    );
  }

  /// Sets the focus to the editor.
  @override
  void setFocus() {
    _evaluateJavascript(source: "\$('#summernote-2').summernote('focus');");
  }

  /// Clears the editor of any text.
  @override
  void clear() {
    _evaluateJavascript(source: "\$('#summernote-2').summernote('reset');");
  }

  /// Sets the hint for the editor.
  @override
  void setHint(String text) {
    text = _processHtml(text);
    _evaluateJavascript(
      source: '\$(".note-placeholder").html(${jsonEncode(text)});',
    );
  }

  /// Toggles code view in the Summernote editor.
  @override
  void toggleCodeView() {
    _evaluateJavascript(
      source: "\$('#summernote-2').summernote('codeview.toggle');",
    );
  }

  /// Disables the Summernote editor.
  @override
  void disable() {
    _evaluateJavascript(source: "\$('#summernote-2').summernote('disable');");
  }

  /// Enables the Summernote editor.
  @override
  void enable() {
    _evaluateJavascript(source: "\$('#summernote-2').summernote('enable');");
  }

  /// Undoes the last action
  @override
  void undo() {
    _evaluateJavascript(source: "\$('#summernote-2').summernote('undo');");
  }

  /// Redoes the last action
  @override
  void redo() {
    _evaluateJavascript(source: "\$('#summernote-2').summernote('redo');");
  }

  /// Insert text at the end of the current HTML content in the editor
  /// Note: This method should only be used for plaintext strings
  @override
  void insertText(String text) {
    _evaluateJavascript(
      source:
          "\$('#summernote-2').summernote('insertText', ${jsonEncode(text)});",
    );
  }

  /// Insert HTML at the position of the cursor in the editor
  /// Note: This method should not be used for plaintext strings
  @override
  void insertHtml(String html) {
    html = _processHtml(html);
    _evaluateJavascript(
      source:
          "\$('#summernote-2').summernote('pasteHTML', ${jsonEncode(html)});",
    );
  }

  /// Insert a network image at the position of the cursor in the editor
  @override
  void insertNetworkImage(String url, {String filename = ''}) {
    _evaluateJavascript(
      source:
          "\$('#summernote-2').summernote('insertImage', ${jsonEncode(url)}, "
          '${jsonEncode(filename)});',
    );
  }

  /// Insert a link at the position of the cursor in the editor
  @override
  void insertLink(String text, String url, bool isNewWindow) {
    _evaluateJavascript(
      source:
          """
    \$('#summernote-2').summernote('createLink', {
        text: ${jsonEncode(text)},
        url: ${jsonEncode(url)},
        isNewWindow: $isNewWindow
      });
    """,
    );
  }

  /// Clears the focus from the webview by hiding the keyboard, calling the
  /// clearFocus method on the [InAppWebViewController], and resetting the height
  /// in case it was changed.
  @override
  void clearFocus() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// Throws because reloading is only supported by the web implementation.
  @override
  void reloadWeb() {
    throw Exception(
      'Non-Flutter Web environment detected, please make sure you are importing package:summernote_editor/summernote_editor.dart and check kIsWeb before calling this function',
    );
  }

  /// Resets the height of the editor back to the original if it was changed to
  /// accommodate the keyboard. This should only be used on mobile, and only
  /// when [adjustHeightForKeyboard] is enabled.
  @override
  void resetHeight() {
    _evaluateJavascript(
      source: "window.flutter_inappwebview.callHandler('setHeight', 'reset');",
    );
  }

  /// Recalculates the height of the editor to remove any vertical scrolling.
  /// This method will not do anything if [autoAdjustHeight] is turned off.
  @override
  void recalculateHeight() {
    _evaluateJavascript(
      source: """
          if (window.notifySummernoteEditorHeight) {
            window.notifySummernoteEditorHeight();
          } else {
            var height = document.body.scrollHeight;
            window.flutter_inappwebview.callHandler('setHeight', height);
          }
        """,
    );
  }

  /// Add a notification to the bottom of the editor. This is styled similar to
  /// Bootstrap alerts. You can set the HTML to be displayed in the alert,
  /// and the notificationType determines how the alert is displayed.
  @override
  void addNotification(String html, NotificationType notificationType) {
    final notificationHtml = notificationType == NotificationType.plaintext
        ? html
        : '<div class="alert alert-${notificationType.name}">$html</div>';
    _evaluateJavascript(
      source:
          """
        \$('.note-status-output').html(${jsonEncode(notificationHtml)});
        if (window.notifySummernoteEditorHeight) {
          window.notifySummernoteEditorHeight();
        }
      """,
    );
  }

  /// Remove the current notification from the bottom of the editor
  @override
  void removeNotification() {
    _evaluateJavascript(
      source: """
        \$('.note-status-output').empty();
        if (window.notifySummernoteEditorHeight) {
          window.notifySummernoteEditorHeight();
        }
      """,
    );
  }

  /// Helper function to process input html
  String _processHtml(String html) {
    if (processInputHtml) {
      html = html.replaceAll('\r', '');
    }
    if (processNewLineAsBr) {
      html = html.replaceAll('\n', '<br/>');
    } else {
      html = html.replaceAll('\n', '');
    }
    return html;
  }

  /// Evaluates JavaScript after the mobile WebView has finished loading.
  Future<dynamic> _evaluateJavascript({required String source}) async {
    if (editorController == null || await editorController!.isLoading()) {
      throw StateError(
        'The HTML editor is still loading. Call controller methods after '
        'Callbacks.onInit.',
      );
    }
    return editorController!.evaluateJavascript(source: source);
  }
}
