import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wi-Fi Direct',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WifiDirectScreen(),
    );
  }
}

class WifiDirectScreen extends StatefulWidget {
  const WifiDirectScreen({super.key});

  @override
  _WifiDirectScreenState createState() => _WifiDirectScreenState();
}

class _WifiDirectScreenState extends State<WifiDirectScreen> {
  static const platform = MethodChannel("wifi_direct");
  List<String> devices = [];
  String? connectedDevice;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.storage.request();
  }

  Future<void> discoverDevices() async {
    try {
      final List<Object?> result = await platform.invokeMethod("discoverDevices");
      setState(() {
        devices = result.map((e) => e.toString()).toList();
      });
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }

  Future<void> connectToDevice(String device) async {
    try {
      final bool success = await platform.invokeMethod("connectToDevice", {"device": device});
      if (success) {
        setState(() {
          connectedDevice = device;
        });
      }
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }


  Future<void> sendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String filePath = result.files.single.path!;
      try {
        await platform.invokeMethod("sendFile", {"filePath": filePath});
      } on PlatformException catch (e) {
        print("Error: ${e.message}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wi-Fi Direct File Transfer")),
      body: Column(
        children: [
          ElevatedButton(onPressed: discoverDevices, child: const Text("Tìm thiết bị")),
          if (devices.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(devices[index]),
                    trailing: ElevatedButton(
                      onPressed: () => connectToDevice(devices[index]),
                      child: const Text("Kết nối"),
                    ),
                  );
                },
              ),
            ),
          if (connectedDevice != null)
            Column(
              children: [
                Text("Đã kết nối với: $connectedDevice"),
                ElevatedButton(onPressed: sendFile, child: const Text("Gửi File"))
              ],
            ),
        ],
      ),
    );
  }
}
