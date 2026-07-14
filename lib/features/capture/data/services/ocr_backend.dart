/// A platform-specific OCR engine.
///
/// Implementations throw [OcrException] on engine errors. They all accept a
/// file path: every capture input (picker XFile, clipboard bytes) is
/// normalized to a temporary image file before reaching a backend, because a
/// file path is the one input format all engines support (ML Kit's
/// `InputImage.fromBytes` notably rejects PNG/JPEG bytes).
abstract interface class OcrBackend {
  Future<String> recognize(String imagePath);
}
