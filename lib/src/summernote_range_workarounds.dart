/// Installs narrow workarounds for stale DOM ranges in Summernote 0.9.0/0.9.1.
///
/// Summernote can retain a range whose text node has been split by the browser.
/// Reading that range while auto-linking, or reselecting it after a font change,
/// throws an IndexSizeError in Chromium. Keep the workaround outside the
/// vendored distribution so the upstream assets remain byte-for-byte intact.
const summernoteRangeWorkarounds = r'''
function installSummernoteRangeWorkarounds() {
  if (!window.jQuery || !$.summernote ||
      ($.summernote.version !== '0.9.0' &&
       $.summernote.version !== '0.9.1')) {
    return;
  }

  var context = $('#summernote-2').data('summernote');
  if (!context || !context.modules) {
    return;
  }

  function isStaleRangeError(error) {
    return error && error.name === 'IndexSizeError';
  }

  var editor = context.modules.editor;
  if (editor && editor.fontStyling &&
      !editor.fontStyling.summernoteEditorRangeWorkaround) {
    var originalFontStyling = editor.fontStyling;
    var patchedFontStyling = function() {
      try {
        return originalFontStyling.apply(this, arguments);
      } catch (error) {
        if (!isStaleRangeError(error)) {
          throw error;
        }

        // The style has already been applied. Capture the browser's updated
        // selection so Summernote does not keep the now-invalid saved range.
        this.setLastRange();
      }
    };
    patchedFontStyling.summernoteEditorRangeWorkaround = true;
    editor.fontStyling = patchedFontStyling;
  }

  function protectWordRange(module, rangeProperty) {
    if (!module || !module.replace ||
        module.replace.summernoteEditorRangeWorkaround) {
      return;
    }

    var originalReplace = module.replace;
    var patchedReplace = function() {
      try {
        return originalReplace.apply(this, arguments);
      } catch (error) {
        if (!isStaleRangeError(error)) {
          throw error;
        }

        // The candidate is stale and cannot safely be linked or replaced.
        // Discard only this candidate; the next key event creates a new range.
        this[rangeProperty] = null;
      }
    };
    patchedReplace.summernoteEditorRangeWorkaround = true;
    module.replace = patchedReplace;
  }

  protectWordRange(context.modules.autoLink, 'lastWordRange');
  protectWordRange(context.modules.autoReplace, 'lastWord');
}
''';
