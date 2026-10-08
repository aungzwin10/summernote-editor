# summernote_editor

A Summernote-based rich-text HTML editor for Flutter on Android, iOS, and web.

Version 1.0.0 embeds **Summernote Lite 0.9.1** and uses Summernote's own toolbar on
every supported platform. The previous Flutter-native toolbar API has been removed.

`summernote_editor` is a maintained successor to
[`html_editor_enhanced`](https://pub.dev/packages/html_editor_enhanced). The original project is
Copyright (c) 2020 Tanay Neotia and remains acknowledged under the included MIT license.

## Features

- One editor API for Android, iOS, and Flutter web
- Summernote Lite toolbar, dialogs, code view, tables, links, images, and video
- Content-based height by default, with no nested vertical editor scroll
- Optional fixed-height mode
- Controller commands and Summernote callbacks
- Initial HTML, character limits, spellcheck, custom Summernote options, and custom templates
- Mobile and web JavaScript hooks
- Optional Summernote at-mention plugin

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  summernote_editor: ^1.0.0
```

Then import the public library:

```dart
import 'package:summernote_editor/summernote_editor.dart';
```

For Android, make sure the app has internet permission if the editor will load remote images,
links, or videos:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Basic usage

Place the editor in the same Flutter scrollable as the surrounding content. With
`autoAdjustHeight: true` (the default), the editor grows and shrinks with its content, and the
parent Flutter widget owns vertical scrolling.

```dart
final controller = SummernoteEditorController();

SingleChildScrollView(
  child: Column(
    children: [
      const Text('Article'),
      SummernoteEditor(
        controller: controller,
        summernoteEditorOptions: const SummernoteEditorOptions(
          hint: 'Write something…',
          shouldEnsureVisible: true,
        ),
        otherOptions: const OtherOptions(height: 400),
        callbacks: Callbacks(
          onChangeContent: (html) => debugPrint(html),
        ),
      ),
    ],
  ),
)
```

`OtherOptions.height` is the temporary loading height in content-height mode. When
`autoAdjustHeight` is false, it is the total fixed height of the Summernote toolbar and editable
area.

## Summernote toolbar

The built-in Summernote Lite toolbar is enabled automatically. Its default configuration includes
all built-in style, font, color, paragraph, insertion, and history controls except the complete
`view` group and the `video` and `table` insertion controls. It runs inside the editor document, so
toolbar state, dropdowns, dialogs, and selection handling stay within Summernote instead of being
duplicated by Flutter widgets.

Customize its groups with Summernote's `toolbar` option through `customOptions`:

```dart
SummernoteEditor(
  controller: controller,
  summernoteEditorOptions: const SummernoteEditorOptions(
    customOptions: '''
      toolbar: [
        ['font', ['bold', 'italic', 'underline', 'clear']],
        ['para', ['ul', 'ol', 'paragraph']],
        ['insert', ['link', 'picture']]
      ],
    ''',
  ),
)
```

`customOptions` is inserted after the package defaults, so a supplied `toolbar` property replaces
the default toolbar. Non-empty values must use valid Summernote syntax and end with a comma. The
package always disables Summernote's manual resize handle; Flutter or the surrounding layout
controls the editor size.

In content-height mode, the editor temporarily expands while a Summernote dropdown, popover, or
dialog is visible so the overlay is not clipped by the iframe/WebView. It returns to content height
when the overlay closes.

## Fixed-height mode

Use a fixed-height editor only when a nested editor scroll is intentional:

```dart
SummernoteEditor(
  controller: controller,
  summernoteEditorOptions: const SummernoteEditorOptions(
    autoAdjustHeight: false,
    adjustHeightForKeyboard: true,
  ),
  otherOptions: const OtherOptions(height: 420),
)
```

## Controller

Create one controller per editor. Common operations include:

```dart
final html = await controller.getText();

controller.setText('<p>Hello</p>');
controller.insertText('Plain text');
controller.insertHtml('<strong>HTML</strong>');
controller.insertLink('OpenAI', 'https://openai.com', true);
controller.insertNetworkImage('https://example.com/image.png');

controller.undo();
controller.redo();
controller.clear();
controller.setFocus();
controller.toggleCodeView();
controller.disable();
controller.enable();
```

Other available commands include `execCommand`, `setHint`, `setFullScreen`,
`recalculateHeight`, `addNotification`, `removeNotification`, `getSelectedTextWeb`,
`evaluateJavascriptWeb`, `reloadWeb`, `clearFocus`, and `resetHeight`. Platform-specific methods
should be guarded with `kIsWeb` where appropriate. On mobile, issue startup commands from
`Callbacks.onInit`, after the WebView has initialized.

## Options

`SummernoteEditorOptions` supports:

- `autoAdjustHeight`: follow rendered toolbar and content height; defaults to `true`
- `adjustHeightForKeyboard`: resize fixed-height mobile editors around the keyboard
- `androidUseHybridComposition`: Android WebView composition mode
- `characterLimit`: maximum text character count
- `customOptions`: raw Summernote initialization properties
- `disabled`: start with editing and toolbar controls disabled
- `filePath`: custom HTML template
- `hint` and `initialText`
- `inputType`: mobile virtual keyboard mode
- `mobileContextMenu`, `mobileInitialScripts`, and `mobileLongPressDuration`
- `webInitialScripts`
- `shouldEnsureVisible`: reveal the editor when it receives focus
- `spellCheck`

`OtherOptions` contains the editor `height` and outer `decoration`.

## Callbacks

Use `Callbacks` to observe Summernote and bridge events:

```dart
callbacks: Callbacks(
  onInit: () => debugPrint('ready'),
  onChangeContent: (html) => debugPrint('changed: $html'),
  onFocus: () => debugPrint('focused'),
  onBlur: () => debugPrint('blurred'),
  onDialogShown: () => debugPrint('dialog opened'),
  onChangeSelection: (settings) {
    debugPrint('font: ${settings.fontName}');
  },
),
```

Image callbacks intentionally replace Summernote's default insertion behavior. When using
`onImageLinkInsert` or `onImageUpload`, insert the resulting image yourself with the controller if
that is the desired behavior.

## At mentions

```dart
plugins: [
  SummernoteAtMention(
    getSuggestionsMobile: (query) =>
        ['alice', 'bob'].where((name) => name.contains(query)).toList(),
    mentionsWeb: const ['alice', 'bob'],
    onSelect: (name) => debugPrint('selected $name'),
  ),
],
```

Mobile suggestions are produced by a Dart callback. Web suggestions are filtered from the static
`mentionsWeb` list inside the iframe.

## Example app

The bundled example is intentionally small enough to use as a starting point. It demonstrates two
independent editors on one responsive page, initial HTML with an embedded image, per-editor
enable/disable actions, safe controller use after `onInit`, and concurrent reads.

Run it with:

```sh
cd example
flutter run -d chrome
```

## Custom HTML template

The editor element must have the ID `summernote-2`. Flutter web templates must also retain these
injection markers:

```html
<head>
  <!--headString-->
</head>
<body>
  <div id="summernote-2"></div>
  <!--summernoteScripts-->
</body>
```

Declare the custom template as a Flutter asset and pass its path through
`SummernoteEditorOptions.filePath`. The template must load compatible jQuery and Summernote assets.

## Vendored editor version

Summernote Lite 0.9.1 is vendored under `lib/assets`. Source and checksums are recorded in
[`lib/assets/SUMMERNOTE.md`](lib/assets/SUMMERNOTE.md).

## Platform notes

- The editor is backed by `flutter_inappwebview` on Android and iOS.
- Flutter web uses an iframe platform view.
- There is currently no automated integration-test suite. Changes involving WebView/iframe input,
  toolbar dialogs, file selection, keyboard behavior, or scrolling should be checked on the target
  platforms.

## License

This package is licensed under the MIT License. See [LICENSE](LICENSE).
