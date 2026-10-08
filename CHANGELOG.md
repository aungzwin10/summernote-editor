## 1.0.0 - 2026-10-07

* Initial `summernote_editor` release
* Expose the editor as `SummernoteEditor`, with `SummernoteEditorController`,
  `SummernoteEditorOptions`, and `SummernoteInputType`
* Require Flutter 3.47.6 and Dart 3.13.5
* Update all direct package dependencies to their latest available releases
* Modernize the example app platform runners for current Flutter tooling
* Use `dart:ui_web`, `package:web`, and `dart:js_interop` for Wasm-compatible web support
* Bundle Summernote Lite 0.9.1
* Use Summernote's built-in toolbar consistently across mobile and web
* Configure the default toolbar with all built-in controls except the `view` group and the
  `video` and `table` insertion controls, while allowing `customOptions` to replace it
* Make auto-height editors follow live content size without an inner vertical scroll
* Disable manual editor resizing and stop scrolling the parent on every typed character
* Expand auto-height editors around visible Summernote dropdowns, popovers, and dialogs so they
  are not clipped by the WebView or iframe boundary
* Prevent fullscreen from entering an auto-height resize feedback loop
* Consolidate web callback dispatch into one disposable listener, scope controller responses per
  editor, and register mobile bridge handlers only once across page reloads
* Correlate concurrent web controller reads, use exact iframe command matching, and safely encode
  all mobile controller arguments before evaluating JavaScript
* Coalesce auto-height measurements to one animation frame and suppress unchanged height messages
* Make callback and configuration payloads immutable and harden upload metadata parsing and
  image-reader error routing
* Initialize editor content, disabled state, input mode, and height before firing `onInit`
* Include a responsive two-editor example covering independent controllers, seeded HTML and an
  embedded image, per-editor enable/disable actions, and concurrent reads
* Stop editor platform views from intercepting input or painting above Flutter dialogs and popup
  routes, while preserving editor state and restoring interaction after dismissal
