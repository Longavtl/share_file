import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> discoverPeers() async {
    try {
      final List<dynamic> result = await platform.invokeMethod("discoverPeers");
      setState(() {
        devices = result.cast<String>();
      });
    } on PlatformException catch (e) {
      print("Lỗi: ${e.message}");
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
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(devices[index]),
                onTap: () => print("Kết nối đến: ${devices[index]}"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
