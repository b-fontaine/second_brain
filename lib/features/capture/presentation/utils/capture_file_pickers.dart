import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/capture_bloc.dart';

/// File pickers shared by the capture source cards and the seed dial.
///
/// Each helper opens the platform picker and maps the selection to the
/// [CaptureEvent] of the existing pipeline (transcription or OCR); `null`
/// means the user cancelled. Keeping the mapping here lets any surface
/// (cards, dial, shortcuts) trigger a flow without duplicating the
/// extension lists.

/// Extensions the audio transcription pipeline accepts.
const List<String> captureAudioExtensions = [
  'wav',
  'm4a',
  'mp3',
  'aac',
  'flac',
  'ogg',
  'opus',
];

/// Extensions the image OCR pipeline accepts.
const List<String> captureImageExtensions = [
  'png',
  'jpg',
  'jpeg',
  'webp',
  'bmp',
  'tiff',
];

/// Desktop platforms pick images with file_selector; mobile goes through
/// the photo gallery (image_picker).
bool get isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Picks an audio file to transcribe.
Future<CaptureEvent?> pickAudioFileEvent() async {
  final group = XTypeGroup(
    label: 'Audio',
    extensions: captureAudioExtensions,
    uniformTypeIdentifiers: const ['public.audio'],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  return file == null ? null : CaptureAudioFilePicked(file.path);
}

/// Picks a screenshot/image to run OCR on.
Future<CaptureEvent?> pickScreenshotEvent() async {
  if (isDesktopPlatform) {
    final group = XTypeGroup(
      label: 'Images',
      extensions: captureImageExtensions,
      uniformTypeIdentifiers: const ['public.image'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    return file == null ? null : CaptureScreenshotPicked(file.path);
  }
  final image = await ImagePicker().pickImage(source: ImageSource.gallery);
  return image == null ? null : CaptureScreenshotPicked(image.path);
}

/// Picks any file the current pipelines can ingest (audio or image) and
/// routes it to the matching flow by extension. `.md`/`.txt` intake will
/// join once the CaptureIntake service lands (chantier 3); until then the
/// picker only offers formats that already have a pipeline.
Future<CaptureEvent?> pickCaptureFileEvent() async {
  final group = XTypeGroup(
    label: 'Audio ou image',
    extensions: [...captureAudioExtensions, ...captureImageExtensions],
    uniformTypeIdentifiers: const ['public.audio', 'public.image'],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;
  final extension = file.path.split('.').last.toLowerCase();
  return captureImageExtensions.contains(extension)
      ? CaptureScreenshotPicked(file.path)
      : CaptureAudioFilePicked(file.path);
}
