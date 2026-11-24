
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetPage extends StatefulWidget {
  final String role;
  final int? officeId;

  const PasswordResetPage({
    super.key,
    required this.role,
    required this.officeId,
  });

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  bool _resetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    if (widget.role != 'super_admin' &&
        widget.role != 'office_manager') {
      throw Exception('ليس لديك صلاحية عرض الموظفين');
    }

    var query = _supabase
        .from('employees')
        .select('id, employee_number, full_name, office_id')
        .eq('is_active', true);

    if (widget.role == 'office_manager') {
      if (widget.officeId == null) {
        throw Exception('لم يتم تحديد مكتب المدير');
      }

      query = query.eq('office_id', widget.officeId!);
    }

    final rows = await query.order('full_name');

    final roleRows = await _supabase
        .from('user_roles')
        .select('user_id, role')
        .eq('is_active', true);

    final administrativeIds = <String>{};

    for (final row in roleRows) {
      if ([
        'super_admin',
        'admin',
        'office_manager',
      ].contains(row['role']?.toString())) {
        administrativeIds.add(row['user_id'].toString());
      }
    }

    final employees = rows
        .map((row) => Map<String, dynamic>.from(row))
        .where(
          (employee) =>
              !administrativeIds.contains(employee['id'].toString()),
        )
        .toList();

    if (!mounted) return;

    setState(() {
      _employees = employees;
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

  List<Map<String, dynamic>> get _filteredEmployees {
    final search = _searchController.text.trim().toLowerCase();

    if (search.isEmpty) return _employees;

    return _employees.where((employee) {
      final name = employee['full_name'].toString().toLowerCase();
      final number =
          employee['employee_number'].toString().toLowerCase();

      return name.contains(search) || number.contains(search);
    }).toList();
  }

Future<void> _resetPassword(
  Map<String, dynamic> employee,
) async {
  final String? newPassword = await showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(
      employeeName: employee['full_name']?.toString() ?? '',
    ),
  );

  if (newPassword == null || !mounted) return;

  setState(() => _resetting = true);

  try {
    final result = await _supabase.functions.invoke(
      'reset-employee-password',
      body: {
        'employee_id': employee['id'].toString(),
        'new_password': newPassword,
      },
    );

    if (result.data is! Map) {
      throw Exception('استجابة غير صالحة من الخادم');
    }

    final data = Map<String, dynamic>.from(result.data as Map);

    if (data['success'] != true) {
      throw Exception(
        data['error'] ?? 'تعذر تغيير كلمة المرور',
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تغيير كلمة مرور الموظف ${employee['full_name']} بنجاح',
        ),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر تغيير كلمة المرور: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _resetting = false);
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final employees = _filteredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعادة تعيين كلمات المرور'),
        backgroundColor: const Color(0xFF145A46),
        foregroundColor: Colors.white,
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
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadEmployees,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ابحث بالرقم الوطني أو الاسم',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: employees.isEmpty
                          ? const Center(
                              child: Text('لا توجد نتائج'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: employees.length,
                              itemBuilder: (context, index) {
                                final employee = employees[index];

                                return Card(
                                  margin: const EdgeInsets.only(
                                    bottom: 8,
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    title: Text(
                                      employee['full_name'].toString(),
                                    ),
                                    subtitle: Text(
                                      'الرقم الوطني: '
                                      '${employee['employee_number']}',
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'إعادة تعيين كلمة المرور',
                                      onPressed: _resetting
                                          ? null
                                          : () => _resetPassword(employee),
                                      icon: const Icon(
                                        Icons.lock_reset,
                                        color: Color(0xFF145A46),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_resetting)
                      const LinearProgressIndicator(),
                  ],
                ),
    );
  }
}
class _PasswordDialog extends StatefulWidget {
  final String employeeName;

  const _PasswordDialog({
    required this.employeeName,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعيين كلمة مرور جديدة'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الموظف: ${widget.employeeName}'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'يجب ألا تقل كلمة المرور عن 8 أحرف';
                }
                if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
                  return 'أضف حرفاً لاتينياً واحداً على الأقل';
                }
                if (!RegExp(r'[0-9]').hasMatch(value)) {
                  return 'أضف رقماً واحداً على الأقل';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _confirmController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'كلمتا المرور غير متطابقتين';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _passwordController.text,
              );
            }
          },
          child: const Text('حفظ كلمة المرور'),
        ),
      ],
    );
  }
}
