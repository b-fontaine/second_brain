/// Offline text extraction from images (screenshots).
///
/// Throws [OcrException] on engine errors.
abstract interface class OcrService {
  /// Extracts readable text from the image at [imagePath],
  /// preserving line structure when possible.
  Future<String> recognizeText(String imagePath);
}
