import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../domain/language.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

enum SpeechApiStage { uploading, transcribing }

typedef SpeechStageCallback = void Function(SpeechApiStage stage);

class SpeechTranscription {
  const SpeechTranscription({
    required this.text,
    required this.detectedLanguage,
    required this.elapsed,
  });

  final String text;
  final String? detectedLanguage;
  final Duration elapsed;
}

class BackendApiException implements Exception {
  const BackendApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client for the project's backend only. Sarvam credentials never enter Flutter.
class SarvamBackendClient {
  SarvamBackendClient({String baseUrl = apiBaseUrl}) : _baseUrl = baseUrl.trim();

  final String _baseUrl;
  final Random _random = Random.secure();

  Uri _uri(String route) {
    if (_baseUrl.isEmpty) {
      throw const BackendApiException(
        'The API address is not configured. Run Flutter with --dart-define=API_BASE_URL=…',
      );
    }
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        !const {'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty) {
      throw const BackendApiException('API_BASE_URL must be a valid HTTP(S) URL.');
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$route',
      query: null,
      fragment: null,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 20));
      return await _decodeResponse(response);
    } on BackendApiException {
      rethrow;
    } on TimeoutException {
      throw const BackendApiException(
        'Unable to connect to the translation service. Please check your internet connection and backend address.',
      );
    } on SocketException {
      throw const BackendApiException(
        'Unable to connect to the translation service. Please check your internet connection and backend address.',
      );
    } on HttpException {
      throw const BackendApiException('The backend returned an invalid response.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _decodeResponse(HttpClientResponse response) async {
    final text = await utf8.decoder.bind(response).join();
    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(text) as Map);
    } on FormatException {
      throw const BackendApiException('The backend returned an invalid response.');
    } catch (_) {
      throw const BackendApiException('The backend returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error'];
      final code = payload['code'];
      throw BackendApiException(
        message is String && message.isNotEmpty
            ? message
            : 'The translation service could not complete the request.',
        code: code is String ? code : null,
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  Future<void> checkReady() async {
    final payload = await _getJson(_uri('/health'));
    if (payload['status'] != 'ok') {
      throw const BackendApiException('The translation backend is not ready.');
    }
    if (payload['sarvamConfigured'] != true) {
      throw const BackendApiException(
        'The backend is running, but SARVAM_API_KEY is not configured in server/.env.',
        code: 'SARVAM_NOT_CONFIGURED',
      );
    }
  }

  Future<SpeechTranscription> transcribe({
    required Uint8List wavAudio,
    required Language language,
    SpeechStageCallback? onStage,
  }) async {
    if (wavAudio.length <= 44) {
      throw const BackendApiException('The recording is empty. Please record again.');
    }
    const maxDurationBytes = 16_000 * 2 * 30;
    if (wavAudio.length - 44 > maxDurationBytes) {
      throw const BackendApiException('Keep each recording to 30 seconds or less.');
    }
    final uri = _uri('/api/speech-to-text');
    final boundary = 'santalisetu-${_random.nextInt(1 << 32).toRadixString(16)}';
    final body = _multipartBody(
      boundary: boundary,
      language: language.sarvamCode,
      wavAudio: wavAudio,
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final stopwatch = Stopwatch()..start();
    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 12));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      request.contentLength = body.length;
      onStage?.call(SpeechApiStage.uploading);
      request.add(body);
      await request.flush().timeout(const Duration(seconds: 35));
      onStage?.call(SpeechApiStage.transcribing);
      final response = await request.close().timeout(const Duration(seconds: 70));
      final payload = await _decodeResponse(response);
      final text = payload['text'];
      if (payload['success'] != true || text is! String || text.trim().isEmpty) {
        throw const BackendApiException('Speech recognition returned no transcript.');
      }
      stopwatch.stop();
      return SpeechTranscription(
        text: text.trim(),
        detectedLanguage: payload['language'] as String?,
        elapsed: stopwatch.elapsed,
      );
    } on BackendApiException {
      rethrow;
    } on TimeoutException {
      throw const BackendApiException('Speech recognition timed out. Please try again.');
    } on SocketException {
      throw const BackendApiException(
        'Unable to connect to the translation service. Please check your internet connection and backend address.',
      );
    } on HttpException {
      throw const BackendApiException('The backend returned an invalid response.');
    } finally {
      client.close(force: true);
    }
  }

  List<int> _multipartBody({
    required String boundary,
    required String language,
    required Uint8List wavAudio,
  }) {
    final body = BytesBuilder(copy: false);
    void field(String name, String value) {
      body.add(ascii.encode('--$boundary\r\n'));
      body.add(ascii.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
      body.add(utf8.encode(value));
      body.add(ascii.encode('\r\n'));
    }

    field('language', language);
    body.add(ascii.encode('--$boundary\r\n'));
    body.add(ascii.encode(
      'Content-Disposition: form-data; name="audio"; filename="recording.wav"\r\n',
    ));
    body.add(ascii.encode('Content-Type: audio/wav\r\n\r\n'));
    body.add(wavAudio);
    body.add(ascii.encode('\r\n--$boundary--\r\n'));
    return body.takeBytes();
  }

  Future<Map<String, dynamic>> translate({
    required String text,
    required Language source,
    required Language target,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const BackendApiException('Enter text to translate.');
    if (trimmed.runes.length > 2_000) {
      throw const BackendApiException('Keep translated text under 2,000 characters.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(_uri('/api/translate')).timeout(const Duration(seconds: 12));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..contentType = ContentType.json;
      request.write(jsonEncode({
        'text': trimmed,
        'sourceLanguage': source.sarvamCode,
        'targetLanguage': target.sarvamCode,
      }));
      final response = await request.close().timeout(const Duration(seconds: 60));
      final payload = await _decodeResponse(response);
      final translatedText = payload['translatedText'];
      if (payload['success'] != true ||
          translatedText is! String ||
          translatedText.trim().isEmpty) {
        throw const BackendApiException('Translation service returned no translated text.');
      }
      return payload;
    } on BackendApiException {
      rethrow;
    } on TimeoutException {
      throw const BackendApiException('Translation timed out. Please try again.');
    } on SocketException {
      throw const BackendApiException(
        'Unable to connect to the translation service. Please check your internet connection and backend address.',
      );
    } on HttpException {
      throw const BackendApiException('The backend returned an invalid response.');
    } finally {
      client.close(force: true);
    }
  }
}
