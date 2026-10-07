import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:summernote_editor/summernote_editor.dart';
import 'package:summernote_editor/src/summernote_editor_controller_unsupported.dart'
    as unsupported;
import 'package:summernote_editor/src/web_message.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

/// Controller for web
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
  /// The default value is true.
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

  /// Manages the view ID for the [SummernoteEditorController] on web
  String? _viewId;
  int _requestSequence = 0;

  /// Internal method to set the view ID when iframe initialization
  /// is complete
  @override
  @internal
  set viewId(String? viewId) => _viewId = viewId;

  /// Gets the text from the editor and returns it as a [String].
  @override
  Future<String> getText() async {
    final response = await _request(
      data: {'type': 'toIframe: getText'},
      responseType: 'toDart: getText',
    );
    String text = response['text']?.toString() ?? '';
    if (processOutputHtml &&
        (text.isEmpty ||
            text == '<p></p>' ||
            text == '<p><br></p>' ||
            text == '<p><br/></p>'))
      text = '';
    return text;
  }

  @override
  Future<String> getSelectedTextWeb({bool withHtmlTags = false}) async {
    final response = await _request(
      data: {
        'type': withHtmlTags
            ? 'toIframe: getSelectedTextHtml'
            : 'toIframe: getSelectedText',
      },
      responseType: 'toDart: getSelectedText',
    );
    return response['text']?.toString() ?? '';
  }

  /// Sets the text of the editor. Some pre-processing is applied to convert
  /// [String] elements like "\n" to HTML elements.
  @override
  void setText(String text) {
    text = _processHtml(text);
    _evaluateJavascriptWeb(data: {'type': 'toIframe: setText', 'text': text});
  }

  /// Sets the editor to full-screen mode.
  @override
  void setFullScreen() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: setFullScreen'});
  }

  /// Sets the focus to the editor.
  @override
  void setFocus() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: setFocus'});
  }

  /// Clears the editor of any text.
  @override
  void clear() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: clear'});
  }

  /// Sets the hint for the editor.
  @override
  void setHint(String text) {
    text = _processHtml(text);
    _evaluateJavascriptWeb(data: {'type': 'toIframe: setHint', 'text': text});
  }

  /// Toggles code view in the Summernote editor.
  @override
  void toggleCodeView() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: toggleCodeview'});
  }

  /// Disables the Summernote editor.
  @override
  void disable() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: disable'});
  }

  /// Enables the Summernote editor.
  @override
  void enable() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: enable'});
  }

  /// Undoes the last action
  @override
  void undo() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: undo'});
  }

  /// Redoes the last action
  @override
  void redo() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: redo'});
  }

  /// Insert text at the end of the current HTML content in the editor
  /// Note: This method should only be used for plaintext strings
  @override
  void insertText(String text) {
    _evaluateJavascriptWeb(
      data: {'type': 'toIframe: insertText', 'text': text},
    );
  }

  /// Insert HTML at the position of the cursor in the editor
  /// Note: This method should not be used for plaintext strings
  @override
  void insertHtml(String html) {
    html = _processHtml(html);
    _evaluateJavascriptWeb(
      data: {'type': 'toIframe: insertHtml', 'html': html},
    );
  }

  /// Insert a network image at the position of the cursor in the editor
  @override
  void insertNetworkImage(String url, {String filename = ''}) {
    _evaluateJavascriptWeb(
      data: {
        'type': 'toIframe: insertNetworkImage',
        'url': url,
        'filename': filename,
      },
    );
  }

  /// Insert a link at the position of the cursor in the editor
  @override
  void insertLink(String text, String url, bool isNewWindow) {
    _evaluateJavascriptWeb(
      data: {
        'type': 'toIframe: insertLink',
        'text': text,
        'url': url,
        'isNewWindow': isNewWindow,
      },
    );
  }

  /// Clears the focus from the webview by hiding the keyboard, calling the
  /// clearFocus method on the [InAppWebViewController], and resetting the height
  /// in case it was changed.
  @override
  void clearFocus() {
    throw Exception(
      'Flutter Web environment detected, please make sure you are importing package:summernote_editor/summernote_editor.dart and check kIsWeb before calling this method.',
    );
  }

  /// Resets the height of the editor back to the original if it was changed to
  /// accommodate the keyboard. This should only be used on mobile, and only
  /// when [adjustHeightForKeyboard] is enabled.
  @override
  void resetHeight() {
    throw Exception(
      'Flutter Web environment detected, please make sure you are importing package:summernote_editor/summernote_editor.dart and check kIsWeb before calling this method.',
    );
  }

  /// Refresh the page
  ///
  /// Note: This should only be used in Flutter Web!!!
  @override
  void reloadWeb() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: reload'});
  }

  /// Recalculates the height of the editor to remove any vertical scrolling.
  /// This method will not do anything if [autoAdjustHeight] is turned off.
  @override
  void recalculateHeight() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: getHeight'});
  }

  /// A function to quickly call a document.execCommand function in a readable format
  @override
  void execCommand(String command, {String? argument}) {
    _evaluateJavascriptWeb(
      data: {
        'type': 'toIframe: execCommand',
        'command': command,
        'argument': argument,
      },
    );
  }

  /// A function to execute JS passed as a [WebScript] to the editor. This should
  /// only be used on Flutter Web.
  @override
  Future<dynamic> evaluateJavascriptWeb(
    String name, {
    bool hasReturnValue = false,
  }) async {
    final data = <String, Object?>{'type': 'toIframe: $name'};
    if (!hasReturnValue) {
      _evaluateJavascriptWeb(data: data);
      return null;
    }
    return _request(data: data, responseType: 'toDart: $name');
  }

  /// Add a notification to the bottom of the editor. This is styled similar to
  /// Bootstrap alerts. You can set the HTML to be displayed in the alert,
  /// and the notificationType determines how the alert is displayed.
  @override
  void addNotification(String html, NotificationType notificationType) {
    if (notificationType == NotificationType.plaintext) {
      _evaluateJavascriptWeb(
        data: {'type': 'toIframe: addNotification', 'html': html},
      );
    } else {
      _evaluateJavascriptWeb(
        data: {
          'type': 'toIframe: addNotification',
          'html': html,
          'alertType': 'alert alert-${notificationType.name}',
        },
      );
    }
    recalculateHeight();
  }

  /// Remove the current notification from the bottom of the editor
  @override
  void removeNotification() {
    _evaluateJavascriptWeb(data: {'type': 'toIframe: removeNotification'});
    recalculateHeight();
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

  /// Sends a command to this controller's iframe.
  void _evaluateJavascriptWeb({required Map<String, Object?> data}) {
    data['view'] = _requireViewId();
    web.window.postMessage(jsonEncode(data).toJS, '*'.toJS);
  }

  Future<Map<String, dynamic>> _request({
    required Map<String, Object?> data,
    required String responseType,
  }) async {
    final viewId = _requireViewId();
    final requestId = '$viewId-${_requestSequence++}';
    data['requestId'] = requestId;

    final response = web.window.onMessage.firstWhere((event) {
      final message = decodeWebMessage(event);
      return message?['type'] == responseType &&
          message?['view'] == viewId &&
          message?['requestId'] == requestId;
    });
    _evaluateJavascriptWeb(data: data);

    final event = await response.timeout(const Duration(seconds: 10));
    return decodeWebMessage(event)!;
  }

  String _requireViewId() {
    final viewId = _viewId;
    if (viewId == null) {
      throw StateError(
        'The HTML editor is not initialized. Call controller methods after '
        'Callbacks.onInit.',
      );
    }
    return viewId;
  }
}
