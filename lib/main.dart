import 'holidays_management_page.dart';
import 'office_employees_page.dart';
import 'password_change_page.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login_page.dart';
import 'manager_management_page.dart';
import 'attendance_reports_page.dart';
import 'office_locations_page.dart';
import 'employee_transfer_page.dart';
import 'employee_add_page.dart';
import 'password_reset_page.dart';
import 'employee_transfer_history_page.dart';
import 'device_identity_service.dart';
import 'device_requests_page.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rbnktsiuimiuvlsukhcc.supabase.co',
    publishableKey: 'sb_publishable_I5Ae8NCwuXn8AoR6tZarog__ZyKF1f6',
  );

  runApp(const AttendanceApp());
}

// ============================================================
// التطبيق الرئيسي
// ============================================================

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  Widget _initialPage() {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return LoginPage(homeBuilder: () => const RoleLandingPage());
    }

    return const RoleLandingPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'الحضور والانصراف',
      locale: const Locale('ar'),
supportedLocales: const [
  Locale('ar'),
  Locale('en'),
],
localizationsDelegates: const [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF145A46)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      home: _initialPage(),
    );
  }
}

// ============================================================
// توجيه المستخدم حسب الصلاحية
// ============================================================

class RoleLandingPage extends StatefulWidget {
  const RoleLandingPage({super.key});

  @override
  State<RoleLandingPage> createState() => _RoleLandingPageState();
}

class _RoleLandingPageState extends State<RoleLandingPage> {
  bool _isLoading = true;
  String? _error;
  String? _role;
  int? _officeId;
  String _employeeName = '';

  SupabaseClient get _supabase => Supabase.instance.client;
  @override
  void initState() {
    super.initState();
    _loadAccountRole();
  }

  Future<void> _loadAccountRole() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = _supabase.auth.currentUser;
    if (user == null) {
      await _returnToLogin();
      return;
    }

    try {
      // التحقق من أن حساب الموظف موجود ونشط.
      final employee = await _supabase
          .from('employees')
          .select('full_name, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (employee == null || employee['is_active'] != true) {
        await _returnToLogin();
        return;
      }

      // كل مستخدم يستطيع قراءة سجل صلاحياته فقط.
      final roleRecord = await _supabase
          .from('user_roles')
          .select('role, office_id, is_active')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      String? assignedRole;
      int? assignedOfficeId;

      if (roleRecord != null && roleRecord['is_active'] == true) {
        final value = roleRecord['role']?.toString();

        if (value == 'super_admin' ||
            value == 'admin' ||
            value == 'office_manager') {
          assignedRole = value;
        }

        final rawOfficeId = roleRecord['office_id'];
        if (rawOfficeId is num) {
          assignedOfficeId = rawOfficeId.toInt();
        } else if (rawOfficeId != null) {
          assignedOfficeId = int.tryParse(rawOfficeId.toString());
        }

        if (assignedRole == 'office_manager' && assignedOfficeId == null) {
          throw Exception('حساب مدير المكتب لا يحتوي على مكتب محدد.');
        }
      }

      setState(() {
        _employeeName = employee['full_name']?.toString() ?? '';
        _role = assignedRole;
        _officeId = assignedOfficeId;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ROLE ROUTING ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحميل صلاحيات الحساب. تحقق من الاتصال والصلاحيات.';
        _isLoading = false;
      });
    }
  }

  Future<void> _returnToLogin() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('SIGN OUT ERROR: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(homeBuilder: () => const RoleLandingPage()),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_error != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('التحقق من الحساب'),
            backgroundColor: const Color(0xFF145A46),
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 52,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadAccountRole,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: _returnToLogin,
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // المستخدم الذي لا يملك دورًا إداريًا يذهب إلى شاشة الموظف.
    if (_role == null) {
      return const AttendanceHomePage();
    }

    return AdminDashboardPage(
      role: _role!,
      officeId: _officeId,
      employeeName: _employeeName,
      onLogout: _returnToLogin,
    );
  }
}

// ============================================================
// لوحة المديرين - قراءة إحصائيات المكاتب والدوام
// ============================================================

