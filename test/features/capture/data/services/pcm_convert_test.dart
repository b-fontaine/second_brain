import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/data/services/pcm_convert.dart';

void main() {
  test('converts little-endian PCM16 samples to normalized floats', () {
    // Samples: 0, 32767 (max), -32768 (min), -1.
    final bytes = Uint8List.fromList([
      0x00, 0x00, //
      0xFF, 0x7F, //
      0x00, 0x80, //
      0xFF, 0xFF, //
    ]);

    final floats = pcm16BytesToFloat32(bytes);

    expect(floats, hasLength(4));
    expect(floats[0], 0.0);
    expect(floats[1], closeTo(32767 / 32768.0, 1e-6));
    expect(floats[2], -1.0);
    expect(floats[3], closeTo(-1 / 32768.0, 1e-9));
  });

  test('ignores a trailing odd byte', () {
    final bytes = Uint8List.fromList([0x00, 0x40, 0x12]);

    final floats = pcm16BytesToFloat32(bytes);

    expect(floats, hasLength(1));
    expect(floats[0], closeTo(0x4000 / 32768.0, 1e-6));
  });

  test('returns an empty list for empty input', () {
    expect(pcm16BytesToFloat32(Uint8List(0)), isEmpty);
  });
}
