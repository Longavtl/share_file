package com.longavtl.share_file

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "wifi_direct"
    private lateinit var wifiDirectHelper: WifiDirectHelper

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wifiDirectHelper = WifiDirectHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverPeers" -> {
                    wifiDirectHelper.discoverPeers(result)
                }
                else -> result.notImplemented()
            }
        }
    }
}