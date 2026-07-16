import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/services/capture_intake.dart';
import '../bloc/capture_bloc.dart';

export '../../domain/services/capture_intake.dart'
    show captureAudioExtensions, captureImageExtensions, captureTextExtensions;

/// File pickers shared by the capture source cards and the seed dial.
///
/// Each helper opens the platform picker; `null` means the user cancelled.
/// The extension lists live in the domain ([CaptureIntake] routes a picked
/// file by extension), so any surface (cards, dial, shortcuts) stays in
/// sync with what the pipelines actually accept.

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

/// Picks any file the seeding intake can ingest (.md/.txt notes, images,
/// audio) for the « aperçu avant semis » flow; the kind detection itself
/// happens in [CaptureIntake]. Returns the path, or null on cancel.
Future<String?> pickSeedFilePath() async {
  final group = XTypeGroup(
    label: 'Notes, images ou audio',
    extensions: [
      ...captureTextExtensions,
      ...captureImageExtensions,
      ...captureAudioExtensions,
    ],
    uniformTypeIdentifiers: const [
      'public.plain-text',
      'public.image',
      'public.audio',
    ],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  return file?.path;
}
