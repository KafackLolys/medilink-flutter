import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../api/medilink_api.dart';
import '../config/app_environment.dart';

class MessagingSocketService {
  MessagingSocketService._();
  static final MessagingSocketService instance = MessagingSocketService._();
  IO.Socket? _socket;
  String? _connectedToken;
  bool get isConnected => _socket?.connected ?? false;
  IO.Socket? get socket => _socket;

  Future<void> connect() async {
    final token = MedilinkApi.instance.idToken;
    final baseUrl = AppEnvironment.apiBaseUrl.trim();
    if (token == null || token.isEmpty || baseUrl.isEmpty) return;
    if (_socket != null && _connectedToken == token) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }
    await disconnect();
    _connectedToken = token;
    final socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(1000)
      .setReconnectionDelayMax(10000)
      .build());
    _socket = socket;
    socket.connect();
  }

  void joinConversation(String id) {
    if (isConnected) _socket!.emit('conversation:join', {'conversationId': id});
  }
  void leaveConversation(String id) {
    _socket?.emit('conversation:leave', {'conversationId': id});
  }
  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
  }
}
