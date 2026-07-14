import 'package:second_brain/core/services/clock.dart';

/// Deterministic, manually advanced clock.
///
/// Scripting: read/assign [current] freely, or call [advance] between two
/// zettel creations so their timestamp ids differ (the world helper
/// `worldCreateZettel` does it for you). `now()` never auto-advances.
class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  void advance([Duration duration = const Duration(seconds: 1)]) {
    current = current.add(duration);
  }

  @override
  DateTime now() => current;
}
