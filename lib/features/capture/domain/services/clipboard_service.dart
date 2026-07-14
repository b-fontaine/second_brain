/// Content currently held by the system clipboard.
class ClipboardContent {
  const ClipboardContent({this.text, this.imagePath});

  final String? text;

  /// Temp-file path of a pasted image, when the clipboard held one.
  final String? imagePath;

  bool get isEmpty => (text == null || text!.isEmpty) && imagePath == null;
}

/// Read access to the system clipboard (text and, where supported, images).
abstract interface class ClipboardService {
  Future<ClipboardContent> read();
}
