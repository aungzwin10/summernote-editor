import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:summernote_editor/src/summernote_range_workarounds.dart';
import 'package:summernote_editor/src/summernote_selection.dart';
import 'package:summernote_editor/src/summernote_toolbar.dart';
import 'package:summernote_editor/src/web_message.dart';
import 'package:summernote_editor/summernote_editor.dart';
import 'package:summernote_editor/utils/utils.dart';
import 'package:web/web.dart' as web;

/// The Summernote editor widget for web, backed by an HTMLIFrameElement.
class SummernoteEditorWidget extends StatefulWidget {
  const SummernoteEditorWidget({
    super.key,
    required this.controller,
    this.callbacks,
    required this.plugins,
    required this.summernoteEditorOptions,
    required this.otherOptions,
  });

  final SummernoteEditorController controller;
  final Callbacks? callbacks;
  final List<Plugins> plugins;
  final SummernoteEditorOptions summernoteEditorOptions;
  final OtherOptions otherOptions;

  @override
  _SummernoteEditorWidgetWebState createState() =>
      _SummernoteEditorWidgetWebState();
}

/// State for the web Summernote editor widget.
///
/// A stateful widget is necessary here, otherwise the HTMLIFrameElement will be
/// rebuilt excessively, hurting performance
class _SummernoteEditorWidgetWebState extends State<SummernoteEditorWidget> {
  /// The view ID for the HTMLIFrameElement. Must be unique.
  late String createdViewId;

  /// The actual height of the editor, used to automatically set the height
  late double actualHeight;

  /// A Future that is observed by the [FutureBuilder]. We don't use a function
  /// as the Future on the [FutureBuilder] because when the widget is rebuilt,
  /// the function may be excessively called, hurting performance.
  Future<bool>? summernoteInit;

  StreamSubscription<web.MessageEvent>? _messageSubscription;
  web.HTMLIFrameElement? _iframe;
  bool _initializationStarted = false;
  bool _routeIsCurrent = true;

