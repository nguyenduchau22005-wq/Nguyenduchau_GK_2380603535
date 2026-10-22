enum UserRole { admin, employee, customer }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Quản trị viên',
    UserRole.employee => 'Nhân viên',
    UserRole.customer => 'Khách hàng',
  };

  static UserRole parse(String? value) => UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.employee,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.phone = '',
    this.department = 'Văn phòng',
    this.biometricEnabled = false,
    this.avatarBase64 = '',
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String passwordHash;
  final UserRole role;
  final String phone;
  final String department;
  final bool biometricEnabled;
  final String avatarBase64;

  AppUser copyWith({bool? biometricEnabled, String? avatarBase64}) => AppUser(
    id: id,
    name: name,
    username: username,
    email: email,
    passwordHash: passwordHash,
    role: role,
    phone: phone,
    department: department,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    avatarBase64: avatarBase64 ?? this.avatarBase64,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'passwordHash': passwordHash,
    'role': role.name,
    'phone': phone,
    'department': department,
    'biometricEnabled': biometricEnabled,
    'avatarBase64': avatarBase64,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String,
    role: UserRoleLabel.parse(json['role'] as String?),
    phone: json['phone'] as String? ?? '',
    department: json['department'] as String? ?? 'Văn phòng',
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    avatarBase64: json['avatarBase64'] as String? ?? '',
  );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.checkIn,
    this.checkOut,
    this.latitude,
    this.longitude,
    this.note = '',
  });

  final String id;
  final String userId;
  final String employeeName;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double? latitude;
  final double? longitude;
  final String note;

  int get minutesWorked => checkOut == null
      ? 0
      : checkOut!.difference(checkIn).inMinutes.clamp(0, 24 * 60);

  AttendanceRecord copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    bool clearCheckOut = false,
    double? latitude,
    double? longitude,
    String? note,
  }) => AttendanceRecord(
    id: id,
    userId: userId,
    employeeName: employeeName,
    checkIn: checkIn ?? this.checkIn,
    checkOut: clearCheckOut ? null : checkOut ?? this.checkOut,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'employeeName': employeeName,
    'checkIn': checkIn.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'note': note,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        userId: json['userId'] as String,
        employeeName: json['employeeName'] as String,
        checkIn: DateTime.parse(json['checkIn'] as String),
        checkOut: json['checkOut'] == null
            ? null
            : DateTime.parse(json['checkOut'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        note: json['note'] as String? ?? '',
      );
}

class EmployeeRecord {
  const EmployeeRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.position,
    required this.phone,
    this.active = true,
  });

  final String id;
  final String name;
  final String email;
  final String department;
  final String position;
  final String phone;
  final bool active;

  EmployeeRecord copyWith({
    String? name,
    String? email,
    String? department,
    String? position,
    String? phone,
    bool? active,
  }) => EmployeeRecord(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    department: department ?? this.department,
    position: position ?? this.position,
    phone: phone ?? this.phone,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'department': department,
    'position': position,
    'phone': phone,
    'active': active,
  };

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) => EmployeeRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    department: json['department'] as String,
    position: json['position'] as String,
    phone: json['phone'] as String? ?? '',
    active: json['active'] as bool? ?? true,
  );
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.category,
    required this.from,
    required this.to,
    required this.reason,
    this.status = 'Chờ duyệt',
  });

  final String id;
  final String userId;
  final String employeeName;
  final String category;
  final DateTime from;
  final DateTime to;
  final String reason;
  final String status;

  LeaveRequest copyWith({String? status}) => LeaveRequest(
    id: id,
    userId: userId,
    employeeName: employeeName,
    category: category,
    from: from,
    to: to,
    reason: reason,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'employeeName': employeeName,
    'category': category,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'reason': reason,
    'status': status,
  };

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as String,
    userId: json['userId'] as String,
    employeeName: json['employeeName'] as String,
    category: json['category'] as String,
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    reason: json['reason'] as String,
    status: json['status'] as String? ?? 'Chờ duyệt',
  );
}
