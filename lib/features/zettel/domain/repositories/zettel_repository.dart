import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/zettel.dart';
import '../entities/zettel_id.dart';

/// Emitted whenever the vault content changes (note saved, deleted,
/// or files updated by a git pull). Consumers: UI lists, graph, sync.
class VaultChanged {
  const VaultChanged();
}

/// Access to the permanent notes of the vault (`zettel/` folder).
///
/// Implementations persist each zettel as a markdown file with YAML
/// frontmatter — see docs/ARCHITECTURE.md for the exact format.
abstract interface class ZettelRepository {
  Future<Either<Failure, List<Zettel>>> getAllZettels();

  Future<Either<Failure, Zettel>> getZettelById(ZettelId id);

  /// Creates a new zettel, generating its timestamp id and file name.
  Future<Either<Failure, Zettel>> createZettel({
    required String title,
    required String body,
    List<String> tags,
    String? source,
  });

  Future<Either<Failure, Zettel>> updateZettel(Zettel zettel);

  Future<Either<Failure, Unit>> deleteZettel(ZettelId id);

  /// Case/diacritic-insensitive search over titles, bodies and tags.
  Future<Either<Failure, List<Zettel>>> searchZettels(String query);

  /// Zettels whose body links to [id].
  Future<Either<Failure, List<Zettel>>> getBacklinks(ZettelId id);

  /// Fires after any mutation of the vault.
  Stream<VaultChanged> watchVault();
}
