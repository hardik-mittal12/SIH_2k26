package org.sih.santalisetu

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

/** Android WAV microphone capture bridge. Cloud inference is performed by the backend. */
class MainActivity : FlutterActivity() {
    private var microphoneResult: MethodChannel.Result? = null
    private var recorder: AudioRecord? = null
    private var recordingThread: Thread? = null
    private val isRecording = AtomicBoolean(false)
    private val capturedPcm = ByteArrayOutputStream()
    private val captureLock = Any()
    private val sampleRate = 16_000

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.sih.santali_setu/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> startRecording(result)
                    "stopRecording" -> stopRecording(result)
                    "cancelRecording" -> {
                        stopAndReleaseRecorder()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
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

    private fun startRecording(result: MethodChannel.Result) {
        if (isRecording.get()) {
            result.error("RECORDING_ACTIVE", "A recording is already active.", null)
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("MIC_PERMISSION_DENIED", "Microphone permission has not been granted.", null)
            return
        }
        val minBytes = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBytes <= 0) {
            result.error("AUDIO_CONFIG_UNAVAILABLE", "The device does not support 16 kHz mono PCM recording.", null)
            return
        }
        try {
            val audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBytes, sampleRate * 2)
            )
            if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord.release()
                result.error("AUDIO_INIT_FAILED", "Android could not initialize the microphone recorder.", null)
                return
            }
            synchronized(captureLock) { capturedPcm.reset() }
            recorder = audioRecord
            audioRecord.startRecording()
            isRecording.set(true)
            recordingThread = Thread({ captureLoop(audioRecord) }, "santali-setu-audio-capture").apply { start() }
            result.success(null)
        } catch (error: Exception) {
            stopAndReleaseRecorder()
            result.error("AUDIO_START_FAILED", error.message ?: "Could not start recording.", null)
        }
    }

    private fun captureLoop(audioRecord: AudioRecord) {
        val samples = ShortArray(2048)
        val maximumSamples = sampleRate * 30
        var capturedSamples = 0
        while (isRecording.get() && capturedSamples < maximumSamples) {
            val requested = minOf(samples.size, maximumSamples - capturedSamples)
            val count = audioRecord.read(samples, 0, requested)
            if (count > 0) {
                val bytes = ByteBuffer.allocate(count * 2).order(ByteOrder.LITTLE_ENDIAN)
                for (index in 0 until count) bytes.putShort(samples[index])
                synchronized(captureLock) { capturedPcm.write(bytes.array()) }
                capturedSamples += count
            } else if (count < 0) {
                isRecording.set(false)
            }
        }
        if (capturedSamples >= maximumSamples) isRecording.set(false)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (recorder == null) {
            result.error("NO_ACTIVE_RECORDING", "There is no active recording to stop.", null)
            return
        }
        val wav = stopAndReleaseRecorder()
        if (wav.size <= 44) {
            result.error("EMPTY_RECORDING", "No microphone audio was captured.", null)
        } else {
            result.success(wav)
        }
    }

    /** Stops capture and returns a standard mono, signed PCM16, 16 kHz WAV. */
    private fun stopAndReleaseRecorder(): ByteArray {
        val audioRecord = recorder
        isRecording.set(false)
        try {
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) audioRecord.stop()
        } catch (_: IllegalStateException) {
            // Device may already have ended capture.
        }
        try { recordingThread?.join(1500) } catch (_: InterruptedException) { Thread.currentThread().interrupt() }
        try { audioRecord?.release() } catch (_: Exception) { }
        recorder = null
        recordingThread = null
        val pcm = synchronized(captureLock) { capturedPcm.toByteArray() }
        if (pcm.isEmpty()) return ByteArray(0)
        val wav = ByteArrayOutputStream(44 + pcm.size)
        wav.write("RIFF".toByteArray(Charsets.US_ASCII))
        writeIntLE(wav, 36 + pcm.size)
        wav.write("WAVEfmt ".toByteArray(Charsets.US_ASCII))
        writeIntLE(wav, 16)
        writeShortLE(wav, 1)
        writeShortLE(wav, 1)
        writeIntLE(wav, sampleRate)
        writeIntLE(wav, sampleRate * 2)
        writeShortLE(wav, 2)
        writeShortLE(wav, 16)
        wav.write("data".toByteArray(Charsets.US_ASCII))
        writeIntLE(wav, pcm.size)
        wav.write(pcm)
        return wav.toByteArray()
    }

    private fun writeIntLE(out: ByteArrayOutputStream, value: Int) {
        out.write(value and 0xff)
        out.write((value shr 8) and 0xff)
        out.write((value shr 16) and 0xff)
        out.write((value shr 24) and 0xff)
    }

    private fun writeShortLE(out: ByteArrayOutputStream, value: Int) {
        out.write(value and 0xff)
        out.write((value shr 8) and 0xff)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4101) {
            microphoneResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            microphoneResult = null
        }
    }

    override fun onDestroy() {
        stopAndReleaseRecorder()
        super.onDestroy()
    }
}
