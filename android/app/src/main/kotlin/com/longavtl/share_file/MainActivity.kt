package com.longavtl.share_file
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.p2p.*
import android.net.wifi.p2p.WifiP2pManager.*
import android.os.Bundle
import android.os.Environment
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket

class MainActivity : FlutterActivity() {
    private val CHANNEL = "wifi_direct"
    private lateinit var wifiP2pManager: WifiP2pManager
    private lateinit var channel: WifiP2pManager.Channel
    private var peers = mutableListOf<WifiP2pDevice>()
    private var groupOwnerAddress: InetAddress? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wifiP2pManager = getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
        channel = wifiP2pManager.initialize(this, Looper.getMainLooper(), null)

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverDevices" -> discoverDevices(result)
                "connectToDevice" -> connectToDevice(call.argument("device")!!, result)
                "sendFile" -> sendFile(call.argument("filePath")!!, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun discoverDevices(result: MethodChannel.Result) {
        if (!checkPermissions()) {
            requestPermissions()
            result.error("PERMISSION_DENIED", "Chưa cấp quyền truy cập", null)
            return
        }

        wifiP2pManager.discoverPeers(channel, object : ActionListener {
            override fun onSuccess() {
                wifiP2pManager.requestPeers(channel) { peerList ->
                    peers.clear()
                    peers.addAll(peerList.deviceList)
                    result.success(peers.map { it.deviceName })
                }
            }

            override fun onFailure(reason: Int) {
                result.error("ERROR", "Không tìm thấy thiết bị", null)
            }
        })
    }

    private fun connectToDevice(device: String, result: MethodChannel.Result) {
        val deviceToConnect = peers.find { it.deviceName == device } ?: return
        val config = WifiP2pConfig().apply { deviceAddress = deviceToConnect.deviceAddress }

        wifiP2pManager.connect(channel, config, object : ActionListener {
            override fun onSuccess() {
                Log.d("WiFiDirect", "Kết nối thành công!")

                wifiP2pManager.requestConnectionInfo(channel) { info ->
                    if (info.groupOwnerAddress != null) {
                        groupOwnerAddress = info.groupOwnerAddress
                        Log.d("WiFiDirect", "Địa chỉ IP thiết bị nhận: $groupOwnerAddress")
                        result.success(true)
                    } else {
                        Log.e("WiFiDirect", "Không lấy được địa chỉ IP!")
                        result.error("ERROR", "Không lấy được địa chỉ IP của thiết bị nhận", null)
                    }
                }
            }

            override fun onFailure(reason: Int) {
                Log.e("WiFiDirect", "Kết nối thất bại!")
                result.error("ERROR", "Không thể kết nối đến thiết bị", null)
            }
        })
    }

    private fun sendFile(filePath: String, result: MethodChannel.Result) {
        if (groupOwnerAddress == null) {
            result.error("ERROR", "Không có địa chỉ IP của thiết bị nhận", null)
            return
        }

        Log.d("WiFiDirect", "Bắt đầu gửi file: $filePath đến $groupOwnerAddress")

        Thread {
            try {
                val socket = Socket(groupOwnerAddress, 8888)
                val file = File(filePath)

                file.inputStream().use { inputStream ->
                    socket.getOutputStream().use { outputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }

                socket.close()
                Log.d("WiFiDirect", "Gửi file thành công!")
                result.success("File sent successfully")
            } catch (e: Exception) {
                Log.e("WiFiDirect", "Lỗi khi gửi file", e)
                result.error("ERROR", "File transfer failed: ${e.message}", null)
            }
        }.start()
    }

    private fun checkPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions() {
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 1)
    }
}
