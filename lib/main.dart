import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'store.dart';
import 'screens/auth_screen.dart';
import 'screens/app_shell.dart';

const ink = Color(0xFF13233F);
const teal = Color(0xFF19A89A);
const canvas = Color(0xFFF4F7FB);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceStartup());
}

class AttendanceStartup extends StatefulWidget {
  const AttendanceStartup({super.key});

  @override
  State<AttendanceStartup> createState() => _AttendanceStartupState();
}

class _AttendanceStartupState extends State<AttendanceStartup> {
  late final AttendanceStore _store = AttendanceStore();
  Object? _startupError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await initializeDateFormatting('vi');
      await _store.initialize();
      if (!mounted) return;
      setState(() {
        _startupError = null;
        _ready = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _startupError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chấm công Hậu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
      ),
      home: _AttendanceHome(
        store: _store,
        ready: _ready,
        startupError: _startupError,
        onRetry: () {
          setState(() => _startupError = null);
          _initialize();
        },
      ),
    );
  }
}

class _AttendanceHome extends StatelessWidget {
  const _AttendanceHome({
    required this.store,
    required this.ready,
    required this.startupError,
    required this.onRetry,
  });

  final AttendanceStore store;
  final bool ready;
  final Object? startupError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (ready) {
        return store.currentUser == null
            ? AuthScreen(store: store)
            : AppShell(store: store);
      }

      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  startupError == null
                      ? 'Đang chuẩn bị dữ liệu chấm công…'
                      : 'Không thể khởi động ứng dụng',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (startupError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '$startupError',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C1B3453),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (trailing != null) trailing!,
    ],
  );
}

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Chào buổi sáng';
  if (hour < 17) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1)
    return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
}