class AdminDashboardPage extends StatefulWidget {
  final String role;
  final int? officeId;
  final String employeeName;

 final Future<void> Function() onLogout;

  const AdminDashboardPage({
    super.key,
    required this.role,
    required this.officeId,
    required this.employeeName,
    required this.onLogout,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = true;
  String? _error;

  int _activeEmployees = 0;
  int _presentEmployees = 0;
  int _notCheckedIn = 0;
  int _completedDepartures = 0;
  int _openAttendances = 0;
  int _officeCount = 0;

  List<Map<String, dynamic>> _officeSummaries = [];
List<Map<String, dynamic>> _presentEmployeeDetails = [];
DateTime _historyDate = DateTime.now();
bool _historyLoading = false;
String _historySearch = '';

List<Map<String, dynamic>> _historyEmployeeDetails = [];
  SupabaseClient get _supabase => Supabase.instance.client;
   String get _today {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get _roleTitle {
    switch (widget.role) {
      case 'super_admin':
        return 'مدير النظام الرئيسي';
      case 'admin':
        return 'مدير النظام';
      case 'office_manager':
        return 'مدير المكتب';
      default:
        return 'لوحة الإدارة';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // قراءة الموظفين الذين تسمح بها سياسات RLS لهذا المدير.
      final List<Map<String, dynamic>> employees = widget.officeId == null
          ? await _supabase
                .from('employees')
                .select('id, full_name, employee_number, office_id, is_active')
          : await _supabase
                .from('employees')
                .select('id, full_name, employee_number, office_id, is_active')
                .eq('office_id', widget.officeId!);

      // قراءة مكاتب المدير. مدير المكتب يرى مكتبه فقط.
      final List<Map<String, dynamic>> offices = widget.officeId == null
          ? await _supabase
                .from('offices')
                .select('id, office_name')
                .order('office_name')
          : await _supabase
                .from('offices')
                .select('id, office_name')
                .eq('id', widget.officeId!);

      // قراءة سجلات اليوم فقط.
      final List<Map<String, dynamic>> attendance = widget.officeId == null
          ? await _supabase
                .from('attendance_records')
            .select('employee_id, office_id, attendance_time, departure_time')
                .eq('work_date', _today)
          : await _supabase
                .from('attendance_records')
               .select('employee_id, office_id, attendance_time, departure_time')
                .eq('work_date', _today)
                .eq('office_id', widget.officeId!);

      final activeEmployees = employees
          .where((row) => row['is_active'] == true)
          .toList();

      final activeEmployeeIds = activeEmployees
          .map((row) => row['id'].toString())
          .toSet();
      // احتساب سجلات موظفي الحسابات النشطة فقط.
      final todayAttendance = attendance

          .where(
            (row) => activeEmployeeIds.contains(row['employee_id'].toString()),
          )
          .toList();
final presentDetails = todayAttendance.map((record) {
  final employee = activeEmployees.firstWhere(
    (row) => row['id'].toString() == record['employee_id'].toString(),
    orElse: () => <String, dynamic>{},
  );

  return <String, dynamic>{
    'full_name': employee['full_name']?.toString() ?? 'موظف غير معروف',
    'employee_number': employee['employee_number']?.toString() ?? '',
    'attendance_time': record['attendance_time'],
    'departure_time': record['departure_time'],
  };
}).toList();
      final completed = todayAttendance
          .where((row) => row['departure_time'] != null)
          .length;

      final summaries = <Map<String, dynamic>>[];

      for (final office in offices) {
        final officeId = office['id'].toString();

        final officeEmployees = activeEmployees
            .where((row) => row['office_id'].toString() == officeId)
            .length;

        final officeAttendance = todayAttendance
            .where((row) => row['office_id'].toString() == officeId)
            .length;

        summaries.add({
          'office_name': office['office_name']?.toString() ?? 'مكتب',
          'employees': officeEmployees,
          'present': officeAttendance,
        });
      }

      if (!mounted) return;

      setState(() {
        _activeEmployees = activeEmployees.length;
        _presentEmployees = todayAttendance.length;
        _notCheckedIn = (_activeEmployees - _presentEmployees)
            .clamp(0, _activeEmployees)
            .toInt();
        _completedDepartures = completed;
        _openAttendances = todayAttendance.length - completed;
        _officeCount = offices.length;
        _officeSummaries = summaries;
_presentEmployeeDetails = presentDetails;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ADMIN DASHBOARD ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحميل إحصائيات الإدارة. تحقق من صلاحيات القراءة.';
        _isLoading = false;
      });
    }
  }
Future<void> _loadHistory() async {
  setState(() {
    _historyLoading = true;
  });

  try {
    final dateKey =
        '${_historyDate.year}-'
        '${_historyDate.month.toString().padLeft(2, '0')}-'
        '${_historyDate.day.toString().padLeft(2, '0')}';

    final employeesQuery = _supabase
        .from('employees')
        .select('id, full_name, employee_number, is_active');

    final employees = widget.officeId == null
        ? await employeesQuery
        : await employeesQuery.eq('office_id', widget.officeId!);

    final attendanceQuery = _supabase
        .from('attendance_records')
        .select('employee_id, attendance_time, departure_time')
        .eq('work_date', dateKey);

    final attendance = widget.officeId == null
        ? await attendanceQuery
        : await attendanceQuery.eq('office_id', widget.officeId!);

    final activeEmployees = employees
        .where((e) => e['is_active'] == true)
        .toList();

    final details = attendance.map((record) {
      final employee = activeEmployees.firstWhere(
        (e) => e['id'].toString() ==
            record['employee_id'].toString(),
        orElse: () => <String, dynamic>{},
      );

      return <String, dynamic>{
        'full_name': employee['full_name']?.toString() ?? 'موظف غير معروف',
        'employee_number':
            employee['employee_number']?.toString() ?? '',
        'attendance_time': record['attendance_time'],
        'departure_time': record['departure_time'],
      };
    }).toList();

    if (!mounted) return;

    setState(() {
      _historyEmployeeDetails = details;
      _historyLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _historyLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر تحميل سجل الحضور: $e')),
    );
  }
}
Future<void> _exportHistoryToExcel() async {
  if (_historyEmployeeDetails.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا توجد بيانات لتصديرها. اعرض سجل الحضور أولاً.'),
      ),
    );
    return;
  }

  try {
    final excel = Excel.createExcel();
    final sheet = excel['سجل الحضور'];

    sheet.appendRow([
      TextCellValue('اسم الموظف'),
      TextCellValue('الرقم الوظيفي'),
      TextCellValue('التاريخ'),
      TextCellValue('وقت الحضور'),
      TextCellValue('وقت الانصراف'),
    ]);

    final dateKey =
        '${_historyDate.year}-'
        '${_historyDate.month.toString().padLeft(2, '0')}-'
        '${_historyDate.day.toString().padLeft(2, '0')}';

    for (final employee in _historyEmployeeDetails) {
      sheet.appendRow([
        TextCellValue(employee['full_name'].toString()),
        TextCellValue(employee['employee_number'].toString()),
        TextCellValue(dateKey),
        TextCellValue(
          _formatAttendanceTime(employee['attendance_time']),
        ),
        TextCellValue(
          _formatAttendanceTime(employee['departure_time']),
        ),
      ]);
    }

    final bytes = excel.encode();

    if (bytes == null) {
      throw Exception('تعذر إنشاء ملف Excel');
    }

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/attendance_$dateKey.xlsx',
    );

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'سجل الحضور بتاريخ $dateKey',
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر تصدير ملف Excel: $e'),
      ),
    );
  }
}
  Widget _metricCard({
    required double width,
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _featureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F1ED),
          child: Icon(icon, color: const Color(0xFF145A46)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
  String _formatAttendanceTime(dynamic value) {
    if (value == null) return 'لم يسجل بعد';

    final raw = value.toString();
    final parsed = DateTime.tryParse(raw);

    if (parsed != null) {
      final local = parsed.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  bool _isLate(dynamic value) {
    if (value == null) return false;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return false;

    final local = parsed.toLocal();

    return local.hour > 8 ||
        (local.hour == 8 && local.minute > 15);
  }

  @override  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = (width - 56) / 2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(
          title: const Text('لوحة الإدارة'),
          backgroundColor: const Color(0xFF145A46),
          foregroundColor: Colors.white,
                centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => widget.onLogout(),
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDashboard,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF145A46),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Colors.white,
                            size: 38,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'مرحبًا بك',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.employeeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _roleTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'ملخص الدوام اليوم',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _metricCard(
                          width: cardWidth,
                          title: 'الموظفون النشطون',
                          value: _activeEmployees,
                          icon: Icons.people_alt_outlined,
                          color: const Color(0xFF145A46),
                        ),
                        _metricCard(
                          width: cardWidth,
                          title: 'سجلوا الحضور اليوم',
                          value: _presentEmployees,
                          icon: Icons.how_to_reg,
                          color: Colors.green.shade700,
                        ),
                        _metricCard(
                          width: cardWidth,
                          title: 'لم يسجلوا الحضور',
                          value: _notCheckedIn,
                          icon: Icons.person_off_outlined,
                          color: Colors.orange.shade800,
                        ),
                        _metricCard(
                          width: cardWidth,
                          title: 'سجلوا الانصراف',
                          value: _completedDepartures,
                          icon: Icons.logout,
                          color: Colors.blue.shade700,
                        ),
                        _metricCard(
                          width: cardWidth,
                          title: 'حضور دون انصراف',
                          value: _openAttendances,
                          icon: Icons.pending_actions,
                          color: Colors.deepOrange.shade700,
                        ),
                        _metricCard(
                          width: cardWidth,
                          title: 'المكاتب المتاحة',
                          value: _officeCount,
                          icon: Icons.business_outlined,
                          color: Colors.indigo.shade700,
                        ),
                      ],
                    ),
       const SizedBox(height: 24),
const Text(     
     'الموظفون الذين سجلوا الحضور اليوم',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),
const SizedBox(height: 10),

if (_presentEmployeeDetails.isEmpty)
  const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('لا يوجد موظفون سجلوا الحضور اليوم.'),
    ),
  )
