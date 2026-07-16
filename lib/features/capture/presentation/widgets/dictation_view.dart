import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/serre_tokens.dart';
import '../bloc/capture_bloc.dart';
import '../bloc/dictation_transcript.dart';

/// Immersive live dictation, « serre de nuit » : full-screen night
/// greenhouse backdrop, animated amplitude wave, live transcript with the
/// revisable partial rendered in italics, and a prominent stop control.
///
/// Stopping sows the transcript into the inbox nursery (Pépinière) — the
/// [CaptureBloc] runs it through `CaptureIntake` — while « Annuler »
/// discards it and returns to the capture sources.
///
/// The view deliberately commits to the dark token set ([SerreTokens.dark])
/// whatever the app brightness: dictation is a focused, low-light surface.
///
/// The wave is NOT fed by a microphone amplitude stream: the recorder is
/// private to `SherpaTranscriptionService` and `TranscriptionService`
/// exposes no amplitude API. Instead, each transcript update triggers ONE
/// bounded swell of the animation controller — never `repeat()` — so
/// `pumpAndSettle` always terminates in tests, and reduced motion
/// (`MediaQuery.disableAnimations`) renders a fully static wave.
class DictationView extends StatefulWidget {
  const DictationView({super.key, required this.transcript});

  final DictationTranscript transcript;

  @override
  State<DictationView> createState() => _DictationViewState();
}

class _DictationViewState extends State<DictationView>
    with SingleTickerProviderStateMixin {
  /// Night-greenhouse palette (#17231A paper, #1E2C1F surface, #EFF4EA ink).
  static const SerreTokens _night = SerreTokens.dark;

  /// One bounded swell of the wave (rise then rest), re-armed by every
  /// transcript change. Bounded on purpose: an infinite `repeat()` would
  /// hang every `pumpAndSettle` of the widget/BDD harness.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      // Frozen mid-swell: the wave stays visible but never schedules a
      // frame, keeping reduced-motion (and test) environments settled.
      _pulse.value = 0.5;
    } else {
      _pulse.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DictationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-read reduce-motion from context: didUpdateWidget is called BEFORE
    // didChangeDependencies in the same frame, so the cached field may be
    // stale.  Explicitly stop the ticker so that even if forward() somehow
    // fires first (e.g. during a re-mount), reduced motion wins.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _pulse.stop(); // no-op when already stopped; cancels pending tick otherwise
      return;
    }
    if (widget.transcript == oldWidget.transcript) return;
    _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bloc = context.read<CaptureBloc>();
    return Scaffold(
      backgroundColor: _night.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _night.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic, color: _night.fleur),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dictée en cours…',
                              style: textTheme.titleMedium?.copyWith(
                                color: _night.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hors-ligne — l’arrêt sème le brouillon en '
                              'pépinière.',
                              style: textTheme.bodySmall?.copyWith(
                                color: _night.sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _night.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _night.line),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: widget.transcript.isEmpty
                            ? Text(
                                'Parlez, le texte apparaît ici…',
                                style: textTheme.bodyLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: _night.sub,
                                ),
                              )
                            : Text.rich(
                                key: const Key('dictation-transcript'),
                                TextSpan(
                                  children: [
                                    TextSpan(text: widget.transcript.committed),
                                    if (widget.transcript.partial.isNotEmpty)
                                      TextSpan(
                                        text:
                                            widget.transcript.committed.isEmpty
                                            ? widget.transcript.partial
                                            : ' ${widget.transcript.partial}',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: _night.sub,
                                        ),
                                      ),
                                  ],
                                ),
                                style: textTheme.bodyLarge?.copyWith(
                                  color: _night.ink,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('dictation-wave'),
                        size: Size.infinite,
                        painter: _WavePainter(
                          pulse: _pulse,
                          seed: widget.transcript.fullText.length,
                          color: _night.feuillage,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('dictation-stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _night.fleur,
                      foregroundColor: _night.paper,
                      minimumSize: const Size.fromHeight(60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: textTheme.titleMedium,
                    ),
                    onPressed: () =>
                        bloc.add(const CaptureDictationStopped()),
                    icon: const Icon(Icons.stop_rounded, size: 30),
                    label: const Text('Arrêter la dictée'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _night.sub),
                    onPressed: () => bloc.add(const CaptureReset()),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Amplitude-like wave: a row of rounded bars whose heights swell with the
/// bounded [pulse] and vary per bar through a deterministic jitter reseeded
/// by [seed] (the transcript length), so arriving words visibly reshape it.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.pulse, required this.seed, required this.color})
    : super(repaint: pulse);

  final Animation<double> pulse;
  final int seed;
  final Color color;

  static const int _barCount = 27;

  @override
  void paint(Canvas canvas, Size size) {
    final t = pulse.value;
    // Rises then falls back to rest over one bounded swell.
    final energy = math.sin(t * math.pi);
    final slot = size.width / _barCount;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = slot * 0.55;
    final centre = size.height / 2;
    for (var i = 0; i < _barCount; i++) {
      final jitter = _noise(i * 12.9898 + seed * 0.618);
      final ripple =
          (0.6 + 0.4 * math.sin(i * 0.85 + t * math.pi * 2)).abs();
      final amp = (0.12 + energy * (0.25 + 0.63 * jitter) * ripple).clamp(
        0.08,
        1.0,
      );
      final half = size.height * amp / 2;
      final x = slot * (i + 0.5);
      paint.color = color.withValues(alpha: 0.45 + 0.55 * jitter);
      canvas.drawLine(Offset(x, centre - half), Offset(x, centre + half), paint);
    }
  }

  /// Deterministic pseudo-random in [0, 1) — no dart:math Random, so the
  /// wave is reproducible frame to frame for a given seed.
  static double _noise(double x) {
    final v = math.sin(x) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.color != color ||
      oldDelegate.pulse != pulse;
}
