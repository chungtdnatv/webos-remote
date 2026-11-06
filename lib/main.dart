import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'webos_client.dart';

void main() => runApp(const RemoteApp());

class RemoteApp extends StatelessWidget {
  const RemoteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LG Wi-Fi Remote',
    theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark,
      useMaterial3: true),
    home: const RemotePage(),
  );
}

class RemotePage extends StatefulWidget {
  const RemotePage({super.key});
  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  final client = WebOsClient();
  final host = TextEditingController();
  final media = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? subscription;
  String status = 'Nhập IP trong Cài đặt TV → Mạng → Kết nối Wi-Fi';
  bool busy = false;
  bool paired = false;
  bool secure = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) host.text = prefs.getString('last_tv') ?? '';
    });
    subscription = client.events.stream.listen((event) {
      if (mounted && event['type'] == 'disconnected') {
        setState(() { paired = false; status = '${event['error']}'; });
      }
    });
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => status = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect() async {
    final ip = host.text.trim();
    final prefs = await SharedPreferences.getInstance();
    setState(() => status = 'Đang kết nối… Hãy chọn CHẤP NHẬN trên TV.');
    try {
      final key = await client.connect(ip,
        key: prefs.getString('key_$ip'), secure: secure);
      await prefs.setString('key_$ip', key);
      await prefs.setString('last_tv', ip);
      if (mounted) setState(() { paired = true; status = 'Đã kết nối $ip'; });
    } catch (_) {
      await client.disconnect();
      rethrow;
    }
  }

  Widget command(String label, IconData icon, Future<void> Function() action) =>
    FilledButton.tonalIcon(onPressed: paired && !busy ? () => run(action) : null,
      icon: Icon(icon), label: Text(label));

  Future<void> request(String uri, [Map<String, dynamic> payload = const {}]) async {
    await client.request(uri, payload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LG Wi-Fi Remote')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: host, enabled: !paired && !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Địa chỉ IPv4 của TV',
            hintText: '192.168.1.20', border: OutlineInputBorder())),
        SwitchListTile(title: const Text('TLS — cổng 3001'),
          subtitle: const Text('Cần chứng chỉ TV được hệ điều hành tin cậy. Mặc định dùng cổng 3000 trong LAN.'),
          value: secure, onChanged: paired || busy ? null : (v) => setState(() => secure = v)),
        FilledButton(onPressed: busy ? null : () => run(paired ? client.disconnect : connect),
          child: Text(paired ? 'Ngắt kết nối' : 'Kết nối / Ghép đôi')),
        if (busy) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(status)),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          command('Tắt TV', Icons.power_settings_new, () async {
            final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('Tắt TV?'), content: const Text('Bạn cần bật lại TV bằng điều khiển vật lý.'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tắt'))]));
            if (confirmed == true) await request('system/turnOff');
          }),
          command('Home', Icons.home, () => client.button('HOME')),
          command('Quay lại', Icons.arrow_back, () => client.button('BACK')),
        ]),
        const SizedBox(height: 22),
        Center(child: command('Lên', Icons.arrow_upward, () => client.button('UP'))),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
          command('Trái', Icons.arrow_back, () => client.button('LEFT')),
          command('OK', Icons.check, () => client.button('ENTER')),
          command('Phải', Icons.arrow_forward, () => client.button('RIGHT')),
        ]),
        const SizedBox(height: 10),
        Center(child: command('Xuống', Icons.arrow_downward, () => client.button('DOWN'))),
        const SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          command('Âm −', Icons.volume_down, () => request('audio/volumeDown')),
          command('Âm +', Icons.volume_up, () => request('audio/volumeUp')),
          command('Tắt tiếng', Icons.volume_off, () => request('audio/setMute', {'mute': true})),
          command('Bật tiếng', Icons.volume_up, () => request('audio/setMute', {'mute': false})),
          command('Kênh −', Icons.remove, () => request('tv/channelDown')),
          command('Kênh +', Icons.add, () => request('tv/channelUp')),
          command('Phát', Icons.play_arrow, () => request('media.controls/play')),
          command('Tạm dừng', Icons.pause, () => request('media.controls/pause')),
          command('Dừng', Icons.stop, () => request('media.controls/stop')),
        ]),
        const SizedBox(height: 24),
        TextField(controller: media, decoration: const InputDecoration(
          labelText: 'URL video MP4 mà TV truy cập được', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        command('Mở video trên TV', Icons.cast, () async {
          final uri = Uri.tryParse(media.text.trim());
          if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
            throw ArgumentError('Cần URL http hoặc https hợp lệ');
          }
          await request('media.viewer/open', {'target': uri.toString(), 'mimeType': 'video/mp4'});
        }),
        const SizedBox(height: 16),
        TextButton(onPressed: busy ? null : () => run(() async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('key_${host.text.trim()}');
          await client.disconnect();
          if (mounted) setState(() => status = 'Đã quên khóa. Kết nối lại để ghép đôi.');
        }), child: const Text('Quên khóa ghép đôi')),
        const Text('TV và thiết bị điều khiển phải cùng mạng LAN/Wi-Fi, không dùng mạng khách cách ly. '
          'Bật LG Connect Apps / Mobile TV On trong cài đặt TV nếu có. '
          'Không mở cổng 3000/3001 ra Internet.'),
      ]))),
  );

  @override
  void dispose() {
    subscription?.cancel();
    unawaited(client.disconnect());
    host.dispose();
    media.dispose();
    super.dispose();
  }
}
