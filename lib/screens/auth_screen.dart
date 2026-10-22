import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store});
  final AttendanceStore store;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _checkingApi = false;
  bool? _apiConnected;
  String? _apiMessage;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_account.text.trim().isEmpty || _password.text.isEmpty)
      return _message('Nhập tên đăng nhập/email và mật khẩu.');
    setState(() => _busy = true);
    try {
      final result = await widget.store.startLogin(
        _account.text,
        _password.text,
      );
      if (!mounted) return;
      var user = result.user;
      if (user == null && result.otpRequired) {
        setState(() => _busy = false);
        final code = await _otpDialog(
          'Xác minh đăng nhập',
          result.message.isEmpty
              ? 'Nhập mã OTP đã gửi đến email của bạn.'
              : result.message,
        );
        if (!mounted || code == null) return;
        setState(() => _busy = true);
        user = await widget.store.verifyLoginOtp(code);
      }
      if (!mounted) return;
      if (user != null) {
        FocusManager.instance.primaryFocus?.unfocus();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        await widget.store.setSession(user);
      } else {
        _message('Máy chủ chưa xác nhận phiên đăng nhập.');
      }
    } catch (error) {
      if (!mounted) return;
      _message('Không thể đăng nhập: $error');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _checkApiConnection() async {
    if (_checkingApi) return;
    setState(() {
      _checkingApi = true;
      _apiMessage = null;
    });
    try {
      await widget.store.api.get('/api');
      if (!mounted) return;
      setState(() {
        _apiConnected = true;
        _apiMessage = 'Đã kết nối được máy chủ API.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _apiConnected = false;
        _apiMessage = '$error';
      });
    } finally {
      if (mounted) setState(() => _checkingApi = false);
    }
  }

  Future<void> _biometricLogin(String method) async {
    final user = widget.store.findAccount(_account.text);
    if (user == null) {
      return _message('Nhập tên đăng nhập hoặc email trước.');
    }
    if (!user.biometricEnabled) {
      return _message(
        'Hãy đăng nhập bằng mật khẩu trước, rồi bật đăng nhập khuôn mặt/vân tay trong mục Tài khoản.',
      );
    }
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Xác nhận bằng $method để đăng nhập',
        biometricOnly: true,
      );
      if (ok && mounted) {
        await widget.store.setSession(user);
      }
    } on LocalAuthException catch (error) {
      _message(
        'Xác thực $method không thành công: ${error.description ?? error.code.name}',
      );
    } catch (_) {
      _message('Không mở được xác thực sinh trắc học trên điện thoại.');
    }
  }

  Future<String?> _otpDialog(String title, String helper) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpEntryDialog(title: title, helper: helper),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _register() async {
    final created = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegisterSheet(store: widget.store),
    );
    if (created != null && mounted) {
      _account.text = created;
      _message(
        'Xác minh email thành công. Hãy đăng nhập bằng mật khẩu vừa tạo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [teal, Color(0xFF63D6B5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3319A89A),
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HẬU WORK',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'CHẤM CÔNG THÔNG MINH',
                      style: TextStyle(
                        color: Color(0xFF73849B),
                        fontSize: 9,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  Icon(
                    _apiConnected == true
                        ? Icons.cloud_done_rounded
                        : _apiConnected == false
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_outlined,
                    color: _apiConnected == true
                        ? const Color(0xFF16845E)
                        : _apiConnected == false
                        ? const Color(0xFFC34B4B)
                        : teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kết nối máy chủ',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_apiMessage != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _apiMessage!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _apiConnected == true
                                  ? const Color(0xFF16845E)
                                  : const Color(0xFFC34B4B),
                              fontSize: 12,
                            ),
                          ),
                        ] else
                          const Text(
                            'Chạm để kiểm tra trạng thái API',
                            style: TextStyle(
                              color: Color(0xFF73849B),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: _checkingApi ? null : _checkApiConnection,
                    child: _checkingApi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_apiConnected == null ? 'Kiểm tra' : 'Thử lại'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Sử dụng tài khoản nhân viên của bạn.'),
                  const SizedBox(height: 19),
                  TextField(
                    controller: _account,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập hoặc email',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _message(
                        'Khôi phục mật khẩu sẽ khả dụng khi kết nối máy chủ email.',
                      ),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _login,
                      icon: _busy
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login_rounded),
                      label: const Text(
                        'Đăng nhập với OTP',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _biometricLogin('khuôn mặt'),
                          icon: const Icon(
                            Icons.face_retouching_natural_rounded,
                          ),
                          label: const Text('Khuôn mặt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF176E70),
                            side: const BorderSide(color: Color(0xFFB8DCD7)),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _biometricLogin('vân tay'),
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Vân tay'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF176E70),
                            side: const BorderSide(color: Color(0xFFB8DCD7)),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bật sinh trắc học trong mục Tài khoản trước. Android sẽ mở phương thức đã cài trên điện thoại.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF8290A2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD5EAE5)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    foregroundColor: teal,
                    child: Icon(Icons.person_add_alt_1_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chưa có tài khoản?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Đăng ký bằng email công ty',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF68788B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _register,
                    child: const Text('Đăng ký'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: teal),
                SizedBox(width: 6),
                Text(
                  'AN TOÀN · MINH BẠCH · ĐÚNG GIỜ',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    color: Color(0xFF8B98A9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _RegisterSheet extends StatefulWidget {
  const _RegisterSheet({required this.store});
  final AttendanceStore store;
  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  UserRole _role = UserRole.employee;
  String _avatarBase64 = '';

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 78,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      setState(() => _avatarBase64 = base64Encode(bytes));
    } catch (_) {
      _toast('Không mở được thư viện ảnh trên điện thoại.');
    }
  }

  Future<void> _submit() async {
    if (_avatarBase64.isEmpty) return _toast('Vui lòng chọn ảnh đại diện.');
    if (_avatarBase64.length < 100 || _avatarBase64.length > 1400000) {
      return _toast('Ảnh đại diện không hợp lệ hoặc quá lớn. Hãy chọn ảnh khác.');
    }
    final email = _email.text.trim();
    final username = _username.text.trim();
    if (_name.text.trim().isEmpty ||
        !RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(username) ||
        !email.contains('@') ||
        _pass.text.length < 8)
      return _toast(
        'Nhập đủ thông tin. Tên đăng nhập cần 3–40 ký tự (chữ, số, . _ -) và mật khẩu ít nhất 8 ký tự.',
      );
    setState(() => _busy = true);
    try {
      await widget.store.beginRegistration(
        username: username,
        name: _name.text,
        email: _email.text,
        password: _pass.text,
        department: 'Văn phòng',
        role: _role,
        avatarBase64: _avatarBase64,
      );
      if (!mounted) return;
      final entered = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _OtpEntryDialog(
          title: 'Xác minh email',
          helper: 'Nhập mã xác minh được gửi đến ${_email.text.trim()}.',
        ),
      );
      if (!mounted) return;
      if (entered == null) {
        setState(() => _busy = false);
        return;
      }
      await widget.store.finishRegistration(
        code: entered,
        username: username,
        name: _name.text,
        email: _email.text,
        password: _pass.text,
        phone: _phone.text,
        role: _role,
        avatarBase64: _avatarBase64,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.pop(context, username);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Không thể tạo tài khoản: $error');
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE3EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tạo tài khoản',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Tài khoản nhân viên sẽ được kích hoạt sau khi xác minh email.',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  InkWell(
                    onTap: _pickAvatar,
                    borderRadius: BorderRadius.circular(40),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFE8EEFF),
                      backgroundImage: _avatarBase64.isEmpty
                          ? null
                          : MemoryImage(base64Decode(_avatarBase64)),
                      child: _avatarBase64.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: Color(0xFF52699A),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _avatarBase64.isEmpty
                          ? 'Chọn ảnh đại diện *'
                          : 'Đã chọn ảnh đại diện',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_avatarBase64.isEmpty ? 'Chọn ảnh' : 'Đổi ảnh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _username,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập (3–40 ký tự)',
                  helperText: 'Dùng tên này để đăng nhập, không dùng Gmail.',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Vai trò tài khoản',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.employee,
                    child: Text('Nhân viên'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.customer,
                    child: Text('Khách hàng'),
                  ),
                ],
                onChanged: (role) {
                  if (role != null) setState(() => _role = role);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại (không bắt buộc)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu (ít nhất 8 ký tự)',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 15),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Xác minh & tạo tài khoản'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OtpEntryDialog extends StatefulWidget {
  const _OtpEntryDialog({required this.title, required this.helper});

  final String title;
  final String helper;

  @override
  State<_OtpEntryDialog> createState() => _OtpEntryDialogState();
}

class _OtpEntryDialogState extends State<_OtpEntryDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.helper),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Mã OTP',
            prefixIcon: Icon(Icons.password_rounded),
          ),
          onSubmitted: (_) => Navigator.pop(context, _code.text.trim()),
        ),
        const Text(
          'Mã có hiệu lực theo thời hạn do máy chủ quy định.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _code.text.trim()),
        child: const Text('Xác nhận'),
      ),
    ],
  );
}
