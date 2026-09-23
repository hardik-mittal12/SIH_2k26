enum Language { hindi, santali }

extension LanguageLabel on Language {
  String get label => this == Language.hindi ? 'Hindi' : 'Santali';
  String get speechLabel =>
      this == Language.hindi ? 'Speak Hindi' : 'Speak Santali';
}

class TranslationDirection {
  const TranslationDirection(this.source, this.target);
  final Language source;
  final Language target;
  TranslationDirection swapped() => TranslationDirection(target, source);
  @override
  String toString() => '${source.name}-${target.name}';
}
