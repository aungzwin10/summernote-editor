/// The [FileUpload] class stores any known data about a file. This class is used
/// as an argument in some callbacks relating to image and file insertion.
///
/// The class holds last modified information, name, size, type, and the base64
/// of the file.
///
/// Note that all parameters are nullable to prevent any null-exception when
/// getting file data from JavaScript.
class FileUpload {
  const FileUpload({
    this.base64,
    this.lastModified,
    this.lastModifiedDate,
    this.name,
    this.size,
    this.type,
  });

  /// The base64 string of the file.
  ///
  /// Note: This includes identifying data (e.g. data:image/jpeg;base64,) at the
  /// beginning. To strip this out, split a non-null value at the first comma.
  final String? base64;

  /// Last modified information in *milliseconds since epoch* format
  final DateTime? lastModified;

  /// Last modified information in *regular date* format
  final DateTime? lastModifiedDate;

  /// The filename
  final String? name;

  /// The file size in bytes
  final int? size;

  /// The content-type (eg. image/jpeg) of the file
  final String? type;

  /// Creates an instance of [FileUpload] from a decoded JSON map.
  factory FileUpload.fromJson(Map<String, dynamic> json) => FileUpload(
    base64: json['base64']?.toString(),
    lastModified: _millisecondsDate(json['lastModified']),
    lastModifiedDate: _date(json['lastModifiedDate']),
    name: json['name']?.toString(),
    size: _integer(json['size']),
    type: json['type']?.toString(),
  );
}

DateTime? _millisecondsDate(dynamic value) {
  final milliseconds = _integer(value);
  return milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  return value == null ? null : DateTime.tryParse(value.toString());
}

int? _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