else
  ..._presentEmployeeDetails.map((employee) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(employee['full_name'].toString()),
              subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رقم الموظف: ${employee['employee_number']}',
            ),
            Text(
              'الحضور: ${_formatAttendanceTime(employee['attendance_time'])}',
            ),
            if (_isLate(employee['attendance_time']))
              const Text(
                'الحالة: متأخر',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                'الحالة: حاضر في الموعد',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              'الانصراف: ${_formatAttendanceTime(employee['departure_time'])}',
            ),
          ],
        ),
        isThreeLine: true,      ),
    );
  }),

const SizedBox(height: 24),
const Text(
                      'ملخص المكاتب',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_officeSummaries.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('لا توجد مكاتب متاحة لهذا الحساب.'),
                        ),
                      )
                    else
                      ..._officeSummaries.map(
                        (office) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.business,
                              color: Color(0xFF145A46),
                            ),
                            title: Text(office['office_name'].toString()),
                            subtitle: Text(
                              'الموظفون النشطون: ${office['employees']}',
                            ),
                            trailing: Text(
                              '${office['present']} حاضر',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF145A46),
                              ),
                            ),
                          ),
                        ),
                      ),
const SizedBox(height: 24),

const Text(
  'سجل الحضور السابق',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 12),

Card(
  elevation: 0,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: _historyDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              helpText: 'اختر تاريخ الحضور',
              cancelText: 'إلغاء',
              confirmText: 'اختيار',
            );

            if (selectedDate != null) {
              setState(() {
                _historyDate = selectedDate;
              });
            }
          },
          icon: const Icon(Icons.calendar_month),
          label: Text(
            'التاريخ: ${_historyDate.day}/'
            '${_historyDate.month}/${_historyDate.year}',
          ),
        ),

        const SizedBox(height: 12),

       ElevatedButton.icon(
  onPressed: _historyLoading ? null : _loadHistory,
  icon: const Icon(Icons.search),
  label: const Text('عرض سجل الحضور'),
),

