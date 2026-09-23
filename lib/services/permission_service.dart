import 'package:flutter/services.dart';

/// Uses the small Android channel so no online package is needed for microphone
/// permission. Other platforms deliberately return false until implemented.
class MicrophonePermissionService {
  static const _channel = MethodChannel('org.sih.santali_setu/permissions');

  Future<bool> request() async {
    try {
      return await _channel.invokeMethod<bool>('requestMicrophone') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
