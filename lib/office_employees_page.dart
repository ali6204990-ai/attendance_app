import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfficeEmployeesPage extends StatefulWidget {
  final int? officeId;
  final String role;

  const OfficeEmployeesPage({
    super.key,
    required this.officeId,
    required this.role,
  });

  @override
  State<OfficeEmployeesPage> createState() =>
      _OfficeEmployeesPageState();
}

class _OfficeEmployeesPageState extends State<OfficeEmployeesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = true;
  String? _error;
  String _searchText = '';

  final Set<String> _busyEmployees = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // الاتصال بخدمة إدارة الموظفين
  Future<Map<String, dynamic>> _invokeFunction(
    Map<String, dynamic> body,
  ) async {
    final response = await _supabase.functions.invoke(
      'manage-office-employees',
      body: body,
    );

    final data = response.data;

    if (data is Map) {
      final result = Map<String, dynamic>.from(data);

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      return result;
    }

    throw Exception('استجابة غير متوقعة من الخادم');
  }

  // تحميل الموظفين
  Future<void> _loadEmployees() async {
    if (widget.officeId == null) {
      setState(() {
        _isLoading = false;
        _error = 'لم يتم تحديد المكتب الخاص بهذا الحساب';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _invokeFunction({
        'action': 'list',
        'office_id': widget.officeId,
      });

      final data = result['employees'];

      if (data is! List) {
        throw Exception('تعذر قراءة قائمة الموظفين');
      }

      final employees = data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _testOfficeSecurity() async {
    try {
      final response = await _supabase.functions.invoke(
        'manage-office-employees',
        body: {
          'action': 'list',
          'office_id': 1,
        },
      );

      debugPrint('SECURITY TEST STATUS: ${response.status}');
      debugPrint('SECURITY TEST DATA: ${response.data}');
    } on FunctionException catch (e) {
      debugPrint('SECURITY TEST STATUS: ${e.status}');
      debugPrint('SECURITY TEST ERROR: ${e.details}');
    } catch (e) {
      debugPrint('SECURITY TEST ERROR: $e');
    }
  }
  // قائمة الموظفين بعد البحث
  List<Map<String, dynamic>> get _filteredEmployees {
    if (_searchText.isEmpty) return _employees;

    return _employees.where((employee) {
      final name =
          (employee['full_name'] ?? '').toString().toLowerCase();

      final number =
          (employee['employee_number'] ?? '').toString().toLowerCase();

      final search = _searchText.toLowerCase();

      return name.contains(search) || number.contains(search);
    }).toList();
  }

  // تعديل اسم الموظف
Future<void> _editEmployee(
  Map<String, dynamic> employee,
) async {
  String newName = employee['full_name']?.toString() ?? '';

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('تعديل اسم الموظف'),
        content: TextFormField(
          initialValue: newName,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'اسم الموظف',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            newName = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final name = newName.trim();

              if (name.length < 2) return;

              Navigator.pop(dialogContext, name);
            },
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );

  if (result == null || result.trim().isEmpty) return;

  await _updateEmployeeName(
    employee['id'].toString(),
    result.trim(),
  );
}
  Future<void> _updateEmployeeName(
    String employeeId,
    String fullName,
  ) async {
    setState(() {
      _busyEmployees.add(employeeId);
    });

    try {
      await _invokeFunction({
        'action': 'update_name',
        'employee_id': employeeId,
        'full_name': fullName,
      });

      _showMessage('تم تعديل اسم الموظف بنجاح');

      await _loadEmployees();
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyEmployees.remove(employeeId);
        });
      }
    }
  }

  // تفعيل أو إيقاف الموظف
  Future<void> _changeEmployeeStatus(
    Map<String, dynamic> employee,
  ) async {
    final id = employee['id'].toString();

    final currentStatus = employee['is_active'] == true;
    final newStatus = !currentStatus;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            newStatus ? 'تفعيل الموظف' : 'إيقاف الموظف',
          ),
          content: Text(
            newStatus
                ? 'هل تريد تفعيل هذا الموظف؟'
                : 'هل تريد إيقاف هذا الموظف؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _busyEmployees.add(id);
    });

    try {
      await _invokeFunction({
        'action': 'set_active',
        'employee_id': id,
        'is_active': newStatus,
      });

      _showMessage(
        newStatus
            ? 'تم تفعيل الموظف بنجاح'
            : 'تم إيقاف الموظف بنجاح',
      );

      await _loadEmployees();
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyEmployees.remove(id);
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employees = _filteredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموظفين'),
        centerTitle: true,
        backgroundColor: const Color(0xFF145A46),
        foregroundColor: Colors.white,
        actions: [            IconButton(
              onPressed: _testOfficeSecurity,
              icon: const Icon(Icons.security),
              tooltip: 'اختبار صلاحيات المكتب',
            ),

          IconButton(
            onPressed: _loadEmployees,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الرقم الوظيفي',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  color: Color(0xFF145A46),
                ),
                const SizedBox(width: 8),
                Text(
                  'عدد الموظفين: ${_employees.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
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
                                size: 45,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                onPressed: _loadEmployees,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : employees.isEmpty
                        ? const Center(
                            child: Text('لا توجد نتائج'),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadEmployees,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              itemCount: employees.length,
                              itemBuilder: (context, index) {
                                final employee = employees[index];

                                final id = employee['id'].toString();
                                final name =
                                    employee['full_name']?.toString() ??
                                        'بدون اسم';

                                final number =
                                    employee['employee_number']
                                            ?.toString() ??
                                        '';

                                final active =
                                    employee['is_active'] == true;

                                final busy =
                                    _busyEmployees.contains(id);

                                return Card(
                                  margin: const EdgeInsets.only(
                                    bottom: 10,
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: active
                                          ? Colors.green.shade100
                                          : Colors.grey.shade300,
                                      child: Icon(
                                        Icons.person,
                                        color: active
                                            ? Colors.green.shade800
                                            : Colors.grey,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 5),
                                        Text('الرقم الوظيفي: $number'),
                                        const SizedBox(height: 4),
                                        Text(
                                          active ? 'نشط' : 'موقوف',
                                          style: TextStyle(
                                            color: active
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: busy
                                        ? const SizedBox(
                                            width: 25,
                                            height: 25,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _editEmployee(employee);
                                              } else if (value == 'status') {
                                                _changeEmployeeStatus(
                                                  employee,
                                                );
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit),
                                                    SizedBox(width: 8),
                                                    Text('تعديل الاسم'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'status',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      active
                                                          ? Icons
                                                              .person_off
                                                          : Icons
                                                              .person_add,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      active
                                                          ? 'إيقاف الموظف'
                                                          : 'تفعيل الموظف',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