const SizedBox(height: 10),

OutlinedButton.icon(
  onPressed: _historyLoading ||
          _historyEmployeeDetails.isEmpty
      ? null
      : _exportHistoryToExcel,
  icon: const Icon(Icons.file_download),
  label: const Text('تصدير إلى Excel'),
),
        const SizedBox(height: 12),

        TextField(
          onChanged: (value) {
            setState(() {
              _historySearch = value.trim().toLowerCase();
            });
          },
          decoration: const InputDecoration(
            labelText: 'البحث باسم الموظف أو رقمه',
            prefixIcon: Icon(Icons.person_search),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
  ),
),

const SizedBox(height: 12),

if (_historyLoading)
  const Center(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: CircularProgressIndicator(),
    ),
  )
else
  ..._historyEmployeeDetails.where((employee) {
    final name =
        employee['full_name'].toString().toLowerCase();
    final number =
        employee['employee_number'].toString().toLowerCase();

    return name.contains(_historySearch) ||
        number.contains(_historySearch);
  }).map((employee) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(employee['full_name'].toString()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رقم الموظف: ${employee['employee_number']}',
            ),
            Text(     
              'الحضور: ${_formatAttendanceTime(employee['attendance_time'])}',
            ),
            if (_isLate(employee['attendance_time']))
              const Text(
                'الحالة: متأخر',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                'الحالة: حاضر في الموعد',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                        ),
            Text(              'الانصراف: ${_formatAttendanceTime(employee['departure_time'])}',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }),

