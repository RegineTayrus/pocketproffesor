package com.pocketprofessor.pocket_professor

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocket_professor/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeSpaceBytes" -> {
                        try {
                            val stat = StatFs(Environment.getDataDirectory().path)
                            result.success(stat.availableBytes)
                        } catch (e: Exception) {
                            result.error("storage_error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
