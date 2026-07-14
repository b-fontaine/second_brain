import 'package:injectable/injectable.dart';

/// Injectable time source so id generation is testable.
abstract interface class Clock {
  DateTime now();
}

@LazySingleton(as: Clock)
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}
