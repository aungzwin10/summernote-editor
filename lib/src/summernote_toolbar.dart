/// Default Summernote toolbar used by the web iframe and mobile WebView.
///
/// Keep this as a complete JavaScript object property, including its trailing
/// comma, so callers can override it later through `customOptions`.
const defaultSummernoteToolbar = '''
  toolbar: [
    ['style', ['style']],
    ['font', [
      'fontname',
      'fontsize',
      'fontsizeunit',
      'bold',
      'italic',
      'underline',
      'strikethrough',
      'superscript',
      'subscript',
      'clear'
    ]],
    ['color', ['color']],
    ['para', ['ul', 'ol', 'paragraph', 'height']],
    ['insert', ['link', 'picture', 'hr']],
    ['history', ['undo', 'redo']]
  ],
''';

/// Maximum image size accepted by Summernote's built-in image picker.
const summernoteMaximumFileSize = 10485760;
