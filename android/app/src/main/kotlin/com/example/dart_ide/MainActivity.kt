package com.example.dart_ide

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DownloadsChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}







//package com.example.dart_ide
//
//import io.flutter.embedding.android.FlutterActivity
//
//class MainActivity : FlutterActivity()
