import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';

final _date = DateFormat('dd/MM/yyyy');
final _time = DateFormat('HH:mm');

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final AttendanceStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => _buildShell(context),
  );

  Widget _buildShell(BuildContext context) {
    if (widget.store.currentUser == null) return const SizedBox.shrink();
    final role = widget.store.currentUser!.role;
    final pages = role == UserRole.admin
        ? <Widget>[
            _Dashboard(store: widget.store),
            _EmployeesPage(store: widget.store),
            _AdminAttendancePage(store: widget.store),
            _RequestsPage(store: widget.store),
            _ProfilePage(store: widget.store),
          ]
        : role == UserRole.employee
        ? <Widget>[
            _Dashboard(store: widget.store),
            _PunchPage(store: widget.store),
            _HistoryPage(store: widget.store),
            _RequestsPage(store: widget.store),
            _ProfilePage(store: widget.store),
          ]
        : <Widget>[
            _Dashboard(store: widget.store),
            _RequestsPage(store: widget.store),
            _ProfilePage(store: widget.store),
          ];
    final destinations = role == UserRole.admin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Nhân sự',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Chấm công',
            ),
            NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Đơn từ',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ]
        : role == UserRole.employee
        ? const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.fingerprint),
              selectedIcon: Icon(Icons.fingerprint),
              label: 'Chấm công',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Đơn từ',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Yêu cầu',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.store});
  final AttendanceStore store;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  AttendanceStore get store => widget.store;

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = store.currentUser!;
    final admin = user.role == UserRole.admin;
    final employee = user.role == UserRole.employee;
    final today = store.todayRecord;
    final todayMinutes = store.todayWorkedMinutes;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              await store.refreshAttendance();
              if (admin) await store.refreshEmployees();
              store.refresh();
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không tải được dữ liệu mới: $error')),
                );
              }
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting(),
                          style: const TextStyle(
                            color: Color(0xFF728198),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.name.split(' ').take(2).join(' '),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFFDDF3EF),
                    backgroundImage: user.avatarBase64.isEmpty
                        ? null
                        : MemoryImage(base64Decode(user.avatarBase64)),
                    child: user.avatarBase64.isEmpty
                        ? Text(
                            initials(user.name),
                            style: const TextStyle(
                              color: teal,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${user.role.label} · ${user.department}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 22),
              if (employee)
                _HeroAttendance(store: store, today: today)
              else
                _AdminHero(admin: admin, store: store),
              const SizedBox(height: 18),
              SectionTitle(admin ? 'Hôm nay tại công ty' : 'Tóm tắt của bạn'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: admin
                          ? Icons.groups_2_outlined
                          : Icons.access_time_rounded,
                      title: admin ? 'Có mặt hôm nay' : 'Giờ đã làm',
                      value: admin
                          ? '${store.todayCount}'
                          : '${todayMinutes ~/ 60}h ${todayMinutes % 60}m',
                      color: teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.mark_email_unread_outlined,
                      title: 'Đơn chờ duyệt',
                      value:
                          '${admin ? store.pendingCount : store.myRequests.where((r) => r.status == 'Chờ duyệt').length}',
                      color: const Color(0xFFEF9A55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionTitle(
                admin ? 'Tình hình nhân sự' : 'Chấm công gần đây',
                trailing: Text(
                  DateFormat('dd MMM', 'vi').format(DateTime.now()),
                  style: const TextStyle(
                    color: Color(0xFF8390A1),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (admin)
                ...store.attendance.take(4).map((r) => _AttendanceTile(row: r))
              else
                ...store.myAttendance
                    .take(4)
                    .map((r) => _AttendanceTile(row: r)),
              if (!admin && employee) ...[
                const SizedBox(height: 18),
                AppCard(
                  color: const Color(0xFFFFF6E8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFE6A13B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trợ lý công minh bạch',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              today?.checkOut == null && today != null
                                  ? 'Bạn chưa kết thúc ca hôm nay. Nhớ chấm ra để giờ công được tính chính xác.'
                                  : 'Kiểm tra giờ vào/ra mỗi ngày để phát hiện sớm sai lệch trước kỳ lương.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF776449),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!employee && !admin) ...[
                const SizedBox(height: 18),
                AppCard(
                  color: const Color(0xFFEAF7F5),
                  child: const Row(
                    children: [
                      Icon(Icons.business_center_outlined, color: teal),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Khu vực khách hàng\nTheo dõi yêu cầu và thông tin hợp tác tại đây.',
                          style: TextStyle(
                            color: ink,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroAttendance extends StatelessWidget {
  const _HeroAttendance({required this.store, required this.today});
  final AttendanceStore store;
  final AttendanceRecord? today;
  @override
  Widget build(BuildContext context) {
    final checked = today != null;
    final ended = today?.checkOut != null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ink, Color(0xFF285270)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, color: Color(0xFFB9EDE2)),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, dd MMMM', 'vi').format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFFB9EDE2),
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            ended
                ? 'Ca làm đã hoàn tất'
                : checked
                ? 'Bạn đang trong ca làm'
                : 'Bạn chưa chấm công',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            checked
                ? 'Vào ca lúc ${_time.format(today!.checkIn)}${ended ? ' · Ra lúc ${_time.format(today!.checkOut!)}' : ''}'
                : 'Chấm công kèm vị trí và ảnh xác nhận khuôn mặt.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ended
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PunchPage(store: store),
                      ),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ink,
                disabledBackgroundColor: Colors.white70,
                minimumSize: const Size(0, 49),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: Icon(
                ended
                    ? Icons.check_circle_outline
                    : checked
                    ? Icons.logout_rounded
                    : Icons.fingerprint,
              ),
              label: Text(
                ended
                    ? 'Đã hoàn tất hôm nay'
                    : checked
                    ? 'Chấm công ra'
                    : 'Chấm công vào',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.admin, required this.store});
  final bool admin;
  final AttendanceStore store;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [ink, Color(0xFF285270)]),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(
            admin
                ? Icons.admin_panel_settings_outlined
                : Icons.storefront_outlined,
            color: const Color(0xFFB9EDE2),
            size: 28,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                admin ? 'Trung tâm quản trị' : 'Cổng thông tin đối tác',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                admin
                    ? '${store.employees.length} hồ sơ · ${store.pendingCount} yêu cầu đang chờ'
                    : 'Cập nhật các yêu cầu và thông tin liên hệ của bạn',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String title, value;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(height: 13),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF78869A)),
        ),
      ],
    ),
  );
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.row});
  final AttendanceRecord row;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.event_available_rounded, color: teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.employeeName,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_date.format(row.checkIn)} · ${row.note.isEmpty ? 'Chấm công' : row.note}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${_time.format(row.checkIn)}\n${row.checkOut == null ? 'Đang ca' : _time.format(row.checkOut!)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PunchPage extends StatefulWidget {
  const _PunchPage({required this.store});
  final AttendanceStore store;
  @override
  State<_PunchPage> createState() => _PunchPageState();
}

class _PunchPageState extends State<_PunchPage> {
  bool _busy = false;
  Position? _position;
  bool _faceVerified = false;
  AttendanceStore get store => widget.store;

  Future<void> _getLocation() async {
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Hãy bật Dịch vụ vị trí/GPS trên điện thoại.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception('Ứng dụng cần quyền vị trí để ghi nhận nơi chấm công.');
      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _captureFace() async {
    setState(() => _busy = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await detector.processImage(
        InputImage.fromFilePath(image.path),
      );
      await detector.close();
      if (faces.length != 1) {
        _faceVerified = false;
        _toast(
          faces.isEmpty
              ? 'Không nhận thấy khuôn mặt. Hãy chụp lại ở nơi đủ sáng.'
              : 'Ảnh cần có đúng một khuôn mặt.',
        );
      } else {
        _faceVerified = true;
      }
    } catch (_) {
      _toast(
        'Không mở được camera/nhận diện. Kiểm tra quyền camera trên điện thoại.',
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _punch() async {
    if (_position == null)
      return _toast('Hãy lấy vị trí GPS trước khi chấm công.');
    if (!_faceVerified) return _toast('Hãy chụp ảnh xác nhận khuôn mặt trước.');
    setState(() => _busy = true);
    try {
      if (store.activeShift == null) {
        await store.checkIn(
          latitude: _position!.latitude,
          longitude: _position!.longitude,
          note: 'Chấm công bằng ứng dụng',
        );
      } else {
        await store.checkOut();
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _faceVerified = false;
      });
      _toast('Đã ghi nhận chấm công thành công.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Không ghi nhận được chấm công: $error');
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) {
    final row = store.todayRecord;
    final completed = row?.checkOut != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chấm công',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ink, Color(0xFF285270)]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CA LÀM HÔM NAY',
                  style: TextStyle(
                    color: Color(0xFFB9EDE2),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  completed
                      ? 'Đã kết thúc lúc ${_time.format(row!.checkOut!)}'
                      : row == null
                      ? 'Sẵn sàng bắt đầu?'
                      : 'Đang làm việc từ ${_time.format(row.checkIn)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'vi').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Xác nhận vị trí'),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ lấy tọa độ khi bạn bấm nút bên dưới. Chia sẻ vị trí là tùy chọn.',
                ),
                const SizedBox(height: 13),
                if (_position != null)
                  Text(
                    'Vị trí: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _getLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(
                        _position == null ? 'Lấy vị trí GPS' : 'Cập nhật GPS',
                      ),
                    ),
                    if (_position != null)
                      TextButton.icon(
                        onPressed: () async {
                          final point =
                              '${_position!.latitude},${_position!.longitude}';
                          final mapsUri = Uri.https(
                            'www.google.com',
                            '/maps/search/',
                            {'api': '1', 'query': point},
                          );
                          final opened = await launchUrl(
                            mapsUri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!opened && mounted) {
                            await Clipboard.setData(ClipboardData(text: point));
                            _toast('Không mở được Maps; đã sao chép tọa độ.');
                          }
                        },
                        icon: const Icon(Icons.share_location_outlined),
                        label: const Text('Mở Google Maps'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Xác nhận khuôn mặt'),
                const SizedBox(height: 7),
                const Text(
                  'Chụp một ảnh selfie. App chỉ kiểm tra ảnh có đúng một khuôn mặt, chưa xác định danh tính.',
                ),
                const SizedBox(height: 14),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _faceVerified
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_retouching_natural_rounded,
                              size: 45,
                              color: teal,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Đã thấy một khuôn mặt',
                              style: TextStyle(
                                color: teal,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_outlined,
                              size: 45,
                              color: Color(0xFF92A0B2),
                            ),
                            SizedBox(height: 8),
                            Text('Chưa có ảnh xác nhận'),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _captureFace,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Chụp ảnh selfie'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _busy || completed ? null : _punch,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      row == null ? Icons.login_rounded : Icons.logout_rounded,
                    ),
              label: Text(
                completed
                    ? 'Đã hoàn tất hôm nay'
                    : row == null
                    ? 'CHẤM CÔNG VÀO'
                    : 'CHẤM CÔNG RA',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.store});
  final AttendanceStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Lịch sử chấm công',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Các lần vào/ra ca làm của bạn.',
          style: TextStyle(color: Color(0xFF728198)),
        ),
        const SizedBox(height: 14),
        ...store.myAttendance.map((r) => _AttendanceTile(row: r)),
      ],
    ),
  );
}

class _EmployeesPage extends StatelessWidget {
  const _EmployeesPage({required this.store});
  final AttendanceStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Quản lý nhân sự',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: () => _editEmployee(context, store),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          '${store.employees.length} hồ sơ nhân viên',
          style: const TextStyle(color: Color(0xFF728198)),
        ),
        const SizedBox(height: 13),
        ...store.employees.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEAF7F5),
                    child: Text(
                      initials(e.name),
                      style: const TextStyle(
                        color: teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${e.position} · ${e.department}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(e.email, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editEmployee(context, store, e);
                      if (v == 'delete')
                        _confirmDelete(
                          context,
                          'Xóa hồ sơ ${e.name}?',
                          () => store.deleteEmployee(e.id),
                        );
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _editEmployee(
  BuildContext context,
  AttendanceStore store, [
  EmployeeRecord? item,
]) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _EditEmployeeDialog(store: store, employee: item),
  );
}

class _EditEmployeeDialog extends StatefulWidget {
  const _EditEmployeeDialog({required this.store, this.employee});

  final AttendanceStore store;
  final EmployeeRecord? employee;

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  late final _name = TextEditingController(text: widget.employee?.name ?? '');
  late final _email = TextEditingController(text: widget.employee?.email ?? '');
  late final _department = TextEditingController(
    text: widget.employee?.department ?? '',
  );
  late final _position = TextEditingController(
    text: widget.employee?.position ?? 'Nhân viên',
  );
  late final _phone = TextEditingController(text: widget.employee?.phone ?? '');
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _department.dispose();
    _position.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) return;
    final employee = widget.employee;
    try {
      await widget.store.saveEmployee(
        EmployeeRecord(
          id: employee?.id ?? 'e-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          email: email,
          department: _department.text.trim(),
          position: _position.text.trim(),
          phone: _phone.text.trim(),
        ),
        password: _password.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được nhân viên: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.employee == null ? 'Thêm nhân viên' : 'Sửa hồ sơ'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ tên'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _department,
            decoration: const InputDecoration(labelText: 'Phòng ban'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _position,
            decoration: const InputDecoration(labelText: 'Chức vụ'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Điện thoại'),
          ),
          if (widget.employee == null && widget.store.apiToken != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu đăng nhập (ít nhất 8 ký tự)',
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

class _AdminAttendancePage extends StatelessWidget {
  const _AdminAttendancePage({required this.store});
  final AttendanceStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Quản lý chấm công',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          '${store.attendance.length} bản ghi · ${store.todayCount} hôm nay',
          style: const TextStyle(color: Color(0xFF728198)),
        ),
        const SizedBox(height: 12),
        ...store.attendance.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.employeeName,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_date.format(row.checkIn)} · ${_time.format(row.checkIn)} – ${row.checkOut == null ? 'Chưa ra' : _time.format(row.checkOut!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (row.latitude != null)
                          Text(
                            '${row.latitude!.toStringAsFixed(4)}, ${row.longitude!.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editAttendance(context, store, row),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(
                      context,
                      'Xóa bản ghi chấm công này?',
                      () => store.deleteAttendance(row.id),
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _editAttendance(
  BuildContext context,
  AttendanceStore store,
  AttendanceRecord row,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _EditAttendanceDialog(store: store, record: row),
  );
}

class _EditAttendanceDialog extends StatefulWidget {
  const _EditAttendanceDialog({required this.store, required this.record});

  final AttendanceStore store;
  final AttendanceRecord record;

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  late final _note = TextEditingController(text: widget.record.note);
  late final _inTime = TextEditingController(
    text: _time.format(widget.record.checkIn),
  );
  late final _outTime = TextEditingController(
    text: widget.record.checkOut == null
        ? ''
        : _time.format(widget.record.checkOut!),
  );

  @override
  void dispose() {
    _note.dispose();
    _inTime.dispose();
    _outTime.dispose();
    super.dispose();
  }

  DateTime? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    return DateTime(
      widget.record.checkIn.year,
      widget.record.checkIn.month,
      widget.record.checkIn.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  void _save() {
    widget.store.saveAttendance(
      widget.record.copyWith(
        checkIn: _parseTime(_inTime.text) ?? widget.record.checkIn,
        checkOut: _parseTime(_outTime.text),
        clearCheckOut: _outTime.text.trim().isEmpty,
        note: _note.text,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sửa bản ghi chấm công'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _inTime,
            decoration: const InputDecoration(labelText: 'Giờ vào (HH:mm)'),
          ),
          TextField(
            controller: _outTime,
            decoration: const InputDecoration(labelText: 'Giờ ra (HH:mm)'),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

class _RequestsPage extends StatelessWidget {
  const _RequestsPage({required this.store});
  final AttendanceStore store;
  @override
  Widget build(BuildContext context) {
    final admin = store.currentUser!.role == UserRole.admin;
    final rows = admin ? store.requests : store.myRequests;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          admin ? 'Duyệt đơn từ' : 'Yêu cầu của tôi',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!admin && store.currentUser!.role == UserRole.employee)
            IconButton(
              onPressed: () => _requestDialog(context, store),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${rows.length} yêu cầu',
            style: const TextStyle(color: Color(0xFF728198)),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.category,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _StatusPill(r.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (admin)
                      Text(
                        r.employeeName,
                        style: const TextStyle(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      '${_date.format(r.from)}${r.to == r.from ? '' : ' – ${_date.format(r.to)}'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Text(r.reason),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (admin && r.status == 'Chờ duyệt') ...[
                          TextButton(
                            onPressed: () => store.updateRequest(
                              r.copyWith(status: 'Từ chối'),
                            ),
                            child: const Text('Từ chối'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton.tonal(
                            onPressed: () => store.updateRequest(
                              r.copyWith(status: 'Đã duyệt'),
                            ),
                            child: const Text('Duyệt'),
                          ),
                        ] else if (!admin && r.status == 'Chờ duyệt') ...[
                          TextButton(
                            onPressed: () => _requestDialog(context, store, r),
                            child: const Text('Sửa'),
                          ),
                          TextButton(
                            onPressed: () => _confirmDelete(
                              context,
                              'Xóa yêu cầu này?',
                              () => store.deleteRequest(r.id),
                            ),
                            child: const Text('Xóa'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'Đã duyệt'
        ? teal
        : status == 'Từ chối'
        ? Colors.redAccent
        : const Color(0xFFE6A13B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

Future<void> _requestDialog(
  BuildContext context,
  AttendanceStore store, [
  LeaveRequest? old,
]) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _RequestDialog(store: store, request: old),
  );
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.store, this.request});

  final AttendanceStore store;
  final LeaveRequest? request;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  late final _reason = TextEditingController(
    text: widget.request?.reason ?? '',
  );
  late String _category = widget.request?.category ?? 'Nghỉ phép';
  late DateTime _from =
      widget.request?.from ?? DateTime.now().add(const Duration(days: 1));
  late DateTime _to = widget.request?.to ?? _from;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: start
          ? DateTime.now().subtract(const Duration(days: 90))
          : _from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (start) {
        _from = selected;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = selected;
      }
    });
  }

  void _save() {
    final user = widget.store.currentUser!;
    final old = widget.request;
    final value = LeaveRequest(
      id: old?.id ?? 'r-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      employeeName: user.name,
      category: _category,
      from: _from,
      to: _to,
      reason: _reason.text.trim(),
    );
    if (old == null) {
      widget.store.createRequest(value);
    } else {
      widget.store.updateRequest(value);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.request == null ? 'Tạo yêu cầu' : 'Sửa yêu cầu'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
            items: const ['Nghỉ phép', 'Đi muộn/về sớm', 'Điều chỉnh công']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() {
              _category = value ?? _category;
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickDate(start: true),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_date.format(_from)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickDate(start: false),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(_date.format(_to)),
                ),
              ),
            ],
          ),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Lý do'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  String text,
  Future<void> Function() delete,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác nhận'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  if (ok == true) {
    try {
      await delete();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thực hiện được thao tác: $error')),
        );
      }
    }
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.store});
  final AttendanceStore store;
  @override
  Widget build(BuildContext context) {
    final user = store.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tài khoản',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFEAF7F5),
                  backgroundImage: user.avatarBase64.isEmpty
                      ? null
                      : MemoryImage(base64Decode(user.avatarBase64)),
                  child: user.avatarBase64.isEmpty
                      ? Text(
                          initials(user.name),
                          style: const TextStyle(
                            color: teal,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user.role.label,
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 26),
                _ProfileLine(icon: Icons.alternate_email, text: user.email),
                _ProfileLine(
                  icon: Icons.phone_outlined,
                  text: user.phone.isEmpty
                      ? 'Chưa thêm số điện thoại'
                      : user.phone,
                ),
                _ProfileLine(
                  icon: Icons.apartment_outlined,
                  text: user.department,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE7EDF2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C142B45),
                  blurRadius: 20,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F6F2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đăng nhập sinh trắc học',
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Khuôn mặt hoặc vân tay trên điện thoại',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF78869A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: user.biometricEnabled,
                      activeTrackColor: teal,
                      onChanged: (enabled) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (!enabled) {
                            await store.setBiometricEnabled(user.id, false);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã tắt đăng nhập sinh trắc học.',
                                ),
                              ),
                            );
                            return;
                          }
                          final auth = LocalAuthentication();
                          if (!await auth.canCheckBiometrics ||
                              !await auth.isDeviceSupported()) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Điện thoại chưa thiết lập sinh trắc học. Hãy bật khuôn mặt hoặc vân tay trong Cài đặt.',
                                ),
                              ),
                            );
                            return;
                          }
                          final verified = await auth.authenticate(
                            localizedReason:
                                'Xác nhận để bật đăng nhập sinh trắc học',
                            biometricOnly: true,
                          );
                          if (!verified) return;
                          await store.setBiometricEnabled(user.id, true);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Đã bật đăng nhập sinh trắc học.'),
                            ),
                          );
                        } catch (error) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Không bật được sinh trắc học: $error',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _BiometricMethodCard(
                        icon: Icons.face_retouching_natural_rounded,
                        label: 'Khuôn mặt',
                        enabled: user.biometricEnabled,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BiometricMethodCard(
                        icon: Icons.fingerprint_rounded,
                        label: 'Vân tay',
                        enabled: user.biometricEnabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.biometricEnabled
                      ? 'Đã bật trên tài khoản này. Android sẽ hiển thị phương thức sinh trắc học mà điện thoại hỗ trợ.'
                      : 'Bật công tắc rồi xác nhận bằng sinh trắc học đã cài trên điện thoại.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            color: const Color(0xFFEAF5FB),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_done_outlined, color: Color(0xFF31759B)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Đăng nhập và dữ liệu chấm công đang kết nối với máy chủ. Khuôn mặt/vân tay dùng phương thức bảo mật mà Android hỗ trợ trên điện thoại này.',
                    style: TextStyle(
                      color: Color(0xFF416477),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await store.setSession(null);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Color(0xFFFFD7D7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricMethodCard extends StatelessWidget {
  const _BiometricMethodCard({
    required this.icon,
    required this.label,
    required this.enabled,
  });
  final IconData icon;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
    decoration: BoxDecoration(
      color: enabled ? const Color(0xFFF0FAF7) : const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: enabled ? const Color(0xFFCDECE4) : const Color(0xFFE7EDF2),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: enabled ? teal : const Color(0xFF7D8A9B), size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: enabled ? ink : const Color(0xFF78869A),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF728198)),
        const SizedBox(width: 9),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}
