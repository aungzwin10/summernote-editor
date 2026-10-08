import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:summernote_editor/summernote_editor.dart'
    hide NavigationActionPolicy, UserScript, ContextMenu;
import 'package:summernote_editor/src/summernote_range_workarounds.dart';
import 'package:summernote_editor/src/summernote_selection.dart';
import 'package:summernote_editor/src/summernote_toolbar.dart';
import 'package:summernote_editor/utils/utils.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// The Summernote editor widget for mobile, backed by InAppWebView.
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
  _SummernoteEditorWidgetMobileState createState() =>
      _SummernoteEditorWidgetMobileState();
}

/// State for the mobile Summernote editor widget.
///
/// A stateful widget is necessary here to allow the height to dynamically adjust.
class _SummernoteEditorWidgetMobileState extends State<SummernoteEditorWidget> {
  /// The height of the document loaded in the editor
  late double docHeight;

  /// The file path to the html code
  late String filePath;

  /// String to use when creating the key for the widget
  late String _visibilityKey;

  /// Stream to transfer the [VisibilityInfo.visibleFraction] to the [onWindowFocus]
  /// function of the webview
  final StreamController<double> visibleStream =
      StreamController<double>.broadcast();

  StreamSubscription<bool>? _keyboardVisibilitySubscription;

  /// Variable to cache the viewable size of the editor to update it in case
  /// the editor is focused much after its visibility changes
  double? cachedVisibleDecimal;

  @override
  void initState() {
    super.initState();
    docHeight = widget.otherOptions.height;
    _visibilityKey = getRandString(10);
    if (widget.summernoteEditorOptions.filePath != null) {
      filePath = widget.summernoteEditorOptions.filePath!;
    } else if (widget.plugins.isEmpty) {
      filePath = 'packages/summernote_editor/assets/summernote-no-plugins.html';
    } else {
      filePath = 'packages/summernote_editor/assets/summernote.html';
    }
  }

  @override
  void dispose() {
    _keyboardVisibilitySubscription?.cancel();
    visibleStream.close();
    super.dispose();
  }

