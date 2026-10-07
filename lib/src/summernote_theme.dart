/// Forces a complete light editor surface when the surrounding Flutter theme
/// is dark. Summernote's default editable area is otherwise transparent.
const summernoteLightThemeStyle = '''
<style id="html-editor-light-theme">
  html,
  body,
  .note-editor.note-frame,
  .note-editing-area,
  .note-editable,
  .note-codable,
  .note-status-output {
    background-color: #fff !important;
    color: #212121 !important;
  }
</style>
''';
