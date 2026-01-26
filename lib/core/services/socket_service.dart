import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;

  void connect(Function(dynamic) onNotification) {
    socket = IO.io(
      'http://197.239.116.77:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('🟢 Socket connecté');
    });

    socket.on('new-notification', (data) {
      onNotification(data);
    });

    socket.onDisconnect((_) {
      print('🔴 Socket déconnecté');
    });
  }
}