if (!_historyLoading && _historyEmployeeDetails.isEmpty)
  const Padding(
    padding: EdgeInsets.all(12),
    child: Text(
      'اختر التاريخ واضغط على عرض سجل الحضور.',
      textAlign: TextAlign.center,
    ),
  ),

const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    const Text(
                      'إدارة النظام',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _featureTile(
                      icon: Icons.people_outline,
                      title: 'إدارة الموظفين',
                      subtitle: 'عرض ومراجعة بيانات الموظفين',
                    onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OfficeEmployeesPage(
        officeId: widget.officeId,
        role: widget.role,
      ),
    ),
  );
},                    ),
                  if (widget.role == 'super_admin')
  _featureTile(
    icon: Icons.business_outlined,
    title: 'إدارة مواقع المكاتب',
    subtitle: 'تحديد إحداثيات المكاتب ونطاق GPS',
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OfficeLocationsPage(),
        ),
      );
    },
                    ),
                    if (widget.role == 'super_admin')
                      _featureTile(
                        icon: Icons.swap_horiz,
                        title: 'نقل الموظفين بين المكاتب',
                        subtitle: 'نقل الموظف إلى مكتب آخر مع حفظ سجل النقل',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EmployeeTransferPage(),
                            ),
                          );
                        },
                      ),
                    if (widget.role == 'super_admin')
                      _featureTile(
                        icon: Icons.history,
                        title: 'سجل تنقلات الموظفين',
                        subtitle: 'عرض جميع عمليات نقل الموظفين السابقة',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EmployeeTransferHistoryPage(),
                            ),
                          );
                        },
                      ),                    _featureTile(
                      icon: Icons.event_available,
                      title: 'إدارة العطلات الرسمية',
                      subtitle: 'إضافة العطلات وتعديلها وحذفها',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HolidaysManagementPage(
                              role: widget.role,
                              officeId: widget.officeId,
                            ),
                          ),
                        );
                      },
                    ),                    _featureTile(
                      icon: Icons.insert_chart_outlined,
                      title: 'تقارير الحضور والانصراف',
                      subtitle: 'التقارير اليومية والشهرية',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttendanceReportsPage(
                              role: widget.role,
                              officeId: widget.officeId,
                            ),
                          ),
                        );
                      },
                    ),
                                    if (widget.role == 'super_admin' ||
                        widget.role == 'office_manager')
                      _featureTile(
                        icon: Icons.lock_reset,
                        title: 'إعادة تعيين كلمات المرور',
                        subtitle: 'إنشاء كلمة مرور مؤقتة للموظفين',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PasswordResetPage(
                                role: widget.role,
                                officeId: widget.officeId,
                              ),
                            ),
                          );
                        },
                      ),
                    if (widget.role == 'super_admin')
                      _featureTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'إدارة المديرين والصلاحيات',
                        subtitle: 'إضافة المديرين وتحديد نطاق عملهم',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManagerManagementPage(),
                            ),
                          );
                        },
                      ),
                 if (widget.role == 'super_admin' ||
    widget.role == 'office_manager')
  _featureTile(
    icon: Icons.person_add_alt_1,
    title: 'إضافة موظف جديد',
    subtitle: 'تسجيل موظف وإنشاء حساب دخول',
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeAddPage(
            role: widget.role,
            officeId: widget.officeId,
          ),
        ),
      );
    },
  ),
      _featureTile(
  icon: Icons.phonelink_lock,
  title: 'طلبات اعتماد الهواتف',
  subtitle: 'مراجعة طلبات اعتماد هواتف الموظفين',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DeviceRequestsPage(),
      ),
    );
  },
),                    OutlinedButton.icon(
                      onPressed: _loadDashboard,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث الإحصائيات'),
                 
                                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============================================================
// شاشة الحضور والانصراف
// ============================================================

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  final LocalAuthentication auth = LocalAuthentication();

  bool checkedIn = false;
  bool checkedOut = false;
  bool isProcessing = false;
  bool isLoadingStatus = true;

  String employeeName = '';
String officeName = '';
String? officeLogoUrl;
String? deviceId;
String? approvedDeviceId;
String? deviceRequestStatus;
String? requestDeviceId;
bool isLoadingDeviceStatus = true;
bool isRequestingDevice = false;

  SupabaseClient get supabase => Supabase.instance.client;

  // التاريخ المحلي للجهاز. يجب أن يكون مضبوطًا على توقيت ليبيا.
  String get currentDate {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get displayDate {
    final now = DateTime.now();

    return '${now.year}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get currentTime {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

 @override
void initState() {
  super.initState();
  _loadTodayAttendance();
  _loadDeviceStatus();
}
  // ==========================================================
  // التحقق من المستخدم وتحميل حالة دوامه اليوم
  // ==========================================================

  Future<void> _loadTodayAttendance() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      await _returnToLogin();
      return;
    }

    try {
      // التحقق من حساب الموظف
     final profile = await supabase
    .from('employees')
    .select('full_name, is_active, office_id')
    .eq('id', user.id)
    .maybeSingle();
      if (!mounted) return;

      if (profile == null || profile['is_active'] != true) {
        await _returnToLogin();
        return;
      }

      // قراءة سجل الموظف لهذا اليوم
      final record = await supabase
          .from('attendance_records')
          .select('attendance_time, departure_time')
          .eq('employee_id', user.id)
          .eq('work_date', currentDate)
              .maybeSingle();

  final officeId = profile['office_id'];
      final office = officeId == null
          ? null
          : await supabase
              .from('offices')
              .select('office_name, logo_url')
              .eq('id', officeId)
              .maybeSingle();
debugPrint('OFFICE DATA: $office');
debugPrint('OFFICE LOGO URL: ${office?['logo_url']}');
      if (!mounted) return;
   

      setState(() {
  employeeName = profile['full_name']?.toString() ?? '';
  officeName = office?['office_name']?.toString() ?? '';
  officeLogoUrl = office?['logo_url']?.toString();

        checkedIn = record != null;

        checkedOut = record != null && record['departure_time'] != null;

        isLoadingStatus = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ATTENDANCE LOAD ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        isLoadingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text('تفاصيل الخطأ: $e'),
        ),
      );
    }
  }
Future<void> _loadDeviceStatus() async {
  try {
    final id = await DeviceIdentityService.getOrCreateDeviceId();

    final result = await supabase.rpc(
      'get_employee_device_status',
    );

    if (!mounted) return;

   setState(() {
  deviceId = id;
  approvedDeviceId = result['approved_device_id']?.toString();
  deviceRequestStatus = result['request_status']?.toString();
  requestDeviceId = result['request_device_id']?.toString();
  isLoadingDeviceStatus = false;
});
  } catch (e) {
    debugPrint('DEVICE STATUS ERROR: $e');

    if (!mounted) return;

    setState(() {
      isLoadingDeviceStatus = false;
    });
  }
}
Future<void> _requestDeviceApproval() async {
  if (deviceId == null || isRequestingDevice) return;

  setState(() {
    isRequestingDevice = true;
  });

  try {
    final result = await supabase.rpc(
      'request_employee_device',
      params: {
        'p_device_id': deviceId,
        'p_device_name': 'هاتف الموظف',
      },
    );

    if (!mounted) return;

    await _loadDeviceStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'تم إرسال الطلب',
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر إرسال الطلب: $e')),
    );
  } finally {
    if (mounted) {
      setState(() {
        isRequestingDevice = false;
      });
    }
  }
}
  // ==========================================================
  // العودة إلى تسجيل الدخول
  // ==========================================================

  Future<void> _returnToLogin() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {
      // متابعة العودة إلى شاشة الدخول
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(homeBuilder: () => const RoleLandingPage()),
      ),
      (route) => false,
    );
  }

  Future<void> logout() async {
    await _returnToLogin();
  }

  // ==========================================================
  // التحقق من البصمة
  // ==========================================================

 Future<bool> authenticateWithBiometrics() async {
  try {
    final availableBiometrics = await auth.getAvailableBiometrics();

    // إذا لم توجد بصمة مفعّلة، نسمح بالتسجيل
    // لأن الموظف سبق أن سجل دخوله برقم الموظف وكلمة المرور.
    if (availableBiometrics.isEmpty) {
      return true;
    }

    // إذا كانت البصمة متاحة، نطلب التحقق منها.
    return await auth.authenticate(
      localizedReason: 'أكد هويتك لتسجيل الحضور أو الانصراف',
      biometricOnly: true,
    );
  } catch (e) {
    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تعذر التحقق بالبصمة. حاول مرة أخرى.'),
      ),
    );
      return false;
    }
  }

  // ==========================================================
  // تسجيل الحضور أو الانصراف في قاعدة البيانات
  // ==========================================================

  Future<void> registerAttendance(bool isCheckIn) async {
    if (isProcessing || isLoadingStatus) return;

    if (isCheckIn && checkedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل الحضور مسبقًا')));
      return;
    }

    if (!isCheckIn && !checkedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب تسجيل الحضور أولًا')));
      return;
    }

    if (!isCheckIn && checkedOut) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل الانصراف مسبقًا')));
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // التحقق من البصمة قبل إرسال الطلب إلى قاعدة البيانات
      final authenticated = await authenticateWithBiometrics();

      if (!mounted) return;

      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم التسجيل لأن التحقق بالبصمة لم ينجح.'),
          ),
        );
        return;
      }

      // استدعاء دالة الحضور أو دالة الانصراف في Supabase
      final currentDeviceId =
    await DeviceIdentityService.getOrCreateDeviceId();

