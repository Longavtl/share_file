package com.longavtl.share_file

import android.content.Context
import android.location.LocationManager
import android.net.wifi.p2p.WifiP2pManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WifiDirectHelper(private val context: Context) : MethodChannel.MethodCallHandler {
    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null

    init {
        manager = context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
        channel = manager?.initialize(context, context.mainLooper, null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "discoverPeers" -> discoverPeers(result)
            else -> result.notImplemented()
        }
    }

    fun discoverPeers(result: MethodChannel.Result) {
        if (!isLocationEnabled()) {
            result.error("LOCATION_DISABLED", "📍 Vui lòng bật vị trí (GPS) để tiếp tục.", null)
            return
        }

        if (manager == null || channel == null) {
            result.error("INITIALIZATION_FAILED", "⚠️ WifiP2pManager chưa được khởi tạo.", null)
            return
        }

        // Reset tìm kiếm trước đó
        manager?.stopPeerDiscovery(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d("WiFiDirect", "🔄 Reset tìm kiếm thành công.")
                startDiscovery(result)
            }

            override fun onFailure(reason: Int) {
                Log.e("WiFiDirect", "❌ Không thể reset tìm kiếm: $reason")
                startDiscovery(result)
            }
        })
    }

    private fun startDiscovery(result: MethodChannel.Result) {
        manager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d("WiFiDirect", "🟢 Đang tìm kiếm thiết bị...")
                Handler(Looper.getMainLooper()).postDelayed({
                    manager?.requestPeers(channel) { peers ->
                        val deviceNames = peers.deviceList.map { it.deviceName }
                        Log.d("WiFiDirect", "🔍 Thiết bị tìm thấy: $deviceNames")
                        result.success(deviceNames)
                    }
                }, 2000)
            }

            override fun onFailure(reason: Int) {
                Log.e("WiFiDirect", "🔴 Tìm thiết bị thất bại: $reason")
                val errorMessage = when (reason) {
                    WifiP2pManager.P2P_UNSUPPORTED -> "Thiết bị không hỗ trợ Wi-Fi Direct"
                    WifiP2pManager.BUSY -> "Hệ thống bận, thử lại sau"
                    WifiP2pManager.ERROR -> "Lỗi không xác định (ERROR 0). Thử khởi động lại thiết bị."
                    else -> "Lỗi không rõ: $reason"
                }
                result.error("DISCOVERY_FAILED", errorMessage, null)
            }
        })
    }

    private fun isLocationEnabled(): Boolean {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
}
