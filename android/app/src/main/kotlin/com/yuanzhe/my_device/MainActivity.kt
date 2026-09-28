package com.yuanzhe.my_device

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    /** The bridge to Android AICore; see [GenAiChannel]. */
    private val genAi = GenAiChannel(this)

    /**
     * Purpose: Register the share and on-device AI channels for the Flutter engine.
     * Inputs: `flutterEngine`.
     * Returns: None.
     * Side effects: Installs the `com.yuanzhe.my_device/share` and
     * `com.yuanzhe.my_device/genai` method-channel handlers.
     * Notes: [GenAiChannel] creates no AICore client here; see its own note on why.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        genAi.attach(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yuanzhe.my_device/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareFile") {
                    val path = call.argument<String>("path")!!
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        File(path)
                    )
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    val chooser = Intent.createChooser(shareIntent, null).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(chooser)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Purpose: Release the AICore client when the activity goes away.
     * Inputs: None.
     * Returns: None.
     * Side effects: Closes the on-device model session and cancels any request.
     * Notes: A model left open holds an AICore session, a shared device resource.
     */
    override fun onDestroy() {
        genAi.detach()
        super.onDestroy()
    }
}