  @override
  void initState() {
    super.initState();
    actualHeight = widget.otherOptions.height;
    createdViewId = getRandString(10);
    widget.controller.viewId = createdViewId;
    _messageSubscription = web.window.onMessage.listen(_handleMessage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _syncPlatformViewInteraction();
    if (!_initializationStarted) {
      _initializationStarted = true;
      _initializeSummernote();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _iframe = null;
    super.dispose();
  }

  void _syncPlatformViewInteraction() {
    _iframe?.style.pointerEvents = _routeIsCurrent ? 'auto' : 'none';
  }

  Future<void> _initializeSummernote() async {
    var headString = '';
    var summernoteCallbacks =
        '''callbacks: {
        onKeydown: function(e) {
            ${widget.summernoteEditorOptions.characterLimit != null ? '''var allowedKeys = (
                e.which === 8 ||  /* BACKSPACE */
                e.which === 35 || /* END */
                e.which === 36 || /* HOME */
                e.which === 37 || /* LEFT */
                e.which === 38 || /* UP */
                e.which === 39 || /* RIGHT*/
                e.which === 40 || /* DOWN */
                e.which === 46 || /* DEL*/
                e.ctrlKey === true && e.which === 65 || /* CTRL + A */
                e.ctrlKey === true && e.which === 88 || /* CTRL + X */
                e.ctrlKey === true && e.which === 67 || /* CTRL + C */
                e.ctrlKey === true && e.which === 86 || /* CTRL + V */
                e.ctrlKey === true && e.which === 90    /* CTRL + Z */
            );
            if (!allowedKeys && \$(e.target).text().length >= ${widget.summernoteEditorOptions.characterLimit}) {
                e.preventDefault();
            }''' : ''}
        },
    ''';
    for (var p in widget.plugins) {
      headString = headString + p.getHeadString() + '\n';
      if (p is SummernoteAtMention) {
        summernoteCallbacks =
            summernoteCallbacks +
            '''
            \nsummernoteAtMention: {
              getSuggestions: (value) => {
                const mentions = ${jsonEncode(p.mentionsWeb)};
                return mentions.filter((mention) => {
                  return mention.includes(value);
                });
              },
              onSelect: (value) => {
                window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onSelectMention", "value": value}), "*");
              },
            },
          ''';
      }
    }
    if (widget.callbacks != null) {
      if (widget.callbacks!.onImageLinkInsert != null) {
        summernoteCallbacks =
            summernoteCallbacks +
            '''
          onImageLinkInsert: function(url) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onImageLinkInsert", "url": url}), "*");
          },
        ''';
      }
      if (widget.callbacks!.onImageUpload != null) {
        summernoteCallbacks =
            summernoteCallbacks +
            """
          onImageUpload: function(files) {
            var reader = new FileReader();
            var base64 = "<an error occurred>";
            reader.onload = function (_) {
              base64 = reader.result;
              window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onImageUpload", "lastModified": files[0].lastModified, "lastModifiedDate": files[0].lastModifiedDate, "name": files[0].name, "size": files[0].size, "mimeType": files[0].type, "base64": base64}), "*");
            };
            reader.onerror = function (_) {
              window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onImageUploadError", "lastModified": files[0].lastModified, "lastModifiedDate": files[0].lastModifiedDate, "name": files[0].name, "size": files[0].size, "mimeType": files[0].type, "error": "base64 conversion failed"}), "*");
            };
            reader.readAsDataURL(files[0]);
          },
        """;
      }
      if (widget.callbacks!.onImageUploadError != null) {
        summernoteCallbacks =
            summernoteCallbacks +
            """
              onImageUploadError: function(file, error) {
                if (typeof file === 'string') {
                  window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onImageUploadError", "base64": file, "error": error}), "*");
                } else {
                  window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onImageUploadError", "lastModified": file.lastModified, "lastModifiedDate": file.lastModifiedDate, "name": file.name, "size": file.size, "mimeType": file.type, "error": error}), "*");
                }
              },
            """;
      }
    }
    summernoteCallbacks = summernoteCallbacks + '}';
    var jsCallbacks = '';
    if (widget.callbacks != null) {
      jsCallbacks = _getJavaScriptCallbacks(widget.callbacks!);
    }
    var userScripts = '';
    var userScriptResponses = '';
    if (widget.summernoteEditorOptions.webInitialScripts != null) {
      widget.summernoteEditorOptions.webInitialScripts!.forEach((element) {
        final commandType = jsonEncode('toIframe: ${element.name}');
        final responseType = jsonEncode('toDart: ${element.name}');
        userScripts =
            userScripts +
            '''
          if (data["type"] === $commandType) {
            if (data["requestId"] != null) {
              window.summernoteEditorCustomRequestIds =
                window.summernoteEditorCustomRequestIds || {};
              window.summernoteEditorCustomRequestIds[$responseType] =
                window.summernoteEditorCustomRequestIds[$responseType] || [];
              window.summernoteEditorCustomRequestIds[$responseType].push(
                data["requestId"]
              );
            }
            ${element.script}
          }
        ''' +
            '\n';
        userScriptResponses =
            userScriptResponses +
            '''
          if (data["type"] === $responseType &&
              data["requestId"] == null &&
              window.summernoteEditorCustomRequestIds &&
              window.summernoteEditorCustomRequestIds[$responseType] &&
              window.summernoteEditorCustomRequestIds[$responseType].length > 0) {
            data["view"] = "$createdViewId";
            data["requestId"] =
              window.summernoteEditorCustomRequestIds[$responseType].shift();
            window.parent.postMessage(JSON.stringify(data), "*");
            return;
          }
        ''' +
            '\n';
      });
    }
    final fullscreenHeight = MediaQuery.sizeOf(context).height;
    final autoHeightScript = widget.summernoteEditorOptions.autoAdjustHeight
        ? '''
        function getSummernoteEditorHeight() {
          var editor = document.querySelector('.note-editor');
          if (!editor) {
            return Math.ceil(document.body.offsetHeight);
          }

          var currentOverlaySpace = window.summernoteEditorOverlaySpace || 0;
          if (editor.classList.contains('fullscreen')) {
            if (currentOverlaySpace > 0) {
              window.summernoteEditorOverlaySpace = 0;
              editor.style.paddingBottom = '';
            }
            if (!window.summernoteEditorFullscreenHeight) {
              window.summernoteEditorFullscreenHeight = Math.max(
                Math.ceil($fullscreenHeight),
                1
              );
            }
            return window.summernoteEditorFullscreenHeight;
          }

          window.summernoteEditorFullscreenHeight = null;
          var editorRect = editor.getBoundingClientRect();
          var baseBottom = editorRect.bottom - currentOverlaySpace;
          var overlayBottom = baseBottom;
          var hasVisibleOverlay = false;
          var overlaySelector = [
            '.note-dropdown-menu',
            '.note-popover',
            '.note-modal.open .note-modal-content'
          ].join(',');

          document.querySelectorAll(overlaySelector).forEach(function(overlay) {
            var style = window.getComputedStyle(overlay);
            var rect = overlay.getBoundingClientRect();
            if (style.display !== 'none' &&
                style.visibility !== 'hidden' &&
                rect.width > 0 && rect.height > 0) {
              hasVisibleOverlay = true;
              overlayBottom = Math.max(overlayBottom, rect.bottom);
            }
          });

          var nextOverlaySpace = hasVisibleOverlay
            ? Math.max(Math.ceil(overlayBottom - baseBottom + 8), 0)
            : 0;
          if (nextOverlaySpace !== currentOverlaySpace) {
            window.summernoteEditorOverlaySpace = nextOverlaySpace;
            editor.style.paddingBottom = nextOverlaySpace > 0
              ? nextOverlaySpace + 'px'
              : '';
            editorRect = editor.getBoundingClientRect();
          }

          return Math.ceil(editorRect.height);
        }

        function resizeSummernoteEditorCodeview() {
          var editor = document.querySelector('.note-editor');
          var codable = document.querySelector('.note-codable');
          if (!editor || !codable || !editor.classList.contains('codeview')) {
            return;
          }
          codable.style.setProperty('height', 'auto', 'important');
          codable.style.setProperty('overflow-y', 'hidden', 'important');
          codable.style.setProperty(
            'height',
            Math.max(codable.scrollHeight, 1) + 'px',
            'important'
          );
        }

        window.notifySummernoteEditorHeight = function() {
          if (window.summernoteEditorHeightFrame) {
            return;
          }
          window.summernoteEditorHeightFrame = window.requestAnimationFrame(function() {
            window.summernoteEditorHeightFrame = null;
            resizeSummernoteEditorCodeview();
            var height = getSummernoteEditorHeight();
            if (height > 0 && height !== window.summernoteEditorLastHeight) {
              window.summernoteEditorLastHeight = height;
              window.parent.postMessage(JSON.stringify({
                "view": "$createdViewId",
                "type": "toDart: htmlHeight",
                "height": height
              }), "*");
            }
          });
        };

        function setupSummernoteEditorAutoHeight() {
          document.documentElement.style.setProperty('overflow-y', 'hidden', 'important');
          document.body.style.setProperty('overflow-y', 'hidden', 'important');

          var editor = document.querySelector('.note-editor');
          var editable = document.querySelector('.note-editable');
          var codable = document.querySelector('.note-codable');
          if (!editor || !editable) {
            return;
          }

          editable.style.setProperty('box-sizing', 'border-box', 'important');
          editable.style.setProperty('height', 'auto');
          editable.style.setProperty('max-height', 'none', 'important');
          editable.style.setProperty('overflow', 'visible', 'important');
          var statusbar = editor.querySelector('.note-statusbar');
          if (statusbar) {
            statusbar.style.setProperty('display', 'none', 'important');
          }
          if (codable) {
            codable.style.setProperty('box-sizing', 'border-box', 'important');
            codable.style.setProperty('max-height', 'none', 'important');
            codable.addEventListener('input', window.notifySummernoteEditorHeight);
          }

          if (window.ResizeObserver) {
            var resizeObserver = new ResizeObserver(window.notifySummernoteEditorHeight);
            resizeObserver.observe(editor);
            resizeObserver.observe(editable);
          }
          if (window.MutationObserver) {
            var mutationObserver = new MutationObserver(window.notifySummernoteEditorHeight);
            mutationObserver.observe(editor, {
              attributes: true,
              attributeFilter: ['class'],
              childList: true,
              characterData: true,
              subtree: true
            });

            var overlayObserver = new MutationObserver(window.notifySummernoteEditorHeight);
            document.querySelectorAll(
              '.note-btn-group, .note-dropdown-menu, .note-popover, .note-modal'
            ).forEach(function(overlay) {
              overlayObserver.observe(overlay, {
                attributes: true,
                attributeFilter: ['class', 'style', 'aria-hidden']
              });
            });
          }

          window.addEventListener('load', window.notifySummernoteEditorHeight);
          window.addEventListener('resize', window.notifySummernoteEditorHeight);
          window.addEventListener('wheel', function(event) {
            var deltaY = event.deltaY;
            if (event.deltaMode === 1) {
              deltaY *= 16;
            } else if (event.deltaMode === 2) {
              deltaY *= window.innerHeight;
            }
            event.preventDefault();
            window.parent.postMessage(JSON.stringify({
              "view": "$createdViewId",
              "type": "toDart: parentScroll",
              "deltaY": deltaY
            }), "*");
          }, {passive: false});
          window.notifySummernoteEditorHeight();
        }
        '''
        : '';
    final autoHeightSetup = widget.summernoteEditorOptions.autoAdjustHeight
        ? 'setupSummernoteEditorAutoHeight();'
        : '';
    final selectionScript = widget.callbacks?.onChangeSelection == null
        ? ''
        : buildSummernoteSelectionScript(
            viewId: createdViewId,
            dispatch:
                'window.parent.postMessage(JSON.stringify(message), "*");',
          );
    var summernoteScripts =
        """
      <script type="text/javascript">
        \$(document).ready(function () {
          \$('#summernote-2').summernote({
            placeholder: ${jsonEncode(widget.summernoteEditorOptions.hint ?? '')},
            tabsize: 2,
            disableGrammar: false,
            spellCheck: ${widget.summernoteEditorOptions.spellCheck},
            maximumFileSize: $summernoteMaximumFileSize,
            $defaultSummernoteToolbar
            ${widget.summernoteEditorOptions.customOptions}
            disableResizeEditor: true,
            $summernoteCallbacks
          });

          $summernoteRangeWorkarounds
          installSummernoteRangeWorkarounds();

          window.setSummernoteEditorTotalHeight = function(totalHeight) {
            window.requestAnimationFrame(function() {
              var editor = document.querySelector('.note-editor');
              var editable = document.querySelector('.note-editable');
              if (!editor || !editable) {
                return;
              }
              var chromeHeight = editor.getBoundingClientRect().height -
                editable.getBoundingClientRect().height;
              \$(editable).outerHeight(Math.max(totalHeight - chromeHeight, 1));
            });
          };

          ${widget.summernoteEditorOptions.autoAdjustHeight ? '' : '''
          window.setSummernoteEditorTotalHeight(${widget.otherOptions.height});
          window.addEventListener('resize', function() {
            window.setSummernoteEditorTotalHeight(${widget.otherOptions.height});
          });
          '''}

          \$('#summernote-2').on('summernote.change', function(_, contents, \$editable) {
            window.parent.postMessage(JSON.stringify({
              "view": "$createdViewId",
              "type": "toDart: onChangeContent",
              "contents": contents,
              "totalChars": \$editable.text().length
            }), "*");
          });

          ${widget.summernoteEditorOptions.shouldEnsureVisible ? '''
          \$('#summernote-2').on('summernote.focus', function() {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: ensureVisible"}), "*");
          });
          ''' : ''}

          $autoHeightSetup
        });

        $autoHeightScript
        $selectionScript

        function handleMessage(e) {
          if (!e || typeof e.data !== 'string') {
            return;
          }

          var data;
          try {
            data = JSON.parse(e.data);
          } catch (_) {
            return;
          }

          $userScriptResponses

          if (data["view"] !== "$createdViewId" ||
              typeof data["type"] !== 'string' ||
              !data["type"].startsWith('toIframe: ')) {
            return;
          }

          switch (data["type"]) {
            case 'toIframe: getText':
                var str = \$('#summernote-2').summernote('code');
              window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: getText", "requestId": data["requestId"], "text": str}), "*");
              break;
            case 'toIframe: getHeight':
                if (window.notifySummernoteEditorHeight) {
                  window.notifySummernoteEditorHeight();
                } else {
                  var height = document.body.scrollHeight;
                  window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: htmlHeight", "height": height}), "*");
                }
              break;
            case 'toIframe: setInputType':
              var editable = document.querySelector('.note-editable');
              if (editable) {
                editable.setAttribute('inputmode', '${widget.summernoteEditorOptions.inputType.name}');
              }
              break;
            case 'toIframe: setText':
              \$('#summernote-2').summernote('code', data["text"]);
              break;
            case 'toIframe: setFullScreen':
              \$("#summernote-2").summernote("fullscreen.toggle");
              break;
            case 'toIframe: setFocus':
              \$('#summernote-2').summernote('focus');
              break;
            case 'toIframe: clear':
              \$('#summernote-2').summernote('reset');
              break;
            case 'toIframe: setHint':
              \$(".note-placeholder").html(data["text"]);
              break;
            case 'toIframe: toggleCodeview':
              \$('#summernote-2').summernote('codeview.toggle');
              break;
            case 'toIframe: disable':
              \$('#summernote-2').summernote('disable');
              break;
            case 'toIframe: enable':
              \$('#summernote-2').summernote('enable');
              break;
            case 'toIframe: undo':
              \$('#summernote-2').summernote('undo');
              break;
            case 'toIframe: redo':
              \$('#summernote-2').summernote('redo');
              break;
            case 'toIframe: insertText':
              \$('#summernote-2').summernote('insertText', data["text"]);
              break;
            case 'toIframe: insertHtml':
              \$('#summernote-2').summernote('pasteHTML', data["html"]);
              break;
            case 'toIframe: insertNetworkImage':
              \$('#summernote-2').summernote('insertImage', data["url"], data["filename"]);
              break;
            case 'toIframe: insertLink':
              \$('#summernote-2').summernote('createLink', {
                text: data["text"],
                url: data["url"],
                isNewWindow: data["isNewWindow"]
              });
              break;
            case 'toIframe: reload':
              window.location.reload();
              break;
            case 'toIframe: addNotification':
                if (data["alertType"] == null) {
                  \$('.note-status-output').html(
                    data["html"]
                  );
                } else {
                  \$('.note-status-output').html(
                    '<div class="' + data["alertType"] + '">' +
                      data["html"] +
                    '</div>'
                  );
                }
              break;
            case 'toIframe: removeNotification':
              \$('.note-status-output').empty();
              break;
            case 'toIframe: execCommand':
              document.execCommand(data["command"], false, data["argument"]);
              break;
            case 'toIframe: getSelectedTextHtml':
              var selection = window.getSelection();
              var htmlContent = '';
              if (selection && selection.rangeCount > 0) {
                var range = selection.getRangeAt(0);
                var content = range.cloneContents();
                var span = document.createElement('span');
                span.appendChild(content);
                htmlContent = span.innerHTML;
              }
              window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: getSelectedText", "requestId": data["requestId"], "text": htmlContent}), "*");
              break;
            case 'toIframe: getSelectedText':
              var currentSelection = window.getSelection();
              window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: getSelectedText", "requestId": data["requestId"], "text": currentSelection ? currentSelection.toString() : ''}), "*");
              break;
            default:
              $userScripts
              break;
          }
        }

        window.parent.addEventListener('message', handleMessage, false);
        window.addEventListener('unload', function() {
          window.parent.removeEventListener('message', handleMessage, false);
        });

        $jsCallbacks
      </script>
    """;
    var filePath =
        'packages/summernote_editor/assets/summernote-no-plugins.html';
    if (widget.summernoteEditorOptions.filePath != null) {
      filePath = widget.summernoteEditorOptions.filePath!;
    }
    var htmlString = await rootBundle.loadString(filePath);
    if (!mounted) return;
    htmlString = htmlString
        .replaceFirst('<!--headString-->', headString)
        .replaceFirst('<!--summernoteScripts-->', summernoteScripts)
        .replaceFirst(
          '"jquery.min.js"',
          '"assets/packages/summernote_editor/assets/jquery.min.js"',
        )
        .replaceFirst(
          '"summernote-lite.min.css"',
          '"assets/packages/summernote_editor/assets/summernote-lite.min.css"',
        )
        .replaceFirst(
          '"summernote-lite.min.js"',
          '"assets/packages/summernote_editor/assets/summernote-lite.min.js"',
        );
    final iframe = web.HTMLIFrameElement()
      ..width = MediaQuery.sizeOf(context).width.toString()
      ..height = widget.summernoteEditorOptions.autoAdjustHeight
          ? actualHeight.toString()
          : widget.otherOptions.height.toString()
      // ignore: unsafe_html, necessary to load HTML string
      ..srcdoc = htmlString.toJS
      ..style.border = 'none'
      ..style.overflow = 'hidden'
      ..style.width = '100%'
      ..style.height = '100%'
      ..onLoad.listen((event) {
        _postMessage({'type': 'toIframe: setInputType'});
        if (widget.summernoteEditorOptions.initialText != null) {
          widget.controller.setText(
            widget.summernoteEditorOptions.initialText!,
          );
        }
        if (widget.summernoteEditorOptions.disabled) {
          widget.controller.disable();
        }
        _postMessage({'type': 'toIframe: getHeight'});
        widget.callbacks?.onInit?.call();
      });
    _iframe = iframe;
    _syncPlatformViewInteraction();
    ui_web.platformViewRegistry.registerViewFactory(
      createdViewId,
      (int viewId) => iframe,
    );
    if (mounted) {
      setState(() {
        summernoteInit = Future.value(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_routeIsCurrent,
      child: SizedBox(
        height: widget.summernoteEditorOptions.autoAdjustHeight
            ? actualHeight
            : widget.otherOptions.height,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FutureBuilder<bool>(
            future: summernoteInit,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return HtmlElementView(viewType: createdViewId);
              }
              return SizedBox(
                height: widget.summernoteEditorOptions.autoAdjustHeight
                    ? actualHeight
                    : widget.otherOptions.height,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Adds the callbacks the user set into JavaScript
  String _getJavaScriptCallbacks(Callbacks c) {
    var callbacks = '';
    if (c.onBeforeCommand != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.before.command', function(_, contents, \$editable) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onBeforeCommand", "contents": contents}), "*");
          });\n
        """;
    }
    if (c.onChangeCodeview != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.change.codeview', function(_, contents, \$editable) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onChangeCodeview", "contents": contents}), "*");
          });\n
        """;
    }
    if (c.onDialogShown != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.dialog.shown', function() {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onDialogShown"}), "*");
          });\n
        """;
    }
    if (c.onEnter != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.enter', function() {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onEnter"}), "*");
          });\n
        """;
    }
    if (c.onFocus != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.focus', function() {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onFocus"}), "*");
          });\n
        """;
    }
    if (c.onBlur != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.blur', function() {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onBlur"}), "*");
          });\n
        """;
    }
    if (c.onBlurCodeview != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.blur.codeview', function() {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onBlurCodeview"}), "*");
          });\n
        """;
    }
    if (c.onKeyDown != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.keydown', function(_, e) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onKeyDown", "keyCode": e.keyCode}), "*");
          });\n
        """;
    }
    if (c.onKeyUp != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.keyup', function(_, e) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onKeyUp", "keyCode": e.keyCode}), "*");
          });\n
        """;
    }
    if (c.onMouseDown != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.mousedown', function(_) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onMouseDown"}), "*");
          });\n
        """;
    }
    if (c.onMouseUp != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.mouseup', function(_) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onMouseUp"}), "*");
          });\n
        """;
    }
    if (c.onPaste != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.paste', function(_) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onPaste"}), "*");
          });\n
        """;
    }
    if (c.onScroll != null) {
      callbacks =
          callbacks +
          """
          \$('#summernote-2').on('summernote.scroll', function(_) {
            window.parent.postMessage(JSON.stringify({"view": "$createdViewId", "type": "toDart: onScroll"}), "*");
          });\n
        """;
    }
    return callbacks;
  }

  void _handleMessage(web.MessageEvent event) {
    final data = decodeWebMessage(event);
    if (data == null || data['view'] != createdViewId) return;

    switch (data['type']) {
      case 'toDart: htmlHeight':
        if (!widget.summernoteEditorOptions.autoAdjustHeight) return;
        final height = (data['height'] as num?)?.toDouble();
        if (height != null && height > 0 && height != actualHeight && mounted) {
          setState(() => actualHeight = height);
        }
        return;
      case 'toDart: onChangeContent':
        widget.controller.characterCount =
            (data['totalChars'] as num?)?.toInt() ?? 0;
        widget.callbacks?.onChangeContent?.call(data['contents']);
        return;
      case 'toDart: ensureVisible':
        final renderObject = context.findRenderObject();
        if (renderObject != null) {
          Scrollable.maybeOf(context)?.position.ensureVisible(
            renderObject,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeIn,
          );
        }
        return;
      case 'toDart: parentScroll':
        final scrollable = Scrollable.maybeOf(context);
        final deltaY = (data['deltaY'] as num?)?.toDouble();
        if (scrollable != null && deltaY != null && deltaY != 0) {
          scrollable.position.pointerScroll(deltaY);
        }
        return;
      case 'toDart: updateToolbar':
        widget.callbacks?.onChangeSelection?.call(editorSettingsFromMap(data));
        return;
      case 'toDart: onSelectMention':
        for (final plugin in widget.plugins.whereType<SummernoteAtMention>()) {
          plugin.onSelect?.call(data['value']?.toString() ?? '');
        }
        return;
      default:
        _dispatchCallback(data);
    }
  }

  void _dispatchCallback(Map<String, dynamic> data) {
    final callbacks = widget.callbacks;
    if (callbacks == null) return;

    switch (data['type']) {
      case 'toDart: onBeforeCommand':
        callbacks.onBeforeCommand?.call(data['contents']);
        return;
      case 'toDart: onChangeCodeview':
        callbacks.onChangeCodeview?.call(data['contents']);
        return;
      case 'toDart: onDialogShown':
        callbacks.onDialogShown?.call();
        return;
      case 'toDart: onEnter':
        callbacks.onEnter?.call();
        return;
      case 'toDart: onFocus':
        callbacks.onFocus?.call();
        return;
      case 'toDart: onBlur':
        callbacks.onBlur?.call();
        return;
      case 'toDart: onBlurCodeview':
        callbacks.onBlurCodeview?.call();
        return;
      case 'toDart: onImageLinkInsert':
        callbacks.onImageLinkInsert?.call(data['url']);
        return;
      case 'toDart: onImageUpload':
        callbacks.onImageUpload?.call(_fileUploadFromMessage(data));
        return;
      case 'toDart: onImageUploadError':
        callbacks.onImageUploadError?.call(
          data['base64'] == null ? _fileUploadFromMessage(data) : null,
          data['base64']?.toString(),
          _uploadError(data['error']),
        );
        return;
      case 'toDart: onKeyDown':
        callbacks.onKeyDown?.call((data['keyCode'] as num?)?.toInt());
        return;
      case 'toDart: onKeyUp':
        callbacks.onKeyUp?.call((data['keyCode'] as num?)?.toInt());
        return;
      case 'toDart: onMouseDown':
        callbacks.onMouseDown?.call();
        return;
      case 'toDart: onMouseUp':
        callbacks.onMouseUp?.call();
        return;
      case 'toDart: onPaste':
        callbacks.onPaste?.call();
        return;
      case 'toDart: onScroll':
        callbacks.onScroll?.call();
        return;
    }
  }

  FileUpload _fileUploadFromMessage(Map<String, dynamic> data) =>
      FileUpload.fromJson({
        'lastModified': data['lastModified'],
        'lastModifiedDate': data['lastModifiedDate'],
        'name': data['name'],
        'size': data['size'],
        'type': data['mimeType'],
        'base64': data['base64'],
      });

  UploadError _uploadError(dynamic error) {
    final message = error?.toString() ?? '';
    if (message.contains('base64')) return UploadError.jsException;
    if (message.contains('unsupported')) return UploadError.unsupportedFile;
    return UploadError.exceededMaxSize;
  }

  void _postMessage(Map<String, Object?> data) {
    data['view'] = createdViewId;
    web.window.postMessage(jsonEncode(data).toJS, '*'.toJS);
  }
}
