import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WifiDirectScreen(),
    );
  }
}

class WifiDirectScreen extends StatefulWidget {
  const WifiDirectScreen({super.key});

  @override
  State<WifiDirectScreen> createState() => _WifiDirectScreenState();
}

class _WifiDirectScreenState extends State<WifiDirectScreen> {
  static const platform = MethodChannel("wifi_direct");
  List<String> devices = [];

  /// 📌 Kiểm tra và yêu cầu quyền trước khi tìm kiếm thiết bị
  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.nearbyWifiDevices,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // ✅ Kiểm tra tất cả quyền đã được cấp
    return statuses.values.every((status) => status.isGranted);
  }

  /// 🔍 Tìm kiếm thiết bị sau khi đảm bảo có quyền
  Future<void> discoverPeers() async {
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Bạn cần cấp đủ quyền để tiếp tục.")),
      );
      return;
    }

    try {
      final List<dynamic> result = await platform.invokeMethod("discoverPeers");
      setState(() {
        devices = result.cast<String>();
      });
    } on PlatformException catch (e) {
      print("⚡ Lỗi: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚡ Lỗi: ${e.message}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WiFi Direct (Kotlin)")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: discoverPeers,
            child: const Text("🔍 Tìm thiết bị"),
          ),
          Expanded(
            child: devices.isEmpty
                ? const Center(child: Text("⚡ Chưa tìm thấy thiết bị nào."))
                : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(devices[index]),
                onTap: () =>
                    print("⚡ Kết nối đến: ${devices[index]}"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
