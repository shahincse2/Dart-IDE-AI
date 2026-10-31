package com.algorisesoft.dartide

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var importChannel: ImportChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        DownloadsChannel(applicationContext, messenger)
        importChannel = ImportChannel(this, messenger)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = importChannel?.onActivityResult(requestCode, resultCode, data) == true
        if (!handled) super.onActivityResult(requestCode, resultCode, data)
    }
}
