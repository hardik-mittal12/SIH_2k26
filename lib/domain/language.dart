enum Language { hindi, santali }

extension LanguageLabel on Language {
  String get label => this == Language.hindi ? 'Hindi' : 'Santali';
  String get speechLabel =>
      this == Language.hindi ? 'Speak Hindi' : 'Speak Santali';
  String get sarvamCode => this == Language.hindi ? 'hi-IN' : 'sat-IN';
}

class TranslationDirection {
  const TranslationDirection(this.source, this.target);
  final Language source;
  final Language target;
  TranslationDirection swapped() => TranslationDirection(target, source);
  @override
  String toString() => '${source.name}-${target.name}';
}