final result = await supabase.rpc(
  isCheckIn ? 'register_attendance' : 'register_departure',
  params: {
    'p_device_id': currentDeviceId,
  },
);
      if (!mounted) return;

      // إعادة قراءة سجل اليوم من قاعدة البيانات
      await _loadTodayAttendance();

      if (!mounted) return;

      final message = result is Map ? result['message']?.toString() : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??
                (isCheckIn
                    ? 'تم تسجيل الحضور بنجاح'
                    : 'تم تسجيل الانصراف بنجاح'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();
      debugPrint('ATTENDANCE RPC ERROR: $errorText');
      String message;

      if (errorText.contains('تم تسجيل الحضور مسبقاً')) {
        message = 'تم تسجيل الحضور مسبقًا.';
      } else if (errorText.contains('لا يوجد حضور مفتوح') ||
          errorText.contains('تم تسجيل الانصراف مسبقاً')) {
        message = 'لا يوجد حضور مفتوح، أو تم تسجيل الانصراف مسبقًا.';
      } else if (errorText.contains('حساب الموظف غير نشط')) {
        message = 'حساب الموظف غير نشط.';
      } else if (errorText.contains('يجب تسجيل الدخول')) {
        message = 'انتهت جلسة الدخول. سجّل الدخول مجددًا.';
      } else {
        message = 'تفاصيل الخطأ: $errorText';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      // محاولة تحديث الحالة من قاعدة البيانات بعد الخطأ
      await _loadTodayAttendance();
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // ==========================================================
  // الواجهة
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF145A46),
          foregroundColor: Colors.white,
          title: const Text(
            'نظام الحضور والانصراف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
                centerTitle: true,
          actions: [
            IconButton(
              onPressed: isProcessing
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordChangePage(),
                        ),
                      );
                    },
              icon: const Icon(Icons.lock_reset),
              tooltip: 'تغيير كلمة المرور',
            ),
            IconButton(
              onPressed: isProcessing ? null : logout,
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF145A46),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                if (officeLogoUrl != null && officeLogoUrl!.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      officeLogoUrl!,
      width: 75,
      height: 75,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(
        Icons.business,
        color: Colors.white,
        size: 45,
      ),
    ),
  )
