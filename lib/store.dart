import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'models.dart';

T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;

Map<String, dynamic> _apiObject(dynamic value) {
  if (value is! Map) return {};
  var map = Map<String, dynamic>.from(value);
  for (final key in ['data', 'result', 'user', 'employee', 'payload']) {
    final nested = map[key];
    if (nested is Map) {
      map = Map<String, dynamic>.from(nested);
      break;
    }
  }
  return map;
}

Map<String, dynamic>? _findUserMap(Map<String, dynamic> source) {
  for (final key in ['user', 'employee', 'profile', 'data', 'result']) {
    final value = source[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  if (source.keys.any(
        (key) =>
            ['id', 'userId', 'employeeId', 'displayName', 'name'].contains(key),
      ) ||
      source.keys.any(
        (key) =>
            key.toLowerCase().endsWith('/role') ||
            key.toLowerCase().endsWith('/nameidentifier'),
      ))
    return source;
  return null;
}

dynamic _pick(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source[key] != null) return source[key];
    for (final entry in source.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase() && entry.value != null)
        return entry.value;
    }
  }
  return null;
}

String? _readToken(Map<String, dynamic> source) {
  final value = _pick(source, ['token', 'accessToken', 'jwt', 'access_token']);
  if (value is String && value.isNotEmpty) return value;
  for (final key in ['data', 'result', 'auth']) {
    final nested = source[key];
    if (nested is Map) {
      final token = _readToken(Map<String, dynamic>.from(nested));
      if (token != null) return token;
    }
  }
  return null;
}

String? _tokenFromResponse(dynamic response) {
  if (response is String && response.split('.').length == 3) return response;
  if (response is Map) {
    final raw = Map<String, dynamic>.from(response);
    return _readToken(raw) ?? _readToken(_apiObject(raw));
  }
  return null;
}

String _readMessage(
  Map<String, dynamic> source, {
  String fallback = 'Máy chủ đã nhận yêu cầu.',
}) {
  final direct = _pick(source, ['message', 'detail', 'error']);
  if (direct != null && '$direct'.trim().isNotEmpty) return '$direct';
  final errors = _pick(source, ['errors', 'validationErrors']);
  if (errors is Map) {
    final details = errors.entries.map((entry) {
      final value = entry.value;
      final message = value is Iterable
          ? value.map((item) => '$item').join(', ')
          : '$value';
      return '${entry.key}: $message';
    }).join('; ');
    if (details.isNotEmpty) return details;
  }
  for (final key in ['data', 'result', 'payload']) {
    final nested = source[key];
    if (nested is Map) {
      final message = _readMessage(Map<String, dynamic>.from(nested));
      if (message != 'Máy chủ đã nhận yêu cầu.') return message;
    }
  }
  final title = _pick(source, ['title']);
  return title == null || '$title'.trim().isEmpty ? fallback : '$title';
}

bool _apiRejected(dynamic value) {
  if (value is! Map) return false;
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    if ((key == 'success' || key == 'issuccess') && entry.value == false) {
      return true;
    }
    if (['data', 'result', 'user', 'employee', 'payload'].contains(key) &&
        _apiRejected(entry.value)) {
      return true;
    }
  }
  return false;
}

Map<String, dynamic> _jwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return {};
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  } catch (_) {
    return {};
  }
}

UserRole _apiRole(dynamic value) {
  final role =
      (value is List ? (value.isEmpty ? null : value.first) : value)
          ?.toString()
          .toLowerCase() ??
      '';
  if (role.contains('admin') || role.contains('quản trị'))
    return UserRole.admin;
  if (role.contains('customer') || role.contains('khách'))
    return UserRole.customer;
  return UserRole.employee;
}

