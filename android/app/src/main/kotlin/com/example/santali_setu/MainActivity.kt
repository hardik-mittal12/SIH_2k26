package com.example.santali_setu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Native inference seam. Keep model runtime objects here (or a dedicated Android
 * module), never in Flutter widgets. The mock Dart implementation does not call it.
 */
class MainActivity : FlutterActivity() {
    private var microphoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.sih.santali_setu/inference")
            .setMethodCallHandler { call, result ->
                result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.sih.santali_setu/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestMicrophone") {
                    result.notImplemented()
                } else if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else {
                    microphoneResult = result
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 4101)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4101) {
            microphoneResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            microphoneResult = null
        }
    }
}
