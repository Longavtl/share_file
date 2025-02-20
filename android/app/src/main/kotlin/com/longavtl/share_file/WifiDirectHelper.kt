package com.longavtl.share_file

import android.content.Context
import android.net.wifi.p2p.WifiP2pManager
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

class WifiDirectHelper(private val context: Context) : MethodCallHandler {
    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null

    init {
        manager = context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
        channel = manager?.initialize(context, context.mainLooper, null)
    }

    companion object {
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "wifi_direct")
            val instance = WifiDirectHelper(registrar.context())
            channel.setMethodCallHandler(instance)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "discoverPeers" -> discoverPeers(result)
            else -> result.notImplemented()
        }
    }

    fun discoverPeers(result: Result) {
        manager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d("WiFiDirect", "Tìm thiết bị thành công.")
                manager?.requestPeers(channel) { peers ->
                    val deviceNames = peers.deviceList.map { it.deviceName }
                    result.success(deviceNames)
                }
            }

            override fun onFailure(reason: Int) {
                Log.e("WiFiDirect", "Tìm thiết bị thất bại: $reason")
                result.error("DISCOVERY_FAILED", "Không thể tìm thiết bị", null)
            }
        })
    }
}