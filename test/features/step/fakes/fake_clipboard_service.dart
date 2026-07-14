import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';

/// Scriptable system clipboard.
///
/// Scripting: assign [content] (e.g. `ClipboardContent(text: '...')`)
/// before triggering a clipboard capture. Defaults to an empty clipboard.
class FakeClipboardService implements ClipboardService {
  ClipboardContent content = const ClipboardContent();

  @override
  Future<ClipboardContent> read() async => content;
}
