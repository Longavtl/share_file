import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  String currentPath = "/storage/emulated/0";
  List<FileSystemEntity> files = [];
  String? copiedFilePath;
  bool isMoveOperation = false;

  @override
  void initState() {
    super.initState();
    requestStoragePermission(context);
  }

  Future<void> requestStoragePermission(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) {
      _listFiles(currentPath);
    } else {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        _listFiles(currentPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚡ Quyền truy cập bộ nhớ bị từ chối.")),
        );
      }
    }
  }

  Future<void> _listFiles(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      var items = dir.listSync().where((item) {
        return !p.basename(item.path).startsWith('.');
      }).toList();

      items.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      setState(() {
        currentPath = path;
        files = items;
        copiedFilePath = null;
      });
    }
  }

  bool _isRootPath() => currentPath == "/storage/emulated/0";

  /// ✅ Hàm sinh tên file mới nếu bị trùng, thêm (1), (2), ...
  String _getUniqueFilePath(String destinationPath) {
    if (!File(destinationPath).existsSync() && !Directory(destinationPath).existsSync()) {
      return destinationPath;
    }
    String dir = p.dirname(destinationPath);
    String baseName = p.basenameWithoutExtension(destinationPath);
    String ext = p.extension(destinationPath);

    int count = 1;
    String newPath;
    do {
      newPath = p.join(dir, "$baseName($count)$ext");
      count++;
    } while (File(newPath).existsSync() || Directory(newPath).existsSync());
    return newPath;
  }

  Future<void> _renameFile(String oldPath) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(oldPath));
    final ext = p.extension(oldPath);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("✏️ Sửa tên file"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim() + ext;
              final newPath = p.join(p.dirname(oldPath), newName);
              if (newName.isNotEmpty) {
                await File(oldPath).rename(newPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ Đã đổi tên thành $newName")),
                );
                _listFiles(currentPath);
                Navigator.pop(context);
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (entity == FileSystemEntityType.file) {
      await File(path).delete();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑 Đã xóa thành công")),
    );
    _listFiles(currentPath);
  }

  Future<void> _copyOrMoveFile(String filePath, {bool isMove = false}) async {
    setState(() {
      copiedFilePath = filePath;
      isMoveOperation = isMove;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isMove ? "📦 Đã chọn để di chuyển" : "📁 File đã được sao chép")),
    );
  }

  Future<void> _pasteFile() async {
    if (copiedFilePath == null) return;
    final fileName = p.basename(copiedFilePath!);
    String destinationPath = p.join(currentPath, fileName);
    destinationPath = _getUniqueFilePath(destinationPath); // ✅ Kiểm tra trùng tên

    try {
      final entityType = FileSystemEntity.typeSync(copiedFilePath!);
      if (entityType == FileSystemEntityType.file) {
        await File(copiedFilePath!).copy(destinationPath);
        if (isMoveOperation) await File(copiedFilePath!).delete();
      } else if (entityType == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(copiedFilePath!), Directory(destinationPath));
        if (isMoveOperation) await Directory(copiedFilePath!).delete(recursive: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isMoveOperation ? "📦 Đã di chuyển thành: ${p.basename(destinationPath)}" : "✅ Đã dán: ${p.basename(destinationPath)}")),
      );
      _listFiles(currentPath);
      copiedFilePath = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚡ Lỗi: $e")),
      );
    }
  }

  /// ✅ Hàm sao chép thư mục và nội dung
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) destination.createSync();
    for (var entity in source.listSync(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(p.join(destination.path, p.basename(entity.path)));
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  Future<void> _createNewFileOrFolder() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("📝 Thêm file hoặc thư mục"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Tên file hoặc thư mục")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newPath = p.join(currentPath, name);
                final uniquePath = _getUniqueFilePath(newPath);
                if (p.extension(name).isEmpty) {
                  await Directory(uniquePath).create();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("📂 Thư mục '${p.basename(uniquePath)}' đã tạo.")),
                  );
                } else {
                  await File(uniquePath).create();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("📄 File '${p.basename(uniquePath)}' đã tạo.")),
                  );
                }
                _listFiles(currentPath);
                Navigator.pop(context);
              }
            },
            child: const Text("Tạo"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📂 Trình duyệt File"),
        actions: [
          if (!_isRootPath() && copiedFilePath != null)
            IconButton(
              onPressed: _pasteFile,
              icon: const Icon(Icons.paste),
              tooltip: "📤 Dán file",
            ),
          if (!_isRootPath())
            IconButton(
              onPressed: _createNewFileOrFolder,
              icon: const Icon(Icons.add),
              tooltip: "📝 Tạo file/thư mục",
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isRootPath())
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text("⬅ Quay lại"),
              onTap: () => _listFiles(p.dirname(currentPath)),
            ),
          Expanded(
            child: files.isEmpty
                ? const Center(child: Text("📭 Thư mục rỗng."))
                : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final entity = files[index];
                final isDir = FileSystemEntity.isDirectorySync(entity.path);
                final fileName = p.basename(entity.path);
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file, color: isDir ? Colors.amber : Colors.blue),
                  title: Text(fileName),
                  trailing: (!_isRootPath())
                      ? PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _renameFile(entity.path);
                          break;
                        case 'delete':
                          _deleteFile(entity.path);
                          break;
                        case 'copy':
                          _copyOrMoveFile(entity.path);
                          break;
                        case 'move':
                          _copyOrMoveFile(entity.path, isMove: true);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text("✏ Sửa tên")),
                      const PopupMenuItem(value: 'delete', child: Text("🗑 Xóa")),
                      const PopupMenuItem(value: 'copy', child: Text("📁 Sao chép")),
                      const PopupMenuItem(value: 'move', child: Text("📦 Di chuyển")),
                    ],
                  )
                      : null,
                  onTap: () => isDir ? _listFiles(entity.path) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