List<Map<String, dynamic>> _apiRows(dynamic value) {
  if (value is List)
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  if (value is! Map) return [];
  final map = Map<String, dynamic>.from(value);
  for (final key in [
    'data',
    'items',
    'records',
    'attendance',
    'history',
    'results',
    'result',
    'value',
  ]) {
    dynamic nested;
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        nested = entry.value;
        break;
      }
    }
    if (nested is List) return _apiRows(nested);
    if (nested is Map) {
      final rows = _apiRows(nested);
      if (rows.isNotEmpty) return rows;
    }
  }
  if (_pick(map, [
        'checkIn',
        'checkInAt',
        'checkInTime',
        'clockIn',
        'startTime',
        'timeIn',
        'attendanceDate',
      ]) !=
      null)
    return [map];
  return [];
}

AttendanceRecord? _attendanceFromApi(Map<String, dynamic> json, AppUser user) {
  final checkInValue = _pick(json, [
    'checkIn',
    'checkInAt',
    'checkInTime',
    'clockIn',
    'startTime',
    'timeIn',
    'attendanceDate',
    'createdAt',
    'date',
  ]);
  final checkIn = _parseApiDate(checkInValue);
  if (checkIn == null) return null;
  final checkOut = _parseApiDate(
    _pick(json, [
      'checkOut',
      'checkOutAt',
      'checkOutTime',
      'clockOut',
      'endTime',
      'timeOut',
    ]),
  );
  return AttendanceRecord(
    id: '${_pick(json, ['id', 'attendanceId', 'recordId']) ?? '${user.id}-${checkIn.microsecondsSinceEpoch}'}',
    userId: user.id,
    employeeName:
        '${_pick(json, ['employeeName', 'displayName', 'name']) ?? user.name}',
    checkIn: checkIn,
    checkOut: checkOut,
    latitude: (_pick(json, ['latitude', 'lat']) as num?)?.toDouble(),
    longitude: (_pick(json, ['longitude', 'lng', 'lon']) as num?)?.toDouble(),
    note: '${_pick(json, ['note', 'description', 'status']) ?? ''}',
  );
}

