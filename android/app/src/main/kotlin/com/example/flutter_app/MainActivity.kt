package com.example.flutter_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val ASSET_CHANNEL = "com.example.flutter_app/asset_copy"
    private val VLM_CHANNEL = "com.example.flutter_app/vlm"
    private lateinit var vlmChannel: MethodChannel

    external fun initVLM(modelPath: String, mmprojPath: String)
    external fun prepareImageVLM(imagePath: String)
    external fun runVLM(prompt: String, imagePath: String): String

    init {
        try {
            System.loadLibrary("fluttervlm")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSET_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "copyAsset") {
                val assetName = call.argument<String>("assetName")
                val destPath = call.argument<String>("destPath")

                if (assetName == null || destPath == null) {
                    result.error("INVALID_ARGS", "assetName and destPath are required", null)
                    return@setMethodCallHandler
                }

                Thread {
                    try {
                        val assetManager = assets
                        val inputStream = assetManager.open(assetName)
                        val destFile = File(destPath)
                        destFile.parentFile?.mkdirs()
                        val outputStream = FileOutputStream(destFile)

                        val buffer = ByteArray(8192) // 8KB buffer — never holds 1GB in memory
                        var bytesRead: Int
                        var totalBytes: Long = 0

                        while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                            outputStream.write(buffer, 0, bytesRead)
                            totalBytes += bytesRead
                        }

                        outputStream.flush()
                        outputStream.close()
                        inputStream.close()

                        runOnUiThread {
                            result.success(totalBytes)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("COPY_FAILED", e.message, e.stackTraceToString())
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }

        vlmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VLM_CHANNEL)
        vlmChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initVLM" -> {
                    val modelPath = call.argument<String>("modelPath") ?: ""
                    val mmprojPath = call.argument<String>("mmprojPath") ?: ""
                    Thread {
                        try {
                            initVLM(modelPath, mmprojPath)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("VLM_INIT_ERR", e.message, null) }
                        }
                    }.start()
                }
                "prepareImageVLM" -> {
                    val imagePath = call.argument<String>("imagePath") ?: ""
                    Thread {
                        try {
                            prepareImageVLM(imagePath)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("VLM_PREPARE_ERR", e.message, null) }
                        }
                    }.start()
                }
                "runVLM" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val imagePath = call.argument<String>("imagePath") ?: ""
                    Thread {
                        try {
                            val response = runVLM(prompt, imagePath)
                            runOnUiThread { result.success(response) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("VLM_RUN_ERR", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    // Called periodically from C++ JNI during Generation
    fun onTokenGenerated(token: String) {
        runOnUiThread {
            vlmChannel.invokeMethod("onToken", token)
        }
    }
}
