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

        // Khởi động server tự động khi ứng dụng chạy
        Thread { startServer() }.start()

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
                wifiP2pManager.requestConnectionInfo(channel) { info ->
                    if (info.groupOwnerAddress != null) {
                        groupOwnerAddress = info.groupOwnerAddress
                        Log.d("WiFiDirect", "Địa chỉ IP thiết bị nhận: $groupOwnerAddress")
                        result.success(true)
                    } else {
                        result.error("ERROR", "Không lấy được địa chỉ IP", null)
                    }
                }
            }

            override fun onFailure(reason: Int) {
                result.error("ERROR", "Không thể kết nối đến thiết bị", null)
            }
        })
    }

    private fun sendFile(filePath: String, result: MethodChannel.Result) {
        if (groupOwnerAddress == null) {
            result.error("ERROR", "Không có địa chỉ IP của thiết bị nhận", null)
            return
        }

        Thread {
            try {
                val socket = Socket(groupOwnerAddress, 8889)
                val file = File(filePath)
                val fileSize = file.length()

                Log.d("WiFiDirect", "Gửi file: ${file.name} có kích thước $fileSize bytes")

                DataOutputStream(socket.getOutputStream()).use { outputStream ->
                    outputStream.writeUTF(file.name)
                    outputStream.writeLong(fileSize)

                    file.inputStream().use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }

                socket.close()
                result.success("File sent successfully")
            } catch (e: Exception) {
                Log.e("WiFiDirect", "Lỗi khi gửi file", e)
                result.error("ERROR", "File transfer failed: ${e.message}", null)
            }
        }.start()
    }

    private fun startServer() {
        try {
            val serverSocket = ServerSocket(8889)
            Log.d("WiFiDirect", "Máy nhận đang chờ file...")

            while (true) {
                val clientSocket = serverSocket.accept()
                Thread {
                    try {
                        val inputStream = DataInputStream(clientSocket.getInputStream())

                        val fileName = inputStream.readUTF()
                        val fileSize = inputStream.readLong()
                        val file = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), fileName)

                        Log.d("WiFiDirect", "Nhận file: $fileName ($fileSize bytes)")

                        file.outputStream().use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }

                        Log.d("WiFiDirect", "File nhận thành công: ${file.absolutePath}")
                        clientSocket.close()
                    } catch (e: Exception) {
                        Log.e("WiFiDirect", "Lỗi khi nhận file", e)
                    }
                }.start()
            }
        } catch (e: Exception) {
            Log.e("WiFiDirect", "Lỗi khi khởi động server", e)
        }
    }

    private fun checkPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.WRITE_EXTERNAL_STORAGE),
            1
        )
    }
}