DateTime? _parseApiDate(dynamic value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is num) {
    final millis = value > 100000000000
        ? value.toInt()
        : (value * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  return null;
}

class ApiLoginResult {
  const ApiLoginResult({
    this.user,
    this.otpRequired = false,
    this.message = '',
  });
  final AppUser? user;
  final bool otpRequired;
  final String message;
}

class AttendanceStore extends ChangeNotifier {
  static const _usersKey = 'users_v1';
  static const _employeesKey = 'employees_v1';
  static const _attendanceKey = 'attendance_v1';
  static const _requestsKey = 'requests_v1';
  static const _sessionKey = 'session_v1';
  static const _tokenKey = 'api_token_v1';
  final ApiService api = ApiService();

  late SharedPreferences _prefs;
  List<AppUser> users = [];
  List<EmployeeRecord> employees = [];
  List<AttendanceRecord> attendance = [];
  List<LeaveRequest> requests = [];
  AppUser? currentUser;
  String? _apiToken;
  String? _pendingLoginUsername;
  String? get apiToken => _apiToken;

  static String hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  String get _today =>
      DateTime.now().toLocal().toIso8601String().substring(0, 10);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    users = _readList(_usersKey, AppUser.fromJson);
    employees = _readList(_employeesKey, EmployeeRecord.fromJson);
    attendance = _readList(_attendanceKey, AttendanceRecord.fromJson);
    requests = _readList(_requestsKey, LeaveRequest.fromJson);
    await _moveSampleShiftsOutOfToday();
    if (users.isEmpty) await _seed();
    final id = _prefs.getString(_sessionKey);
    currentUser = _firstOrNull(users.where((u) => u.id == id));
    _apiToken = _prefs.getString(_tokenKey);
    if (currentUser != null && _apiToken != null) {
      try {
        await refreshAttendance();
      } catch (_) {
        // Keep the last locally cached records available while offline.
      }
    }
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      _usersKey,
      jsonEncode(users.map((e) => e.toJson()).toList()),
    );
    await _prefs.setString(
      _employeesKey,
      jsonEncode(employees.map((e) => e.toJson()).toList()),
    );
    await _prefs.setString(
      _attendanceKey,
      jsonEncode(attendance.map((e) => e.toJson()).toList()),
    );
    await _prefs.setString(
      _requestsKey,
      jsonEncode(requests.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _seed() async {
    users = [
      _demo(
        'u-admin',
        'Quản trị viên',
        'admin',
        'admin@chamcong.demo',
        'Admin@123',
        UserRole.admin,
        '0901000001',
        'Điều hành',
      ),
      _demo(
        'u-employee',
        'Nguyễn Đức Hậu',
        'nhanvien',
        'nhanvien@chamcong.demo',
        'Nhanvien@123',
        UserRole.employee,
        '0901000002',
        'Công nghệ',
      ),
      _demo(
        'u-customer',
        'Khách hàng mẫu',
        'khachhang',
        'khachhang@chamcong.demo',
        'Khach@123',
        UserRole.customer,
        '0901000003',
        'Đối tác',
      ),
    ];
    employees = [
      const EmployeeRecord(
        id: 'e1',
        name: 'Nguyễn Đức Hậu',
        email: 'nhanvien@chamcong.demo',
        department: 'Công nghệ',
        position: 'Nhân viên',
        phone: '0901000002',
      ),
      const EmployeeRecord(
        id: 'e2',
        name: 'Trần Minh Anh',
        email: 'minhanh@chamcong.demo',
        department: 'Nhân sự',
        position: 'Chuyên viên',
        phone: '0901000004',
      ),
      const EmployeeRecord(
        id: 'e3',
        name: 'Lê Gia Bảo',
        email: 'giabao@chamcong.demo',
        department: 'Kinh doanh',
        position: 'Nhân viên',
        phone: '0901000005',
      ),
    ];
    final now = DateTime.now();
    final sampleDay = now.subtract(const Duration(days: 1));
    attendance = [
      AttendanceRecord(
        id: 'a1',
        userId: 'u-employee',
        employeeName: 'Nguyễn Đức Hậu',
        checkIn: DateTime(sampleDay.year, sampleDay.month, sampleDay.day, 8, 2),
        checkOut: DateTime(
          sampleDay.year,
          sampleDay.month,
          sampleDay.day,
          17,
          10,
        ),
        latitude: 10.7769,
        longitude: 106.7009,
        note: 'Văn phòng',
      ),
      AttendanceRecord(
        id: 'a2',
        userId: 'e2',
        employeeName: 'Trần Minh Anh',
        checkIn: DateTime(
          sampleDay.year,
          sampleDay.month,
          sampleDay.day,
          8,
          15,
        ),
        checkOut: DateTime(
          sampleDay.year,
          sampleDay.month,
          sampleDay.day,
          17,
          0,
        ),
        latitude: 10.7769,
        longitude: 106.7009,
        note: 'Ca mẫu đã hoàn tất',
      ),
    ];
    requests = [
      LeaveRequest(
        id: 'r1',
        userId: 'u-employee',
        employeeName: 'Nguyễn Đức Hậu',
        category: 'Nghỉ phép',
        from: now.add(const Duration(days: 2)),
        to: now.add(const Duration(days: 2)),
        reason: 'Việc cá nhân',
      ),
    ];
    await _save();
  }

  Future<void> _moveSampleShiftsOutOfToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final previousDay = today.subtract(const Duration(days: 1));
    var changed = false;

    attendance = attendance.map((row) {
      final rowDay = row.checkIn.toLocal();
      final isToday =
          rowDay.year == today.year &&
          rowDay.month == today.month &&
          rowDay.day == today.day;
      final isSeedShift =
          (row.id == 'a1' && row.userId == 'u-employee') ||
          (row.id == 'a2' && row.userId == 'e2');
      if (!isToday || !isSeedShift) return row;

      changed = true;
      final checkIn = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        row.checkIn.hour,
        row.checkIn.minute,
      );
      final oldCheckOut = row.checkOut;
      final checkOut = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        oldCheckOut?.hour ?? 17,
        oldCheckOut?.minute ?? 0,
      );
      return row.copyWith(
        checkIn: checkIn,
        checkOut: checkOut,
        note: 'Ca mẫu đã hoàn tất',
      );
    }).toList();

    if (changed) {
      await _prefs.setString(
        _attendanceKey,
        jsonEncode(attendance.map((row) => row.toJson()).toList()),
      );
    }
  }

  AppUser _demo(
    String id,
    String name,
    String username,
    String email,
    String pass,
    UserRole role,
    String phone,
    String department,
  ) => AppUser(
    id: id,
    name: name,
    username: username,
    email: email,
    passwordHash: hash(pass),
    role: role,
    phone: phone,
    department: department,
  );

  AppUser? findAccount(String account) {
    final normalized = account.trim().toLowerCase();
    for (final user in users) {
      if (user.username.toLowerCase() == normalized ||
          user.email.toLowerCase() == normalized)
        return user;
    }
    return null;
  }

  Future<ApiLoginResult> startLogin(String account, String password) async {
    final normalizedInput = account.trim();
    final normalized = normalizedInput.contains('@')
        ? normalizedInput.split('@').first
        : normalizedInput;
    final response = await api.post(
      '/api/auth/login',
      body: {'username': normalized, 'password': password},
    );
    final data = _apiObject(response);
    if (_apiRejected(response)) {
      throw ApiException(
        _readMessage(data, fallback: 'Tên đăng nhập hoặc mật khẩu không đúng.'),
      );
    }
    final token = _tokenFromResponse(response) ?? _readToken(data);
    if (token == null) {
      _pendingLoginUsername = normalized;
      return ApiLoginResult(otpRequired: true, message: _readMessage(data));
    }
    final user = await _acceptApiLogin(data, token, normalized, password);
    return ApiLoginResult(user: user);
  }

  Future<AppUser> verifyLoginOtp(String code) async {
    final username = _pendingLoginUsername;
    if (username == null)
      throw const ApiException('Phiên đăng nhập đã hết hạn.');
    final response = await api.post(
      '/api/auth/verify-login-otp',
      body: {'username': username, 'code': code},
    );
    final data = _apiObject(response);
    if (_apiRejected(response)) {
      throw ApiException(
        _readMessage(data, fallback: 'Mã OTP đăng nhập không hợp lệ.'),
      );
    }
    final token = _tokenFromResponse(response) ?? _readToken(data);
    if (token == null) {
      throw ApiException(
        _readMessage(
          data,
          fallback: 'Mã OTP không đúng hoặc máy chủ chưa trả phiên đăng nhập.',
        ),
      );
    }
    final user = await _acceptApiLogin(data, token, username, '');
    _pendingLoginUsername = null;
    return user;
  }

  Future<AppUser> _acceptApiLogin(
    Map<String, dynamic> data,
    String token,
    String account,
    String password,
  ) async {
    _apiToken = token;
    await _prefs.setString(_tokenKey, token);
    var userData = _findUserMap(data) ?? _jwtClaims(token);
    if (userData.isEmpty) {
      try {
        userData = _apiObject(await api.get('/api/employees/me', token: token));
      } catch (_) {}
    }
    final id =
        '${_pick(userData, ['id', 'userId', 'employeeId', 'sub', 'nameidentifier']) ?? _claimSuffix(userData, 'nameidentifier') ?? account}';
    final username =
        '${_pick(userData, ['username', 'userName', 'unique_name']) ?? account}';
    final email =
        '${_pick(userData, ['email', 'emailAddress']) ?? (account.contains('@') ? account : '$account@unknown.local')}';
    final name =
        '${_pick(userData, ['displayName', 'name', 'fullName', 'employeeName']) ?? username}';
    final role = _apiRole(
      _pick(userData, ['role', 'roleName', 'userRole', 'roles']) ??
          _claimSuffix(userData, 'role'),
    );
    final user = AppUser(
      id: id,
      name: name,
      username: username,
      email: email,
      passwordHash: password.isEmpty ? '' : hash(password),
      role: role,
      phone: '${_pick(userData, ['phone', 'phoneNumber']) ?? ''}',
      department:
          '${_pick(userData, ['department', 'departmentName']) ?? 'Văn phòng'}',
      biometricEnabled: findAccount(account)?.biometricEnabled ?? false,
      avatarBase64: findAccount(account)?.avatarBase64 ?? '',
    );
    users = [
      ...users.where((u) => u.id != user.id && u.username != username),
      user,
    ];
    await _save();
    return user;
  }

  Future<void> beginRegistration({
    required String username,
    required String name,
    required String email,
    required String password,
    required String department,
    required UserRole role,
    required String avatarBase64,
  }) async {
    final normalizedUsername = username.trim();
    if (!RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(normalizedUsername)) {
      throw const ApiException(
        'Tên đăng nhập cần từ 3–40 ký tự, chỉ gồm chữ, số, dấu chấm, gạch dưới hoặc gạch ngang.',
      );
    }
    final response = await api.post(
      '/api/auth/register',
      body: {
        'username': normalizedUsername,
        'email': email.trim(),
        'password': password,
        'displayName': name.trim(),
        'department': department.trim().isEmpty ? null : department.trim(),
        'role': role == UserRole.customer ? 'Customer' : 'Employee',
        // RegisterRequest on the server requires an avatar as base64.
        'avatarBase64': avatarBase64,
      },
    );
    final data = _apiObject(response);
    final message = _readMessage(
      data,
      fallback: 'API từ chối yêu cầu đăng ký nhưng không gửi lý do.',
    );
    if (_apiRejected(response)) throw ApiException(message);
    _pendingLoginUsername = normalizedUsername;
  }

  Future<void> finishRegistration({
    required String code,
    required String username,
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required String avatarBase64,
  }) async {
    final normalizedUsername =
        _pendingLoginUsername ?? username.trim();
    final response = await api.post(
      '/api/auth/verify-email',
      body: {'username': normalizedUsername, 'code': code},
    );
    final data = _apiObject(response);
    if (_apiRejected(response))
      throw ApiException(
        _readMessage(data, fallback: 'Mã xác minh email không đúng.'),
      );
    final user = AppUser(
      id: '${_pick(data, ['id', 'userId']) ?? normalizedUsername}',
      name: name.trim(),
      username: normalizedUsername,
      email: email.trim(),
      passwordHash: hash(password),
      role: role,
      phone: phone.trim(),
      avatarBase64: avatarBase64,
    );
    users = [
      ...users.where(
        (u) =>
            u.username != normalizedUsername && u.email != email.trim(),
      ),
      user,
    ];
    if (role == UserRole.employee) {
      employees = [
        ...employees,
        EmployeeRecord(
          id: user.id,
          name: user.name,
          email: user.email,
          department: user.department,
          position: 'Nhân viên',
          phone: user.phone,
        ),
      ];
    }
    _pendingLoginUsername = null;
    await _save();
  }

  Future<void> setBiometricEnabled(String userId, bool enabled) async {
    users = users
        .map((u) => u.id == userId ? u.copyWith(biometricEnabled: enabled) : u)
        .toList();
    if (currentUser?.id == userId)
      currentUser = currentUser!.copyWith(biometricEnabled: enabled);
    await _save();
  }

  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    if (users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase()))
      return null;
    final username = email.trim().split('@').first;
    if (users.any((u) => u.username.toLowerCase() == username.toLowerCase()))
      return null;
    final user = AppUser(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      username: username,
      email: email.trim(),
      passwordHash: hash(password),
      role: role,
      phone: phone.trim(),
    );
    users = [...users, user];
    if (role == UserRole.employee)
      employees = [
        ...employees,
        EmployeeRecord(
          id: user.id,
          name: user.name,
          email: user.email,
          department: user.department,
          position: 'Nhân viên',
          phone: user.phone,
        ),
      ];
    await _save();
    return user;
  }

  Future<void> setSession(AppUser? user) async {
    currentUser = user;
    if (user == null) {
      await _prefs.remove(_sessionKey);
      _apiToken = null;
      await _prefs.remove(_tokenKey);
    } else {
      await _prefs.setString(_sessionKey, user.id);
    }
    notifyListeners();
    if (user != null && _apiToken != null) {
      try {
        await refreshAttendance();
        if (user.role == UserRole.admin) await refreshEmployees();
      } catch (_) {
        // Keep locally cached values visible if the server is temporarily offline.
      }
    }
  }

  void refresh() => notifyListeners();

  Future<void> refreshAttendance() async {
    final token = _apiToken;
    final user = currentUser;
    if (token == null || user == null) return;
    final results = await Future.wait([
      api.get('/api/attendance/today', token: token),
      api.get('/api/attendance/history?limit=30', token: token),
    ]);
    final rows = <AttendanceRecord>[];
    for (final result in results) {
      for (final map in _apiRows(result)) {
        final row = _attendanceFromApi(map, user);
        if (row != null && rows.every((existing) => existing.id != row.id))
          rows.add(row);
      }
    }
    attendance = [...attendance.where((row) => row.userId != user.id), ...rows]
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    await _prefs.setString(
      _attendanceKey,
      jsonEncode(attendance.map((row) => row.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> refreshEmployees() async {
    final token = _apiToken;
    if (token == null || currentUser?.role != UserRole.admin) return;
    final rows = _apiRows(await api.get('/api/employees', token: token));
    employees = rows
        .map((row) {
          final id = '${_pick(row, ['id', 'employeeId', 'userId']) ?? ''}';
          return EmployeeRecord(
            id: id,
            name:
                '${_pick(row, ['displayName', 'name', 'fullName']) ?? 'Nhân viên'}',
            email: '${_pick(row, ['email', 'emailAddress']) ?? ''}',
            department:
                '${_pick(row, ['department', 'departmentName']) ?? 'Văn phòng'}',
            position:
                '${_pick(row, ['position', 'role', 'roleName']) ?? 'Nhân viên'}',
            phone: '${_pick(row, ['phone', 'phoneNumber']) ?? ''}',
          );
        })
        .where((employee) => employee.id.isNotEmpty)
        .toList();
    await _prefs.setString(
      _employeesKey,
      jsonEncode(employees.map((row) => row.toJson()).toList()),
    );
    notifyListeners();
  }

  AttendanceRecord? get activeShift {
    final shifts =
        attendance
            .where((a) => a.userId == currentUser?.id && a.checkOut == null)
            .toList()
          ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return _firstOrNull(shifts);
  }

  AttendanceRecord? get todayRecord {
    final active = activeShift;
    if (active != null) return active;
    final shifts =
        attendance
            .where(
              (a) =>
                  a.userId == currentUser?.id &&
                  a.checkIn.toLocal().toIso8601String().startsWith(_today),
            )
            .toList()
          ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return _firstOrNull(shifts);
  }

  List<AttendanceRecord> get myAttendance =>
      attendance.where((a) => a.userId == currentUser?.id).toList()
        ..sort((a, b) => b.checkIn.compareTo(a.checkIn));

  int get todayWorkedMinutes {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));
    return myAttendance.fold<int>(0, (total, row) {
      final start = row.checkIn.isAfter(startOfToday)
          ? row.checkIn
          : startOfToday;
      final end = row.checkOut ?? now;
      final clippedEnd = end.isBefore(endOfToday) ? end : endOfToday;
      final minutes = clippedEnd.difference(start).inMinutes;
      return total + (minutes > 0 ? minutes : 0);
    });
  }

  List<LeaveRequest> get myRequests =>
      requests.where((r) => r.userId == currentUser?.id).toList()
        ..sort((a, b) => b.from.compareTo(a.from));

  Future<void> checkIn({
    double? latitude,
    double? longitude,
    String note = '',
  }) async {
    if (activeShift != null) return;
    final user = currentUser!;
    final token = _apiToken;
    if (token != null) {
      await api.post('/api/attendance/check-in', token: token);
      try {
        await refreshAttendance();
      } catch (_) {}
      if (activeShift == null) {
        attendance = [
          AttendanceRecord(
            id: 'server-${DateTime.now().microsecondsSinceEpoch}',
            userId: user.id,
            employeeName: user.name,
            checkIn: DateTime.now(),
            latitude: latitude,
            longitude: longitude,
            note: note,
          ),
          ...attendance,
        ];
        await _save();
      }
      return;
    }
    attendance = [
      AttendanceRecord(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}',
        userId: user.id,
        employeeName: user.name,
        checkIn: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        note: note,
      ),
      ...attendance,
    ];
    await _save();
  }

  Future<void> checkOut() async {
    final row = activeShift;
    if (row == null) return;
    final token = _apiToken;
    if (token != null) {
      await api.post('/api/attendance/check-out', token: token);
      try {
        await refreshAttendance();
      } catch (_) {}
      final stillActive = activeShift;
      if (stillActive?.id == row.id) {
        attendance = attendance
            .map(
              (a) => a.id == row.id ? a.copyWith(checkOut: DateTime.now()) : a,
            )
            .toList();
        await _save();
      }
      return;
    }
    attendance = attendance
        .map((a) => a.id == row.id ? a.copyWith(checkOut: DateTime.now()) : a)
        .toList();
    await _save();
  }

  Future<void> saveEmployee(EmployeeRecord item, {String? password}) async {
    final token = _apiToken;
    if (token != null && currentUser?.role == UserRole.admin) {
      final exists = employees.any((e) => e.id == item.id);
      if (exists) {
        await api.put(
          '/api/employees/${Uri.encodeComponent(item.id)}',
          token: token,
          body: {
            'displayName': item.name,
            'email': item.email,
            'department': item.department,
            'role': item.position,
          },
        );
      } else {
        if (password == null || password.length < 8) {
          throw const ApiException(
            'Mật khẩu nhân viên mới phải có ít nhất 8 ký tự.',
          );
        }
        final response = _apiObject(
          await api.post(
            '/api/employees',
            token: token,
            body: {
              'username': item.email.split('@').first,
              'email': item.email,
              'password': password,
              'displayName': item.name,
              'department': item.department,
              'role': 'Employee',
            },
          ),
        );
        final id = _pick(response, ['id', 'employeeId', 'userId']);
        if (id != null)
          item = EmployeeRecord(
            id: '$id',
            name: item.name,
            email: item.email,
            department: item.department,
            position: item.position,
            phone: item.phone,
          );
      }
      await refreshEmployees();
      return;
    }
    final exists = employees.any((e) => e.id == item.id);
    employees = exists
        ? employees.map((e) => e.id == item.id ? item : e).toList()
        : [item, ...employees];
    await _save();
  }

  Future<void> deleteEmployee(String id) async {
    if (_apiToken != null && currentUser?.role == UserRole.admin) {
      await api.delete(
        '/api/employees/${Uri.encodeComponent(id)}',
        token: _apiToken,
      );
      await refreshEmployees();
      return;
    }
    employees = employees.where((e) => e.id != id).toList();
    await _save();
  }

  Future<void> saveAttendance(AttendanceRecord item) async {
    attendance = attendance.map((a) => a.id == item.id ? item : a).toList();
    await _save();
  }

  Future<void> deleteAttendance(String id) async {
    attendance = attendance.where((a) => a.id != id).toList();
    await _save();
  }

  Future<void> createRequest(LeaveRequest item) async {
    requests = [item, ...requests];
    await _save();
  }

  Future<void> updateRequest(LeaveRequest item) async {
    requests = requests.map((r) => r.id == item.id ? item : r).toList();
    await _save();
  }

  Future<void> deleteRequest(String id) async {
    requests = requests.where((r) => r.id != id).toList();
    await _save();
  }

  int get todayCount => attendance
      .where((a) => a.checkIn.toLocal().toIso8601String().startsWith(_today))
      .length;
  int get pendingCount => requests.where((r) => r.status == 'Chờ duyệt').length;
}

dynamic _claimSuffix(Map<String, dynamic> claims, String suffix) {
  for (final entry in claims.entries) {
    if (entry.key.toLowerCase().endsWith('/$suffix')) return entry.value;
  }
  return null;
}
