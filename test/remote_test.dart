import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webos_remote/main.dart';
import 'package:webos_remote/webos_client.dart';

void main() {
  testWidgets('remote requires pairing before controls are enabled', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RemoteApp());
    await tester.pumpAndSettle();
    expect(find.text('Kết nối / Ghép đôi'), findsOneWidget);
    final ok = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK'));
    expect(ok.onPressed, isNull);
  });

  test('SSAP registration waits for approval, then sends volume and errors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
    final sockets = <WebSocket>[];
    final requests = <String>[];
    final subscription = server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      sockets.add(ws);
      ws.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        final id = data['id'];
        if (data['type'] == 'register') {
          ws.add(jsonEncode({'id': id, 'type': 'response', 'payload': {'pairingType': 'PROMPT'}}));
          ws.add(jsonEncode({'id': id, 'type': 'registered', 'payload': {'client-key': 'test-key'}}));
        } else {
          requests.add(data['uri'] as String);
          ws.add(jsonEncode(data['uri'] == 'ssap://invalid'
              ? {'id': id, 'type': 'error', 'error': '404 no such service'}
              : {'id': id, 'type': 'response', 'payload': {'returnValue': true}}));
        }
      });
    });
    final client = WebOsClient();
    try {
      expect(await client.connect('127.0.0.1'), 'test-key');
      await client.request('audio/volumeUp');
      expect(requests, contains('ssap://audio/volumeUp'));
      await expectLater(client.request('invalid'), throwsStateError);
      await client.disconnect();
      expect(client.connected, isFalse);
    } finally {
      await client.disconnect();
      for (final socket in sockets) { await socket.close(); }
      await subscription.cancel();
      await server.close(force: true);
      await client.events.close();
    }
  });
}
