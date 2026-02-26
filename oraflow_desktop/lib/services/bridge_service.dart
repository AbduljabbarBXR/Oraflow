import 'dart:io';
import 'dart:convert';
import 'dart:async';

class BridgeService {
  HttpServer? _server;
  List<WebSocket> _clients = [];
  bool _isRunning = false;
  final StreamController<Map<String, dynamic>> _confirmationController = StreamController<Map<String, dynamic>>.broadcast();

  bool get isRunning => _isRunning;
  Stream<Map<String, dynamic>> get confirmationStream => _confirmationController.stream;

  Future<void> startServer() async {
    if (_isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 6543);
      print('OraFlow WebSocket server started on ws://localhost:6543');

      _server!.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(request).then((WebSocket socket) {
          _clients.add(socket);
          print('Client connected. Total clients: ${_clients.length}');

          socket.listen(
            (data) {
              try {
                final message = jsonDecode(data as String) as Map<String, dynamic>;
                print('Received from VS Code: $message');

                // Handle fix confirmation
                if (message['type'] == 'fix_applied_confirmation') {
                  print('🎯 VS Code confirmed fix application!');
                  _confirmationController.add(message);
                }
              } catch (e) {
                print('Failed to parse message from VS Code: $e');
              }
            },
            onDone: () {
              _clients.remove(socket);
              print('Client disconnected. Total clients: ${_clients.length}');
            },
            onError: (error) {
              _clients.remove(socket);
              print('Client error: $error');
            },
          );
        });
      });

      _isRunning = true;
    } catch (e) {
      print('Failed to start WebSocket server: $e');
      rethrow;
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    for (var client in _clients) {
      await client.close();
    }
    _clients.clear();

    await _server?.close();
    _server = null;
    _isRunning = false;
    print('OraFlow WebSocket server stopped');
  }

  void sendMessage(Map<String, dynamic> data) {
    if (!_isRunning || _clients.isEmpty) return;

    final message = jsonEncode(data);
    for (var client in _clients) {
      client.add(message);
    }
    print('Broadcasted message to ${_clients.length} clients: $message');
  }

  void sendPing() {
    sendMessage({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  void dispose() {
    _confirmationController.close();
  }
}
