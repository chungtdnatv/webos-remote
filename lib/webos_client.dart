import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// webOS SSAP transport. Never bypasses TLS certificate validation.
class WebOsClient {
  WebSocket? _socket;
  String? _host;
  StreamSubscription<dynamic>? _subscription;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final events = StreamController<Map<String, dynamic>>.broadcast();
  final _registrations = <String>{};
  int _sequence = 0;
  bool get connected => _socket != null;

  Future<String> connect(String host, {String? key, bool secure = false}) async {
    await disconnect();
    if (InternetAddress.tryParse(host)?.type != InternetAddressType.IPv4) {
      throw ArgumentError('Nhập địa chỉ IPv4 của TV, ví dụ 192.168.1.20');
    }
    final socket = await WebSocket.connect(
      '${secure ? 'wss' : 'ws'}://$host:${secure ? 3001 : 3000}',
    ).timeout(const Duration(seconds: 8));
    _socket = socket;
    _host = host;
    _subscription = socket.listen(_receive, onError: (Object error) {
      _fail(error);
    }, onDone: () => _fail(StateError('TV đã ngắt kết nối')));
    final response = await _send('register', {
      'pairingType': 'PROMPT',
      if (key != null) 'client-key': key,
      'manifest': {
        'manifestVersion': 1,
        'appVersion': '1.0',
        'permissions': [
          'CONTROL_AUDIO', 'CONTROL_INPUT_MEDIA_PLAYBACK',
          'CONTROL_POWER', 'READ_CURRENT_CHANNEL', 'READ_RUNNING_APPS',
          'READ_INSTALLED_APPS', 'CONTROL_INPUT_TV', 'CONTROL_MOUSE_AND_KEYBOARD',
          'LAUNCH', 'LAUNCH_WEBAPP',
        ],
      },
    }, timeout: const Duration(seconds: 60));
    final savedKey = response['client-key'];
    if (savedKey is! String || savedKey.isEmpty) {
      await disconnect();
      throw StateError('TV không trả về khóa ghép đôi');
    }
    return savedKey;
  }

  void _receive(dynamic raw) {
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      events.add(message);
      final id = message['id'];
      final pending = _pending[id];
      if (pending == null) return;
      final payload = Map<String, dynamic>.from(message['payload'] as Map? ?? {});
      if (message['type'] == 'error') {
        _pending.remove(id)?.completeError(StateError('${message['error']}'));
      } else if (message['type'] == 'registered' ||
          (message['type'] == 'response' && !_registrations.contains(id))) {
        _pending.remove(id)?.complete(payload);
      }
    } catch (error) {
      _fail(FormatException('Phản hồi TV không hợp lệ: $error'));
    }
  }

  Future<Map<String, dynamic>> _send(String type, Map<String, dynamic> payload,
      {String? uri, Duration timeout = const Duration(seconds: 8)}) async {
    final socket = _socket;
    if (socket == null) throw StateError('Chưa kết nối TV');
    final id = 'remote_${++_sequence}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    if (type == 'register') _registrations.add(id);
    try {
      socket.add(jsonEncode({'id': id, 'type': type,
        if (uri != null) 'uri': uri, 'payload': payload}));
      return await completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
      _registrations.remove(id);
    }
  }

  Future<Map<String, dynamic>> request(String uri,
      [Map<String, dynamic> payload = const {}]) =>
      _send('request', payload, uri: 'ssap://$uri');

  Future<void> button(String name) async {
    const allowed = {'UP', 'DOWN', 'LEFT', 'RIGHT', 'ENTER', 'BACK', 'HOME', 'MENU'};
    if (!allowed.contains(name)) throw ArgumentError('Phím không hợp lệ');
    final response = await request('com.webos.service.networkinput/getPointerInputSocket');
    final path = Uri.parse(response['socketPath'] as String);
    // Only connect back to the paired TV; reject arbitrary socket destinations.
    if (path.host != _host || !{'ws', 'wss'}.contains(path.scheme)) {
      throw StateError('Địa chỉ điều khiển không thuộc TV đã ghép đôi');
    }
    final pointer = await WebSocket.connect(path.toString())
        .timeout(const Duration(seconds: 8));
    try {
      pointer.add('type:button\nname:$name\n\n');
      await pointer.close();
    } finally {
      await pointer.close();
    }
  }

  void _fail(Object error) {
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
    events.add({'type': 'disconnected', 'error': error.toString()});
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
    _fail(StateError('Đã ngắt kết nối'));
  }
}