else
  const Icon(
    Icons.business,
    color: Colors.white,
    size: 45,
  ),

const SizedBox(height: 8),

if (officeName.isNotEmpty)
  Text(
    officeName,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),

const SizedBox(height: 12),

const Text(
  'مرحبًا بك',
  style: TextStyle(color: Colors.white70, fontSize: 17),
),
const SizedBox(height: 6),
Text(
   employeeName.isEmpty ? 'بوابة الموظف' : employeeName,
  style: const TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  ),
),

                ],
              ),
            ),

                        const SizedBox(height: 22),

            Card(  elevation: 0,
  color: Colors.white,
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        const Icon(
          Icons.smartphone,
          size: 40,
          color: Color(0xFF145A46),
        ),
        const SizedBox(height: 10),
        const Text(
          'اعتماد هاتف الموظف',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (isLoadingDeviceStatus)
          const CircularProgressIndicator()

        else if (deviceId == null)
          const Text('تعذر قراءة هوية الهاتف')

        else if (approvedDeviceId == deviceId)
          const Text(
            'هذا الهاتف معتمد ويمكن استخدامه',
            style: TextStyle(color: Colors.green),
          )

        else if (deviceRequestStatus == 'pending')
          Text(
            requestDeviceId == deviceId
                ? 'طلب اعتماد هاتفك قيد المراجعة'
                : 'لديك طلب اعتماد هاتف آخر قيد المراجعة',
            style: const TextStyle(color: Colors.orange),
            textAlign: TextAlign.center,
          )

        else ...[
          const Text(
            'هذا الهاتف غير معتمد حتى الآن',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isRequestingDevice
                ? null
                : _requestDeviceApproval,
            icon: const Icon(Icons.verified_user),
            label: Text(
              isRequestingDevice
                  ? 'جارٍ إرسال الطلب...'
                  : 'طلب اعتماد هذا الهاتف',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF145A46),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    ),
  ),
),
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                   if (officeLogoUrl != null && officeLogoUrl!.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      officeLogoUrl!,
      width: 85,
      height: 85,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(
        Icons.badge_outlined,
        color: Colors.white,
        size: 42,
      ),
    ),
  )
else
  const Icon(
    Icons.badge_outlined,
    color: Colors.white,
    size: 42,
  ),
const SizedBox(height: 14),
if (officeName.isNotEmpty)
  Text(
    officeName,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),                    const SizedBox(height: 10),
                    const Text(
                      'تاريخ اليوم',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayDate,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الوقت الحالي: $currentTime',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'تسجيل الدوام',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            if (isLoadingStatus) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(child: Text('جارٍ تحميل سجل الدوام...')),
              const SizedBox(height: 12),
            ],

            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: isLoadingStatus || isProcessing || checkedIn
                    ? null
                    : () => registerAttendance(true),
                icon: const Icon(Icons.login),
                label: Text(
                  isProcessing
                      ? 'جارٍ المعالجة...'
                      : checkedIn
                      ? 'تم تسجيل الحضور'
                      : 'تسجيل الحضور',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF145A46),
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed:
                    isLoadingStatus || isProcessing || !checkedIn || checkedOut
                    ? null
                    : () => registerAttendance(false),
                icon: const Icon(Icons.logout),
                label: Text(
                  checkedOut ? 'تم تسجيل الانصراف' : 'تسجيل الانصراف',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

                                const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
