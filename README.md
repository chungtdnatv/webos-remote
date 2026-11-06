# LG Wi-Fi Remote

Ứng dụng Flutter dùng chung mã cho **Android, Windows, macOS và Linux**, điều khiển TV LG webOS 5 bằng SSAP WebSocket qua mạng nội bộ.

## Chức năng

- Nhập IP TV, ghép đôi bằng xác nhận trên TV, nhớ khóa theo từng IP.
- Điều hướng, OK, Home, Back; âm lượng, mute, kênh; play/pause/stop.
- Tắt TV có xác nhận; mở URL video MP4 mà TV truy cập được.
- Hiện lỗi kết nối, từ chối ghép đôi, timeout; quên khóa để ghép đôi lại.

Chưa có tự dò TV, Wake-on-LAN, bàn phím hay danh sách ứng dụng. Bật TV bằng remote vật lý. Khả năng điều khiển media phụ thuộc ứng dụng đang chạy trên TV.

## Chuẩn bị và chạy

Cài Flutter stable (Dart >=3.5), Git, Python 3. Với Android cài Android SDK/JDK theo `flutter doctor`; Windows cần Visual Studio C++ desktop, macOS cần Xcode, Linux cần bộ công cụ GTK theo Flutter doctor. Chạy build desktop trên đúng hệ điều hành đích.

Từ thư mục repository:

```sh
bash scripts/bootstrap.sh
flutter doctor -v
flutter devices
flutter run -d <device-id>
```

Script tạo host project Android/Windows/macOS/Linux chính thức qua `flutter create`, thêm quyền Internet Android và network client macOS, tải dependencies, chạy analyzer và tests. Mã ứng dụng nằm ở `lib/`; host project cần tạo trước lần build đầu tiên. Windows có thể chạy các lệnh tương ứng trong Git Bash hoặc tạo host bằng `flutter create --project-name webos_remote --org vn.local.webosremote --platforms android,windows,macos,linux .`, rồi chạy `python scripts/platform_permissions.py`, `flutter pub get`, `flutter analyze`, `flutter test`.

```sh
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release   # trên Windows
flutter build macos --release     # trên macOS
flutter build linux --release     # trên Linux
```

APK dùng cấu hình ký mặc định của Flutter khi chưa cấu hình release signing; cần khóa ký riêng trước khi phát hành. Desktop cần ký/đóng gói riêng nếu phân phối.

## Kết nối TV

1. TV và máy/điện thoại phải cùng LAN/Wi-Fi; tránh guest Wi-Fi hoặc AP isolation.
2. Lấy IPv4 trong cài đặt Mạng trên TV. Bật LG Connect Apps / Mobile TV On nếu firmware có tùy chọn này.
3. Nhập IPv4, nhấn **Kết nối / Ghép đôi**, chấp nhận yêu cầu trên TV trong 60 giây.
4. Thử âm lượng, Home và điều hướng. Khi thay đổi quyền hoặc ghép đôi lỗi, chọn **Quên khóa ghép đôi** rồi thử lại.

Mặc định dùng `ws://TV:3000` trong LAN. Khóa được lưu bằng SharedPreferences, **không mã hóa**; chỉ dùng trên thiết bị và mạng tin cậy. Không công khai cổng TV ra Internet. Tùy chọn WSS cổng 3001 giữ kiểm tra chứng chỉ TLS; chứng chỉ tự ký của TV sẽ bị từ chối trừ khi được hệ thống tin cậy. Không có bypass chứng chỉ.

## Kiểm thử

`flutter test` gồm kiểm tra UI khóa nút khi chưa kết nối và server TV giả kiểm tra handshake, lệnh SSAP, lỗi và ngắt kết nối. Tests không thay thế kiểm tra firmware thật.

Môi trường cloud ban đầu không có Flutter; tải Dart SDK bị proxy từ chối (HTTP 403 tại storage.googleapis.com). Vì vậy **chưa chạy analyzer, tests hay build APK/desktop** trong môi trường này. Cần cho phép miền tải SDK trong environment settings, hoặc chạy lệnh trên máy có Flutter. Chưa kiểm tra trên TV thật vì cloud không nằm trong Wi-Fi của TV.
