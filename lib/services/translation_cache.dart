import '../domain/language.dart';
import '../domain/translation_result.dart';

class TranslationCache {
  final Map<String, TranslationResult> _entries = {};
  String _key(String text, Language source, Language target) =>
      '${source.name}|${target.name}|${text.trim()}';
  TranslationResult? get(String text, Language source, Language target) =>
      _entries[_key(text, source, target)];
  void put(String text, TranslationResult value) =>
      _entries[_key(text, value.sourceLanguage, value.targetLanguage)] = value;
  int get count => _entries.length;
  void clear() => _entries.clear();
}
