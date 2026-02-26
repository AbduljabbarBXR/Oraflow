import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class AndroidBridgeService {
  HttpServer? _server;
  bool _isRunning = false;
  final StreamController<Map<String, dynamic>> _errorController = StreamController<Map<String, dynamic>>.broadcast();

  bool get isRunning => _isRunning;
  Stream<Map<String, dynamic>> get androidErrorStream => _errorController.stream;

  Future<void> startServer() async {
    if (_isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 6544);
      print('Android Bridge WebSocket server started on ws://localhost:6544');

      _server!.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(request).then((WebSocket socket) {
          print('Android Bridge client connected');

          socket.listen(
            (data) {
              try {
                final message = jsonDecode(data as String) as Map<String, dynamic>;
                print('Received from ADB Bridge: ${message['type']} - ${message['message']?.substring(0, math.min(50, message['message']?.length as int? ?? 0))}');

                // Handle different message types
                if (message['type'] == 'android_error') {
                  _errorController.add(message);
                } else if (message['type'] == 'adb_bridge_status') {
                  print('ADB Bridge status: ${message['status']} - ${message['message']}');
                } else if (message['type'] == 'adb_monitoring_status') {
                  print('ADB Monitoring status: ${message['status']} - ${message['message']}');
                }
              } catch (e) {
                print('Failed to parse message from ADB Bridge: $e');
              }
            },
            onDone: () {
              print('Android Bridge client disconnected');
            },
            onError: (error) {
              print('Android Bridge client error: $error');
            },
          );

          // Send connection confirmation
          socket.add(jsonEncode({
            'type': 'connection_ack',
            'status': 'connected',
            'message': 'OraFlow Desktop connected to ADB Bridge'
          }));
        });
      });

      _isRunning = true;
    } catch (e) {
      print('Failed to start Android Bridge server: $e');
      rethrow;
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    await _server?.close();
    _server = null;
    _isRunning = false;
    print('Android Bridge WebSocket server stopped');
  }

  void dispose() {
    stopServer();
    _errorController.close();
  }
}
