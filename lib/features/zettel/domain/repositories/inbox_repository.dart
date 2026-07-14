import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/inbox_item.dart';

/// Access to raw captures awaiting processing (`inbox/` folder).
abstract interface class InboxRepository {
  Future<Either<Failure, InboxItem>> addItem(InboxItem item);

  Future<Either<Failure, List<InboxItem>>> getPendingItems();

  Future<Either<Failure, InboxItem>> updateItem(InboxItem item);

  Future<Either<Failure, Unit>> removeItem(String id);
}
