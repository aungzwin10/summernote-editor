/// A Summernote-powered rich HTML editor for Flutter on Android, iOS, and web.
library summernote_editor;

export 'package:summernote_editor/utils/callbacks.dart';
export 'package:summernote_editor/utils/plugins.dart';
export 'package:summernote_editor/utils/file_upload_model.dart';
export 'package:summernote_editor/utils/options.dart';
export 'package:summernote_editor/utils/utils.dart' hide getRandString;

export 'package:summernote_editor/src/summernote_editor_unsupported.dart'
    if (dart.library.js_interop) 'package:summernote_editor/src/summernote_editor_web.dart'
    if (dart.library.io) 'package:summernote_editor/src/summernote_editor_mobile.dart';

export 'package:summernote_editor/src/summernote_editor_controller_unsupported.dart'
    if (dart.library.js_interop) 'package:summernote_editor/src/summernote_editor_controller_web.dart'
    if (dart.library.io) 'package:summernote_editor/src/summernote_editor_controller_mobile.dart';

export 'package:summernote_editor/utils/shims/flutter_inappwebview_fake.dart'
    if (dart.library.io) 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Defines the 3 different cases for file insertion failing
enum UploadError { unsupportedFile, exceededMaxSize, jsException }

/// Manages the notification type for a notification displayed at the bottom of
/// the editor
enum NotificationType { info, warning, success, danger, plaintext }

/// Sets how the virtual keyboard appears on mobile devices
enum SummernoteInputType { decimal, email, numeric, tel, url, text }
