import 'package:summernote_editor/summernote_editor.dart';
import 'package:summernote_editor/src/widgets/summernote_editor_widget_web.dart';
import 'package:flutter/material.dart';

/// SummernoteEditor class for web
class SummernoteEditor extends StatelessWidget {
  const SummernoteEditor({
    super.key,
    required this.controller,
    this.callbacks,
    this.summernoteEditorOptions = const SummernoteEditorOptions(),
    this.otherOptions = const OtherOptions(),
    this.plugins = const [],
  });

  /// The controller that is passed to the widget, which allows multiple [SummernoteEditor]
  /// widgets to be used on the same page independently.
  final SummernoteEditorController controller;

  /// Sets & activates Summernote's callbacks. See the functions available in
  /// [Callbacks] for more details.
  final Callbacks? callbacks;

  /// Defines options for the Summernote editor.
  final SummernoteEditorOptions summernoteEditorOptions;

  /// Defines other options
  final OtherOptions otherOptions;

  /// Sets the list of Summernote plugins enabled in the editor.
  final List<Plugins> plugins;

  @override
  Widget build(BuildContext context) => SummernoteEditorWidget(
    key: key,
    controller: controller,
    callbacks: callbacks,
    plugins: plugins,
    summernoteEditorOptions: summernoteEditorOptions,
    otherOptions: otherOptions,
  );
}
