import 'package:equatable/equatable.dart';

import '../../../zettel/domain/entities/zettel_id.dart';

/// Answer of the assistant to a knowledge-base question.
class AssistantAnswer extends Equatable {
  const AssistantAnswer({required this.text, this.citedZettels = const []});

  /// Markdown answer; may contain `[[id]]` citations.
  final String text;

  /// Zettels used as context and cited as sources, most relevant first.
  final List<ZettelId> citedZettels;

  @override
  List<Object?> get props => [text, citedZettels];
}