  /// resets the height of the editor to the original height
  Future<void> resetHeight() async {
    final controller = widget.controller.editorController;
    if (controller == null) return;
    if (widget.summernoteEditorOptions.autoAdjustHeight) {
      await controller.evaluateJavascript(
        source: """
        if (window.notifySummernoteEditorHeight) {
          window.notifySummernoteEditorHeight();
        }
      """,
      );
      return;
    }
    if (mounted) {
      setState(() {
        docHeight = widget.otherOptions.height;
      });
      await controller.evaluateJavascript(
        source:
            "if (window.setSummernoteEditorTotalHeight) { window.setSummernoteEditorTotalHeight(${widget.otherOptions.height}); }",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    return SizedBox(
      height: docHeight,
      child: Offstage(
        offstage: !routeIsCurrent,
        child: IgnorePointer(
          ignoring: !routeIsCurrent,
          child: GestureDetector(
            onTap: () {
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
            child: VisibilityDetector(
              key: Key(_visibilityKey),
              onVisibilityChanged: (VisibilityInfo info) {
                if (!visibleStream.isClosed) {
                  cachedVisibleDecimal = info.visibleFraction == 1
                      ? (info.size.height / widget.otherOptions.height).clamp(
                          0,
                          1,
                        )
                      : info.visibleFraction;
                  visibleStream.add(
                    info.visibleFraction == 1
                        ? (info.size.height / widget.otherOptions.height).clamp(
                            0,
                            1,
                          )
                        : info.visibleFraction,
                  );
                }
              },
              child: Container(
                height: docHeight,
                decoration: widget.otherOptions.decoration,
                child: InAppWebView(
                  initialFile: filePath,
                  onWebViewCreated: (InAppWebViewController controller) {
                    widget.controller.editorController = controller;
                    _registerJavaScriptHandlers(controller);
                    if (widget
                            .summernoteEditorOptions
                            .adjustHeightForKeyboard &&
                        !widget.summernoteEditorOptions.autoAdjustHeight) {
                      _keyboardVisibilitySubscription =
                          KeyboardVisibilityController().onChange.listen((
                            visible,
                          ) {
                            if (!visible && mounted) {
                              controller.clearFocus();
                              resetHeight();
                            }
                          });
                    }
                  },
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    transparentBackground: true,
                    useShouldOverrideUrlLoading: true,
                    useHybridComposition: widget
                        .summernoteEditorOptions
                        .androidUseHybridComposition,
                    loadWithOverviewMode: true,
                    disableVerticalScroll:
                        widget.summernoteEditorOptions.autoAdjustHeight,
                    verticalScrollBarEnabled:
                        !widget.summernoteEditorOptions.autoAdjustHeight,
                  ),
                  initialUserScripts:
                      widget.summernoteEditorOptions.mobileInitialScripts
                          as UnmodifiableListView<UserScript>?,
                  contextMenu:
                      widget.summernoteEditorOptions.mobileContextMenu
                          as ContextMenu?,
                  gestureRecognizers: {
                    if (!widget.summernoteEditorOptions.autoAdjustHeight)
                      Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer(),
                      ),
                    Factory<LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(
                        duration: widget
                            .summernoteEditorOptions
                            .mobileLongPressDuration,
                      ),
                    ),
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    if (!action.request.url.toString().contains(filePath)) {
                      return (await widget.callbacks?.onNavigationRequestMobile
                                  ?.call(action.request.url.toString()))
                              as NavigationActionPolicy? ??
                          NavigationActionPolicy.ALLOW;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onWindowFocus: (controller) async {
                    if (widget.summernoteEditorOptions.shouldEnsureVisible) {
                      final renderObject = context.findRenderObject();
                      if (renderObject != null) {
                        await Scrollable.maybeOf(context)?.position
                            .ensureVisible(renderObject);
                      }
                    }
                    if (widget
                            .summernoteEditorOptions
                            .adjustHeightForKeyboard &&
                        !widget.summernoteEditorOptions.autoAdjustHeight &&
                        mounted &&
                        !visibleStream.isClosed) {
                      Future<void> setHeightJS() async {
                        await controller.evaluateJavascript(
                          source:
                              """
                                if (window.setSummernoteEditorTotalHeight) {
                                  window.setSummernoteEditorTotalHeight(${max(docHeight, 30)});
                                }
                                // from https://stackoverflow.com/a/67152280
                                var selection = window.getSelection();
                                if (selection.rangeCount) {
                                  var firstRange = selection.getRangeAt(0);
                                  if (firstRange.commonAncestorContainer !== document) {
                                    var tempAnchorEl = document.createElement('br');
                                    firstRange.insertNode(tempAnchorEl);
                                    tempAnchorEl.scrollIntoView({
                                      block: 'end',
                                    });
                                    tempAnchorEl.remove();
                                  }
                                }
                              """,
                        );
                      }

                      /// this is a workaround so jumping between focus on different
                      /// editable elements still resizes the editor
                      if ((cachedVisibleDecimal ?? 0) > 0.1) {
                        if (!mounted) return;
                        setState(() {
                          docHeight =
                              widget.otherOptions.height *
                              cachedVisibleDecimal!;
                        });
                        await setHeightJS();
                      }
                      var visibleDecimal = await visibleStream.stream
                          .firstWhere(
                            (_) => !visibleStream.isClosed,
                            orElse: () => 0,
                          );
                      if (visibleDecimal > 0.1 && mounted) {
                        setState(() {
                          docHeight =
                              widget.otherOptions.height * visibleDecimal;
                        });
                        await setHeightJS();
                      }
                    }
                  },
                  onLoadStop: (InAppWebViewController controller, Uri? uri) async {
                    var url = uri.toString();
                    if (url.contains(filePath)) {
                      final selectionScript =
                          widget.callbacks?.onChangeSelection == null
                          ? ''
                          : buildSummernoteSelectionScript(
                              dispatch: "window.flutter_inappwebview.callHandler('FormatSettings', message);",
                            );
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
                      final imageReaderErrorHandler =
                          widget.callbacks?.onImageUploadError == null
                          ? ''
                          : """
                                  var newObject = {
                                     'lastModified': files[0].lastModified,
                                     'lastModifiedDate': files[0].lastModifiedDate,
                                     'name': files[0].name,
                                     'size': files[0].size,
                                     'type': files[0].type
                                  };
                                  window.flutter_inappwebview.callHandler(
                                    'onImageUploadError',
                                    newObject,
                                    'base64 conversion failed'
                                  );
                              """;
                      if (widget.plugins.isNotEmpty) {
                        for (var p in widget.plugins) {
                          if (p is SummernoteAtMention) {
                            summernoteCallbacks =
                                summernoteCallbacks +
                                """
                              \nsummernoteAtMention: {
                                getSuggestions: async function(value) {
                                  return await window.flutter_inappwebview.callHandler('getSuggestions', value);
                                },
                                onSelect: (value) => {
                                  window.flutter_inappwebview.callHandler('onSelectMention', value);
                                },
                              },
                            """;
                          }
                        }
                      }
                      if (widget.callbacks != null) {
                        if (widget.callbacks!.onImageLinkInsert != null) {
                          summernoteCallbacks =
                              summernoteCallbacks +
                              """
                              onImageLinkInsert: function(url) {
                                window.flutter_inappwebview.callHandler('onImageLinkInsert', url);
                              },
                            """;
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
                                  var newObject = {
                                     'lastModified': files[0].lastModified,
                                     'lastModifiedDate': files[0].lastModifiedDate,
                                     'name': files[0].name,
                                     'size': files[0].size,
                                     'type': files[0].type,
                                     'base64': base64
                                  };
                                  window.flutter_inappwebview.callHandler('onImageUpload', newObject);
                                };
                                reader.onerror = function (_) {
                                  $imageReaderErrorHandler
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
                                    window.flutter_inappwebview.callHandler('onImageUploadError', file, error);
                                  } else {
                                    var newObject = {
                                       'lastModified': file.lastModified,
                                       'lastModifiedDate': file.lastModifiedDate,
                                       'name': file.name,
                                       'size': file.size,
                                       'type': file.type,
                                    };
                                    window.flutter_inappwebview.callHandler('onImageUploadError', newObject, error);
                                  }
                                },
                            """;
                        }
                      }
                      summernoteCallbacks = summernoteCallbacks + '}';
                      await controller.evaluateJavascript(
                        source:
                            """
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

                          \$('#summernote-2').on('summernote.change', function(_, contents, \$editable) {
                            window.flutter_inappwebview.callHandler(
                              'onChangeContent',
                              contents,
                              \$editable.text().length
                            );
                          });

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

                          ${widget.summernoteEditorOptions.autoAdjustHeight ? '''
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
                                  Math.ceil(${MediaQuery.sizeOf(context).height}),
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
                                window.flutter_inappwebview.callHandler('setHeight', height);
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
                            window.notifySummernoteEditorHeight();
                          }

                          setupSummernoteEditorAutoHeight();
                          ''' : ''}

                          $selectionScript
                      """,
                      );
                      await controller.evaluateJavascript(
                        source:
                            "document.getElementsByClassName('note-editable')[0].setAttribute('inputmode', '${widget.summernoteEditorOptions.inputType.name}');",
                      );
                      //set the text once the editor is loaded
                      if (widget.summernoteEditorOptions.initialText != null) {
                        widget.controller.setText(
                          widget.summernoteEditorOptions.initialText!,
                        );
                      }
                      //adjusts the height of the editor when it is loaded
                      if (widget.summernoteEditorOptions.autoAdjustHeight) {
                        await controller.evaluateJavascript(
                          source: "if (window.notifySummernoteEditorHeight) { window.notifySummernoteEditorHeight(); }",
                        );
                      }
                      //disable editor if necessary
                      if (widget.summernoteEditorOptions.disabled) {
                        widget.controller.disable();
                      }
                      //initialize callbacks
                      if (widget.callbacks != null) {
                        _addJavaScriptCallbacks(widget.callbacks!);
                      }
                      //call onInit callback
                      if (widget.callbacks != null &&
                          widget.callbacks!.onInit != null) {
                        widget.callbacks!.onInit!.call();
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _registerJavaScriptHandlers(InAppWebViewController controller) {
    if (widget.callbacks?.onChangeSelection != null) {
      controller.addJavaScriptHandler(
        handlerName: 'FormatSettings',
        callback: (arguments) {
          final settings = arguments.first as Map<String, dynamic>;
          widget.callbacks?.onChangeSelection?.call(
            editorSettingsFromMap(settings),
          );
        },
      );
    }

    if (widget.summernoteEditorOptions.autoAdjustHeight) {
      controller.addJavaScriptHandler(
        handlerName: 'setHeight',
        callback: (arguments) {
          if (arguments.first == 'reset') {
            resetHeight();
            return;
          }
          final height = double.tryParse(arguments.first.toString());
          if (height != null && height > 0 && height != docHeight && mounted) {
            setState(() => docHeight = height);
          }
        },
      );
    }
    controller.addJavaScriptHandler(
      handlerName: 'onChangeContent',
      callback: (arguments) {
        widget.controller.characterCount = arguments.length > 1
            ? (arguments[1] as num?)?.toInt() ?? 0
            : 0;
        widget.callbacks?.onChangeContent?.call(
          arguments.isEmpty ? null : arguments.first.toString(),
        );
      },
    );

    SummernoteAtMention? atMention;
    for (final plugin in widget.plugins) {
      if (plugin is SummernoteAtMention) {
        atMention = plugin;
        break;
      }
    }
    final mention = atMention;
    if (mention != null) {
      controller.addJavaScriptHandler(
        handlerName: 'getSuggestions',
        callback: (arguments) =>
            mention.getSuggestionsMobile!.call(arguments.first.toString()),
      );
      controller.addJavaScriptHandler(
        handlerName: 'onSelectMention',
        callback: (arguments) {
          mention.onSelect?.call(arguments.first.toString());
        },
      );
    }

    final callbacks = widget.callbacks;
    if (callbacks != null) _addJavaScriptHandlers(controller, callbacks);
  }

  /// adds the callbacks set by the user into the scripts
  void _addJavaScriptCallbacks(Callbacks c) {
    if (c.onBeforeCommand != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.before.command', function(_, contents) {
            window.flutter_inappwebview.callHandler('onBeforeCommand', contents);
          });
        """,
      );
    }
    if (c.onChangeCodeview != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.change.codeview', function(_, contents, \$editable) {
            window.flutter_inappwebview.callHandler('onChangeCodeview', contents);
          });
        """,
      );
    }
    if (c.onDialogShown != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.dialog.shown', function() {
            window.flutter_inappwebview.callHandler('onDialogShown', 'fired');
          });
        """,
      );
    }
    if (c.onEnter != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.enter', function() {
            window.flutter_inappwebview.callHandler('onEnter', 'fired');
          });
        """,
      );
    }
    if (c.onFocus != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.focus', function() {
            window.flutter_inappwebview.callHandler('onFocus', 'fired');
          });
        """,
      );
    }
    if (c.onBlur != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.blur', function() {
            window.flutter_inappwebview.callHandler('onBlur', 'fired');
          });
        """,
      );
    }
    if (c.onBlurCodeview != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.blur.codeview', function() {
            window.flutter_inappwebview.callHandler('onBlurCodeview', 'fired');
          });
        """,
      );
    }
    if (c.onKeyDown != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.keydown', function(_, e) {
            window.flutter_inappwebview.callHandler('onKeyDown', e.keyCode);
          });
        """,
      );
    }
    if (c.onKeyUp != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.keyup', function(_, e) {
            window.flutter_inappwebview.callHandler('onKeyUp', e.keyCode);
          });
        """,
      );
    }
    if (c.onMouseDown != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.mousedown', function(_) {
            window.flutter_inappwebview.callHandler('onMouseDown', 'fired');
          });
        """,
      );
    }
    if (c.onMouseUp != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.mouseup', function(_) {
            window.flutter_inappwebview.callHandler('onMouseUp', 'fired');
          });
        """,
      );
    }
    if (c.onPaste != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.paste', function(_) {
            window.flutter_inappwebview.callHandler('onPaste', 'fired');
          });
        """,
      );
    }
    if (c.onScroll != null) {
      widget.controller.editorController!.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.scroll', function(_) {
            window.flutter_inappwebview.callHandler('onScroll', 'fired');
          });
        """,
      );
    }
  }

  /// creates flutter_inappwebview JavaScript Handlers to handle any callbacks the
  /// user has defined
  void _addJavaScriptHandlers(InAppWebViewController controller, Callbacks c) {
    if (c.onBeforeCommand != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onBeforeCommand',
        callback: (contents) {
          c.onBeforeCommand!.call(contents.first.toString());
        },
      );
    }
    if (c.onChangeCodeview != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onChangeCodeview',
        callback: (contents) {
          c.onChangeCodeview!.call(contents.first.toString());
        },
      );
    }
    if (c.onDialogShown != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onDialogShown',
        callback: (_) {
          c.onDialogShown!.call();
        },
      );
    }
    if (c.onEnter != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onEnter',
        callback: (_) {
          c.onEnter!.call();
        },
      );
    }
    if (c.onFocus != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onFocus',
        callback: (_) {
          c.onFocus!.call();
        },
      );
    }
    if (c.onBlur != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onBlur',
        callback: (_) {
          c.onBlur!.call();
        },
      );
    }
    if (c.onBlurCodeview != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onBlurCodeview',
        callback: (_) {
          c.onBlurCodeview!.call();
        },
      );
    }
    if (c.onImageLinkInsert != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onImageLinkInsert',
        callback: (url) {
          c.onImageLinkInsert!.call(url.first.toString());
        },
      );
    }
    if (c.onImageUpload != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onImageUpload',
        callback: (files) {
          c.onImageUpload!.call(_fileUploadFromArgument(files.first));
        },
      );
    }
    if (c.onImageUploadError != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onImageUploadError',
        callback: (args) {
          final error = _uploadError(args.last);
          if (!args.first.toString().startsWith('{')) {
            c.onImageUploadError!.call(null, args.first?.toString(), error);
          } else {
            c.onImageUploadError!.call(
              _fileUploadFromArgument(args.first),
              null,
              error,
            );
          }
        },
      );
    }
    if (c.onKeyDown != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onKeyDown',
        callback: (keyCode) {
          c.onKeyDown!.call(keyCode.first);
        },
      );
    }
    if (c.onKeyUp != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onKeyUp',
        callback: (keyCode) {
          c.onKeyUp!.call(keyCode.first);
        },
      );
    }
    if (c.onMouseDown != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onMouseDown',
        callback: (_) {
          c.onMouseDown!.call();
        },
      );
    }
    if (c.onMouseUp != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onMouseUp',
        callback: (_) {
          c.onMouseUp!.call();
        },
      );
    }
    if (c.onPaste != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onPaste',
        callback: (_) {
          c.onPaste!.call();
        },
      );
    }
    if (c.onScroll != null) {
      controller.addJavaScriptHandler(
        handlerName: 'onScroll',
        callback: (_) {
          c.onScroll!.call();
        },
      );
    }
  }

  UploadError _uploadError(dynamic error) {
    final message = error?.toString() ?? '';
    if (message.contains('base64')) return UploadError.jsException;
    if (message.contains('unsupported')) return UploadError.unsupportedFile;
    return UploadError.exceededMaxSize;
  }

  FileUpload _fileUploadFromArgument(dynamic value) {
    if (value is Map) {
      return FileUpload.fromJson(Map<String, dynamic>.from(value));
    }
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return FileUpload.fromJson(Map<String, dynamic>.from(decoded));
      }
    }
    return const FileUpload();
  }
}
