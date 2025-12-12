import 'dart:async';
import 'package:flutter/material.dart';
import 'package:navigation_app/services/ble_service.dart'; // Import the main BLEService

// ==========================================================
// BluetoothSenderScreen - Flutter UI 畫面
// ==========================================================

class BluetoothSenderScreen extends StatefulWidget {
  const BluetoothSenderScreen({super.key});

  @override
  State<BluetoothSenderScreen> createState() => _BluetoothSenderScreenState();
}

class _BluetoothSenderScreenState extends State<BluetoothSenderScreen> {
  final TextEditingController _messageController = TextEditingController(text: "8");
  String _logOutput = "準備發送訊息...\n";
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _logOutput = "開始發送...\n";
    });

    print("=== 開始發送藍牙指令 ===");  // Terminal 輸出
    String messageText = _messageController.text;
    print("嘗試發送指令: $messageText");  // Terminal 輸出

    final bleService = BLEService(); // Get instance of the main BLEService

    if (!bleService.isConnected) {
      setState(() {
        _logOutput = "❌ 設備未連接。請先在 'Bluetooth Devices' 頁面連接設備。";
        _isSending = false;
      });
      print("=== 發送流程結束 (未連接) ===");
      return;
    }

    try {
      int? command = int.tryParse(messageText);
      if (command == null) {
        setState(() {
          _logOutput = "❌ 無效指令：請輸入一個整數 (例如: 0, 1, 2, 3, 4)。";
          _isSending = false;
        });
        print("=== 發送流程結束 (無效指令) ===");
        return;
      }

      await bleService.sendVibrateCommand(command);
      setState(() {
        _logOutput = "✅ 指令 '$command' 發送成功！";
        _isSending = false;
      });
      print("=== 指令發送成功 ===");
    } catch (e) {
      setState(() {
        _logOutput = "❌ 發送指令時發生錯誤: $e";
        _isSending = false;
      });
      print("=== 發送流程結束 (錯誤) ===");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 訊息發送'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 輸入訊息
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: '要發送的訊息',
                border: OutlineInputBorder(),
                hintText: '輸入要發送的訊息',
              ),
            ),
            const SizedBox(height: 16),
            
            // 發送按鈕
            ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: _isSending
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('發送中...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  : const Text('發送訊息', style: TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 24),
            const Text(
              '執行日誌：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // 日誌輸出區域
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _logOutput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}