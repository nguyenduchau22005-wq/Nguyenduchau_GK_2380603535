# Nguyenduchau_GK_2380603535

Ứng dụng Flutter chấm công và quản lý chấm công nhân viên, dùng API ASP.NET Core và SQL Server. Ứng dụng hướng tới chạy trên điện thoại Android thật.

## Chức năng

- Đăng ký tài khoản nhân viên/khách hàng và xác minh email qua API.
- Đăng nhập bằng tên đăng nhập hoặc email và mật khẩu; API có thể yêu cầu OTP.
- Điều hướng theo vai trò do API trả về.
- Chấm công vào/ra, xem lịch sử và gửi yêu cầu điều chỉnh/nghỉ phép.
- Lấy vị trí GPS, chụp ảnh khi chấm công và xác thực sinh trắc học Android nếu thiết bị hỗ trợ.
- Giao diện quản trị nhân viên và dữ liệu chấm công theo các quyền được API cấp.

## Yêu cầu

- Flutter SDK và Android Studio đã cài đặt.
- Điện thoại Android có bật USB debugging, hoặc một thiết bị Android khác.
- API chấm công đang hoạt động và có thể truy cập từ điện thoại. URL API hiện được đặt trong `lib/api_service.dart`; địa chỉ ngrok có thể hết hạn hoặc máy chủ có thể ngoại tuyến.

## Chạy ứng dụng

1. Clone repository hoặc mở thư mục project trong Android Studio.
2. Chọn **Pub get** để tải các package Flutter và đợi Gradle sync.
3. Bật **Tùy chọn nhà phát triển → Gỡ lỗi USB** trên điện thoại, kết nối với máy tính và chấp nhận yêu cầu gỡ lỗi.
4. Chọn điện thoại trong danh sách thiết bị Android Studio rồi nhấn **Run**.
5. Cho phép quyền vị trí và camera khi ứng dụng yêu cầu. Cài đặt vân tay/khuôn mặt trong Android trước khi bật xác thực sinh trắc học trong app.

Nếu ứng dụng báo không kết nối được, kiểm tra API và URL trong `lib/api_service.dart`; `localhost` trên điện thoại trỏ về chính điện thoại, không phải máy tính đang chạy API.

## Lưu ý bảo mật

- Không có tài khoản hay OTP mặc định được công bố trong tài liệu này. Tạo tài khoản qua API và dùng OTP do máy chủ gửi.
- Không commit `.env`, `android/local.properties`, `key.properties`, keystore, mật khẩu hoặc token.
- Xác thực sinh trắc học dùng dữ liệu đã đăng ký trên thiết bị. Việc chụp ảnh khuôn mặt trong luồng chấm công không tự chứng minh danh tính nếu máy chủ không đối chiếu ảnh.
