
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeTransferPage extends StatefulWidget {
  const EmployeeTransferPage({super.key});

  @override
  State<EmployeeTransferPage> createState() =>
      _EmployeeTransferPageState();
}

class _EmployeeTransferPageState
    extends State<EmployeeTransferPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController =
      TextEditingController();
  final TextEditingController _reasonController =
      TextEditingController();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _offices = [];

  Map<String, dynamic>? _selectedEmployee;
  int? _destinationOfficeId;

  bool _loading = true;
  bool _transferring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final employeeRows = await _supabase
          .from('employees')
          .select(
            'id, employee_number, full_name, office_id',
          )
          .eq('is_active', true)
          .order('full_name');

      final officeRows = await _supabase
          .from('offices')
          .select('id, office_name')
          .order('office_name');

      final roleRows = await _supabase
          .from('user_roles')
          .select('user_id, role')
          .eq('is_active', true);

      final administrativeIds = <String>{};

      for (final row in roleRows) {
        final role = row['role']?.toString();

        if ([
          'super_admin',
          'admin',
          'office_manager',
        ].contains(role)) {
          administrativeIds.add(
            row['user_id'].toString(),
          );
        }
      }

      final employees = employeeRows
          .map((row) => Map<String, dynamic>.from(row))
          .where(
            (employee) =>
                !administrativeIds.contains(
                  employee['id'].toString(),
                ),
          )
          .toList();

      final offices = officeRows
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      if (!mounted) return;

      setState(() {
        _employees = employees;
        _offices = offices;
        _selectedEmployee = null;
        _destinationOfficeId = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _officeName(dynamic officeId) {
    if (officeId == null) return 'غير محدد';

    for (final office in _offices) {
      if ((office['id'] as num).toInt() ==
          (officeId as num).toInt()) {
        return office['office_name'].toString();
      }
    }

    return 'غير معروف';
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _employees;

    return _employees.where((employee) {
      final name =
          employee['full_name'].toString().toLowerCase();

      final number =
          employee['employee_number'].toString().toLowerCase();

      return name.contains(query) || number.contains(query);
    }).toList();
  }

  void _selectEmployee(Map<String, dynamic> employee) {
    final currentOfficeId =
        (employee['office_id'] as num?)?.toInt();

    final destinations = _offices.where((office) {
      return (office['id'] as num).toInt() !=
          currentOfficeId;
    }).toList();

    setState(() {
      _selectedEmployee = employee;

      _destinationOfficeId = destinations.isEmpty
          ? null
          : (destinations.first['id'] as num).toInt();

      _reasonController.clear();
    });
  }

  Future<void> _confirmTransfer() async {
    final employee = _selectedEmployee;

    if (employee == null) return;

    if (_destinationOfficeId == null) {
      _showMessage('اختر المكتب الجديد', isError: true);
      return;
    }

    final oldOfficeId =
        (employee['office_id'] as num).toInt();

    if (oldOfficeId == _destinationOfficeId) {
      _showMessage(
        'الموظف موجود بالفعل في هذا المكتب',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد نقل الموظف'),
          content: Text(
            'هل تريد نقل الموظف ${employee['full_name']}؟\n\n'
            'من: ${_officeName(oldOfficeId)}\n'
            'إلى: ${_officeName(_destinationOfficeId)}',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('تأكيد النقل'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _transferring = true;
    });

    try {
      final response =
          await _supabase.functions.invoke(
        'transfer-employee-office',
        body: {
          'employee_id': employee['id'].toString(),
          'to_office_id': _destinationOfficeId,
          'reason': _reasonController.text.trim(),
        },
      );

      if (response.status < 200 ||
          response.status >= 300) {
        throw Exception(response.data.toString());
      }

      final data = response.data;

      if (data is Map && data['success'] != true) {
        throw Exception(
          data['error']?.toString() ??
              'تعذر تنفيذ عملية النقل',
        );
      }

      if (!mounted) return;

      setState(() {
        _selectedEmployee = null;
        _reasonController.clear();
        _searchController.clear();
      });

      _showMessage('تم نقل الموظف بنجاح');

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'تعذر نقل الموظف: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _transferring = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = _selectedEmployee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقل الموظفين بين المكاتب'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تعذر تحميل البيانات\n$_error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'ابحث بالاسم أو الرقم الوطني',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    Expanded(
                      child: _filteredEmployees.isEmpty
                          ? const Center(
                              child: Text('لا توجد نتائج'),
                            )
                          : ListView.builder(
                              itemCount:
                                  _filteredEmployees.length,
                              itemBuilder: (context, index) {
                                final item =
                                    _filteredEmployees[index];

                                final selected =
                                    employee?['id'] ==
                                        item['id'];

                                return Card(
                                  margin: const EdgeInsets
                                      .symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    selected: selected,
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    title: Text(
                                      item['full_name'] ??
                                          'بدون اسم',
                                    ),
                                    subtitle: Text(
                                      'الرقم الوطني: '
                                      '${item['employee_number']}\n'
                                      'المكتب الحالي: '
                                      '${_officeName(item['office_id'])}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.arrow_forward_ios,
                                    ),
                                    onTap: _transferring
                                        ? null
                                        : () =>
                                            _selectEmployee(item),
                                  ),
                                );
                              },
                            ),
                    ),

                    if (employee != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme.surface,
                          border: const Border(
                            top: BorderSide(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'الموظف: ${employee['full_name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'المكتب الحالي: '
                              '${_officeName(employee['office_id'])}',
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<int>(
                              initialValue:
                                  _destinationOfficeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'المكتب الجديد',
                                border: OutlineInputBorder(),
                              ),
                              items: _offices
                                  .where(
                                    (office) =>
                                        (office['id'] as num)
                                            .toInt() !=
                                        (employee['office_id']
                                            as num)
                                            .toInt(),
                                  )
                                  .map((office) {
                                return DropdownMenuItem<int>(
                                  value: (office['id'] as num)
                                      .toInt(),
                                  child: Text(
                                    office['office_name']
                                        .toString(),
                                  ),
                                );
                              }).toList(),
                              onChanged: _transferring
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _destinationOfficeId =
                                            value;
                                      });
                                    },
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: _reasonController,
                              maxLength: 500,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'سبب النقل (اختياري)',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 8),

                            ElevatedButton.icon(
                              onPressed: _transferring
                                  ? null
                                  : _confirmTransfer,
                              icon: const Icon(
                                Icons.swap_horiz,
                              ),
                              label: Text(
                                _transferring
                                    ? 'جارٍ تنفيذ النقل...'
                                    : 'تأكيد نقل الموظف',
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize:
                                    const Size.fromHeight(50),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
