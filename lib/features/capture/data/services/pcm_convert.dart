import 'dart:typed_data';

/// Converts little-endian 16-bit PCM bytes (the `record` stream format) to
/// normalized 32-bit floats in [-1.0, 1.0], as expected by sherpa-onnx.
Float32List pcm16BytesToFloat32(
  Uint8List bytes, [
  Endian endian = Endian.little,
]) {
  final sampleCount = bytes.length ~/ 2;
  final values = Float32List(sampleCount);
  final data = ByteData.sublistView(bytes, 0, sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    values[i] = data.getInt16(i * 2, endian) / 32768.0;
  }
  return values;
}
