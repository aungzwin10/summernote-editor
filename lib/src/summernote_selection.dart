/// Builds the shared selection-state observer used by both embedded editors.
String buildSummernoteSelectionScript({
  String? viewId,
  required String dispatch,
}) {
  final messageScope = viewId == null
      ? ''
      : '''
            'view': '$viewId',
            'type': 'toDart: updateToolbar',''';

  return '''
        function onSelectionChange() {
          var selection = document.getSelection();
          var focusNode = selection && selection.focusNode;
          var editableRoot = document.querySelector('.note-editable');
          if (!focusNode || !editableRoot || !editableRoot.contains(focusNode)) {
            return;
          }

          var focusElement = \$(focusNode);
          var parentList = focusElement.closest(
            'div.note-editable ol, div.note-editable ul'
          );
          var message = {
            $messageScope
            'style': document.queryCommandValue('formatBlock'),
            'fontName': document.queryCommandValue('fontName'),
            'fontSize': document.queryCommandValue('fontSize') || 16,
            'font': [
              document.queryCommandState('bold'),
              document.queryCommandState('italic'),
              document.queryCommandState('underline')
            ],
            'miscFont': [
              document.queryCommandState('strikeThrough'),
              document.queryCommandState('superscript'),
              document.queryCommandState('subscript')
            ],
            'color': [
              document.queryCommandValue('foreColor') || '000000',
              document.queryCommandValue('hiliteColor') || 'FFFF00'
            ],
            'paragraph': [
              document.queryCommandState('insertUnorderedList'),
              document.queryCommandState('insertOrderedList')
            ],
            'listStyle': parentList.css('list-style-type'),
            'align': [
              document.queryCommandState('justifyLeft'),
              document.queryCommandState('justifyCenter'),
              document.queryCommandState('justifyRight'),
              document.queryCommandState('justifyFull')
            ],
            'lineHeight': \$(focusNode.parentNode).css('line-height'),
            'direction': \$(focusNode.parentNode).css('direction')
          };
          $dispatch
        }

        document.onselectionchange = onSelectionChange;
  ''';
}
