import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'attendance_export_service.dart';

class AttendanceReportsPage extends StatefulWidget {
  final String role;
  final int? officeId;

  const AttendanceReportsPage({
    super.key,
    required this.role,
    required this.officeId,
  });

  @override
  State<AttendanceReportsPage> createState() =>
      _AttendanceReportsPageState();
}

class _AttendanceReportsPageState extends State<AttendanceReportsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime _selectedDate = DateTime.now();
  String _period = 'أسبوعي';

  int? _selectedOfficeId;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _offices = [];
  List<Map<String, dynamic>> _holidays = [];

  Map<String, Map<String, dynamic>> _attendance = {};

  bool _loading = true;
  String? _error;

  static const Color _mainColor = Color(0xFF145A46);

  bool get _isSuperAdmin => widget.role == 'super_admin';

  DateTime get _startDate {
    if (_period == 'يومي') {
      return _dateOnly(_selectedDate);
    }

    if (_period == 'شهري') {
      return DateTime(_selectedDate.year, _selectedDate.month, 1);
    }

    final daysSinceSunday = _selectedDate.weekday % 7;

    return _dateOnly(
      _selectedDate.subtract(Duration(days: daysSinceSunday)),
    );
  }

  DateTime get _endDate {
    if (_period == 'يومي') {
      return _dateOnly(_selectedDate);
    }

    if (_period == 'شهري') {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
      );
    }

    return _startDate.add(const Duration(days: 4));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final d = _dateOnly(date);

    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();

    _selectedOfficeId = widget.officeId;
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final startKey = _dateKey(_startDate);
      final endKey = _dateKey(_endDate);

      if (_isSuperAdmin) {
        final officeData = await _supabase
            .from('offices')
            .select('id, office_name')
            .order('id');

        _offices = List<Map<String, dynamic>>.from(officeData);
      }

      var employeeQuery = _supabase
          .from('employees')
          .select('id, employee_number, full_name, office_id')
          .eq('is_active', true);

      if (_selectedOfficeId != null) {
        employeeQuery =
            employeeQuery.eq('office_id', _selectedOfficeId!);
      }

      final employeeData = await employeeQuery.order('full_name');

      _employees = List<Map<String, dynamic>>.from(employeeData);

      var attendanceQuery = _supabase
          .from('attendance_records')
          .select(
            'employee_id, office_id, attendance_time, '
            'departure_time, work_date',
          )
          .gte('work_date', startKey)
          .lte('work_date', endKey);

      if (_selectedOfficeId != null) {
        attendanceQuery =
            attendanceQuery.eq('office_id', _selectedOfficeId!);
      }

      final attendanceData = await attendanceQuery;

      _attendance = {};

      for (final item in attendanceData) {
        final row = Map<String, dynamic>.from(item);

        final employeeId = row['employee_id']?.toString();
        final workDate = row['work_date']?.toString();

        if (employeeId == null || workDate == null) continue;

        _attendance['$employeeId|$workDate'] = row;
      }

      var holidayQuery = _supabase
          .from('holidays')
          .select('holiday_date, office_id')
          .gte('holiday_date', startKey)
          .lte('holiday_date', endKey);

      if (_selectedOfficeId != null) {
        holidayQuery = holidayQuery.or(
          'office_id.is.null,office_id.eq.$_selectedOfficeId',
        );
      }

      final holidayData = await holidayQuery;

      _holidays = List<Map<String, dynamic>>.from(holidayData);

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  bool _isWorkDay(DateTime date) {
    // الأحد إلى الخميس
    return date.weekday >= DateTime.monday &&
        date.weekday <= DateTime.thursday ||
        date.weekday == DateTime.sunday;
  }

  bool _isHoliday(DateTime date, int? officeId) {
    final key = _dateKey(date);

    return _holidays.any((holiday) {
      final holidayDate =
          holiday['holiday_date']?.toString();

      final holidayOffice = holiday['office_id'];

      final appliesToOffice = holidayOffice == null ||
          officeId == null ||
          holidayOffice.toString() == officeId.toString();

      return holidayDate == key && appliesToOffice;
    });
  }

  List<DateTime> get _workDates {
    final dates = <DateTime>[];

    final today = _dateOnly(DateTime.now());

    for (var date = _startDate;
        !date.isAfter(_endDate);
        date = date.add(const Duration(days: 1))) {
      if (!_isWorkDay(date)) continue;
      if (date.isAfter(today)) continue;

      dates.add(date);
    }

    return dates;
  }

  Map<String, dynamic>? _attendanceFor(
    Map<String, dynamic> employee,
    DateTime date,
  ) {
    final key =
        '${employee['id']}|${_dateKey(date)}';

    return _attendance[key];
  }

  String _formatTime(dynamic value) {
    if (value == null) return '—';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return '—';

    final local = date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _workDuration(dynamic arrival, dynamic departure) {
    if (arrival == null || departure == null) return '—';

    final start = DateTime.tryParse(arrival.toString());
    final end = DateTime.tryParse(departure.toString());

    if (start == null || end == null || !end.isAfter(start)) {
      return '—';
    }

    final minutes = end.difference(start).inMinutes;
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    return '$hours ساعة و $remaining دقيقة';
  }

  int _workMinutes(dynamic arrival, dynamic departure) {
    if (arrival == null || departure == null) return 0;

    final start = DateTime.tryParse(arrival.toString());
    final end = DateTime.tryParse(departure.toString());

    if (start == null || end == null || !end.isAfter(start)) {
      return 0;
    }

    return end.difference(start).inMinutes;
  }

  bool _isLate(dynamic arrival) {
    if (arrival == null) return false;

    final date = DateTime.tryParse(arrival.toString());
    if (date == null) return false;

    final local = date.toLocal();

    return local.hour > 8 ||
        (local.hour == 8 && local.minute > 0);
  }

  String _status(
    Map<String, dynamic>? record,
    DateTime date,
    int? officeId,
  ) {
    if (_isHoliday(date, officeId)) {
      return 'عطلة رسمية';
    }

    if (record == null || record['attendance_time'] == null) {
      return 'غياب';
    }

    if (record['departure_time'] == null) {
      return 'لم يسجل الانصراف';
    }

    if (_isLate(record['attendance_time'])) {
      return 'حضور متأخر';
    }

    return 'حضور مكتمل';
  }

  List<Map<String, dynamic>> _buildExportRows() {
    final rows = <Map<String, dynamic>>[];

    for (final employee in _employees) {
      final officeId = employee['office_id'] as int?;

      for (final date in _workDates) {
        if (_isHoliday(date, officeId)) continue;

        final record = _attendanceFor(employee, date);
        final status = _status(record, date, officeId);

        rows.add({
          'employee_number': employee['employee_number'] ?? '',
          'full_name': employee['full_name'] ?? '',
          'work_date': _dateKey(date),
          'attendance_time': record?['attendance_time'],
          'departure_time': record?['departure_time'],
          'attendance': _formatTime(record?['attendance_time']),
          'departure': _formatTime(record?['departure_time']),
          'status': status,
          'work_minutes': _workMinutes(
            record?['attendance_time'],
            record?['departure_time'],
          ),
          'late': record != null &&
              _isLate(record['attendance_time']),
        });
      }
    }

    return rows;
  }

  int get _presentDays {
    return _buildExportRows().where((row) {
      return row['attendance_time'] != null;
    }).length;
  }

  int get _absentDays {
    return _buildExportRows().where((row) {
      return row['status'] == 'غياب';
    }).length;
  }

  int get _lateDays {
    return _buildExportRows().where((row) {
      return row['late'] == true;
    }).length;
  }

  int get _missingDepartureDays {
    return _buildExportRows().where((row) {
      return row['status'] == 'لم يسجل الانصراف';
    }).length;
  }

  int get _totalWorkMinutes {
    return _buildExportRows().fold<int>(
      0,
      (total, row) => total + (row['work_minutes'] as int),
    );
  }

  String get _periodLabel {
    return '${_dateKey(_startDate)} إلى ${_dateKey(_endDate)}';
  }

  String get _officeName {
    if (_selectedOfficeId == null) return 'جميع المكاتب';

    final matches = _offices.where((office) {
      return office['id'].toString() ==
          _selectedOfficeId.toString();
    });

    if (matches.isEmpty) return 'مكتب الموظف';

    return matches.first['office_name']?.toString() ?? '';
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ التقرير',
      confirmText: 'اختيار',
      cancelText: 'إلغاء',
    );

    if (selected == null) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadReport();
  }

  Future<void> _exportPdf() async {
    try {
    await AttendanceExportService.exportPdf(
        employees: _buildExportRows(),
        reportDate: _periodLabel,
        officeName: _officeName,
      );
    } catch (e) {
      _showMessage('تعذر تصدير PDF: $e');
    }
  }

  Future<void> _exportExcel() async {
    try {
      await AttendanceExportService.exportExcel(
        employees: _buildExportRows(),
        reportDate: _periodLabel,
        officeName: _officeName,
      );
    } catch (e) {
      _showMessage('تعذر تصدير Excel: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _summaryCard(
    String title,
    int value,
    IconData icon,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: _mainColor, size: 27),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _mainColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'غياب') return Colors.red;
    if (status == 'حضور متأخر') return Colors.orange;
    if (status == 'لم يسجل الانصراف') return Colors.deepOrange;
    if (status == 'عطلة رسمية') return Colors.blueGrey;

    return Colors.green;
  }

  Widget _employeeCard(Map<String, dynamic> employee) {
    final officeId = employee['office_id'] as int?;

    final details = <Widget>[];

    for (final date in _workDates) {
      if (_isHoliday(date, officeId)) continue;

      final record = _attendanceFor(employee, date);
      final status = _status(record, date, officeId);

      details.add(
        ListTile(
          dense: true,
          title: Text(_dateKey(date)),
          subtitle: Text(
            'الحضور: ${_formatTime(record?['attendance_time'])}  '
            ' | الانصراف: ${_formatTime(record?['departure_time'])}\n'
            'مدة العمل: ${_workDuration(record?['attendance_time'], record?['departure_time'])}',
          ),
          trailing: Text(
            status,
            style: TextStyle(
              color: _statusColor(status),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    final rows = _buildExportRows().where((row) {
      return row['employee_number'].toString() ==
          employee['employee_number'].toString();
    }).toList();

    final present = rows.where(
      (row) => row['attendance_time'] != null,
    ).length;

    final absent = rows.where(
      (row) => row['status'] == 'غياب',
    ).length;

    final late = rows.where(
      (row) => row['late'] == true,
    ).length;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE5F0EB),
          child: Icon(Icons.person, color: _mainColor),
        ),
        title: Text(
          employee['full_name']?.toString() ?? 'بدون اسم',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'الرقم الوظيفي: ${employee['employee_number']}\n'
          'الحضور: $present  | الغياب: $absent  | التأخير: $late',
        ),
        children: details.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد أيام عمل ضمن هذه الفترة'),
                ),
              ]
            : details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        backgroundColor: _mainColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث التقرير',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadReport,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _period,
                              decoration: const InputDecoration(
                                labelText: 'نوع التقرير',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'يومي',
                                  child: Text('تقرير يومي'),
                                ),
                                DropdownMenuItem(
                                  value: 'أسبوعي',
                                  child: Text('تقرير أسبوعي'),
                                ),
                                DropdownMenuItem(
                                  value: 'شهري',
                                  child: Text('تقرير شهري'),
                                ),
                              ],
                              onChanged: (value) async {
                                if (value == null) return;

                                setState(() {
                                  _period = value;
                                });

                                await _loadReport();
                              },
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _chooseDate,
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                'التاريخ المحدد: ${_dateKey(_selectedDate)}',
                              ),
                            ),
                            if (_isSuperAdmin) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int?>(
                                initialValue: _selectedOfficeId,
                                decoration: const InputDecoration(
                                  labelText: 'المكتب',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('جميع المكاتب'),
                                  ),
                                  ..._offices.map((office) {
                                    return DropdownMenuItem<int?>(
                                      value: office['id'] as int,
                                      child: Text(
                                        office['office_name'].toString(),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) async {
                                  setState(() {
                                    _selectedOfficeId = value;
                                  });

                                  await _loadReport();
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'الفترة: $_periodLabel',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _mainColor,
                              ),
                            ),
                            Text('المكتب: $_officeName'),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.45,
                          children: [
                            _summaryCard(
                              'إجمالي الموظفين',
                              _employees.length,
                              Icons.people,
                            ),
                            _summaryCard(
                              'أيام الحضور',
                              _presentDays,
                              Icons.check_circle,
                            ),
                            _summaryCard(
                              'أيام الغياب',
                              _absentDays,
                              Icons.event_busy,
                            ),
                            _summaryCard(
                              'مرات التأخير',
                              _lateDays,
                              Icons.access_time,
                            ),
                            _summaryCard(
                              'غياب الانصراف',
                              _missingDepartureDays,
                              Icons.logout,
                            ),
                            _summaryCard(
                              'ساعات العمل',
                              _totalWorkMinutes ~/ 60,
                              Icons.timelapse,
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'تفاصيل الموظفين',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (_employees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('لا يوجد موظفون في هذا المكتب'),
                          ),
                        )
                      else
                        ..._employees.map(_employeeCard),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _exportPdf,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('تصدير التقرير PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _mainColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _exportExcel,
                                icon: const Icon(Icons.table_chart),
                                label: const Text('تصدير التقرير Excel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _mainColor,
                                  padding: const EdgeInsets.all(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}