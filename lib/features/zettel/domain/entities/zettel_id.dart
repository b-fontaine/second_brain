import 'package:equatable/equatable.dart';

/// Unique, immutable identifier of a zettel.
///
/// Timestamp-based (`yyyyMMddHHmmss`), the convention recommended by
/// zettelkasten.de: chronological, unique, and independent of the title.
class ZettelId extends Equatable {
  const ZettelId._(this.value);

  /// Builds an id from an existing raw string (e.g. parsed from a file name).
  ///
  /// Throws [FormatException] if [raw] is not a 14-digit timestamp.
  factory ZettelId.fromString(String raw) {
    if (!_pattern.hasMatch(raw)) {
      throw FormatException('Invalid zettel id: $raw');
    }
    return ZettelId._(raw);
  }

  /// Builds an id from a point in time.
  factory ZettelId.fromDateTime(DateTime moment) {
    final local = moment.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return ZettelId._(
      '${local.year}${two(local.month)}${two(local.day)}'
      '${two(local.hour)}${two(local.minute)}${two(local.second)}',
    );
  }

  static final _pattern = RegExp(r'^\d{14}$');

  final String value;

  static bool isValid(String raw) => _pattern.hasMatch(raw);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
