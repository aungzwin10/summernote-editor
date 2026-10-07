import 'package:flutter/foundation.dart';

/// Abstract class that all plugin classes extend.
abstract class Plugins {
  const Plugins();

  /// Provides the JS and CSS tags to be inserted inside <head>. Only used for Web
  String getHeadString();
}

/// Summernote @ Mention plugin - adds a dropdown to select the person to mention whenever
/// the '@' character is typed into the editor. The list of people to mention is
/// drawn from the [getSuggestionsMobile] (on mobile) or [mentionsWeb] (on Web)
/// parameter. You can detect who was mentioned using the [onSelect] callback.
///
/// README available [here](https://github.com/team-loxo/summernote-at-mention)
class SummernoteAtMention extends Plugins {
  /// Function used to get the displayed suggestions on mobile
  final List<String> Function(String)? getSuggestionsMobile;

  /// List of mentions to display on Web. The default behavior is to only return
  /// the mentions containing the string entered by the user in the editor
  final List<String>? mentionsWeb;

  /// Callback to run code when a mention is selected
  final void Function(String)? onSelect;

  const SummernoteAtMention({
    this.getSuggestionsMobile,
    this.mentionsWeb,
    this.onSelect,
  }) : assert(kIsWeb ? mentionsWeb != null : getSuggestionsMobile != null);

  @override
  String getHeadString() {
    return '<script src=\"assets/packages/summernote_editor/assets/plugins/summernote-at-mention/summernote-at-mention.js\"></script>';
  }
}
