import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerManagementPage extends StatefulWidget {
  const ManagerManagementPage({super.key});

  @override
  State<ManagerManagementPage> createState() =>
      _ManagerManagementPageState();
}

class _ManagerManagementPageState extends State<ManagerManagementPage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _employeeNumberController = TextEditingController();
  final _fullNameController = TextEditingController();

  List<Map<String, dynamic>> offices = [];
List<Map<String, dynamic>> managers = [];
bool loadingManagers = true;
  int? selectedOfficeId;
  String selectedRole = 'office_manager';

  bool loadingOffices = true;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    loadOffices();
    loadManagers();
 }
  @override
  void dispose() {
    _employeeNumberController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> loadOffices() async {
    try {
      final result = await supabase
          .from('offices')
          .select('id, office_name')
          .order('id');

      if (!mounted) return;

      setState(() {
        offices = List<Map<String, dynamic>>.from(result);
        if (offices.isNotEmpty) {
          selectedOfficeId = offices.first['id'] as int;
        }
        loadingOffices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingOffices = false);
      showMessage('تعذر تحميل المكاتب: $e');
    }
  }
Future<void> editManager(Map<String, dynamic> manager) async {
  final nameController = TextEditingController(
    text: manager['full_name']?.toString() ?? '',
  );

  String selectedRole = manager['role'].toString();

  int? selectedOfficeId = manager['office_id'] is int
      ? manager['office_id'] as int
      : int.tryParse(manager['office_id']?.toString() ?? '');

  if (selectedOfficeId != null &&
      !offices.any((office) => office['id'] == selectedOfficeId)) {
    selectedOfficeId = null;
  }

  final formKey = GlobalKey<FormState>();

  final changes = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('تعديل بيانات المدير'),
        content: SingleChildScrollView(
          child: Form(
                  key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: manager['employee_number']?.toString() ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الوطني',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المدير',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'أدخل الاسم بشكل صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'نوع الصلاحية',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('مدير عام للنظام'),
                    ),
                    DropdownMenuItem(
                      value: 'office_manager',
                      child: Text('مدير مكتب'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedRole = value;
                        if (value == 'admin') {
                          selectedOfficeId = null;
                        }
                      });
                    }
                  },
                ),
                if (selectedRole == 'office_manager') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedOfficeId,
                    decoration: const InputDecoration(
                      labelText: 'المكتب التابع له',
                      border: OutlineInputBorder(),
                    ),
                    items: offices.map((office) {
                      return DropdownMenuItem<int>(
                        value: office['id'] as int,
                        child: Text(office['office_name'].toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedOfficeId = value;
                      });
                    },
                    validator: (value) {
                      if (selectedRole == 'office_manager' && value == null) {
                        return 'اختر المكتب';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(dialogContext, {
                'full_name': nameController.text.trim(),
                'role': selectedRole,
                'office_id': selectedOfficeId,
              });
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    ),
  );

  

  if (changes == null) return;

  try {
    final response = await supabase.functions.invoke(
      'manage-manager-account',
      body: {
        'action': 'update',
        'user_id': manager['user_id'].toString(),
        'full_name': changes['full_name'],
        'role': changes['role'],
        'office_id': changes['office_id'],
      },
    );

    final data = response.data;

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        data is Map ? data['error'] : 'تعذر تعديل بيانات المدير',
      );
    }

    if (data is! Map || data['success'] != true) {
      throw Exception(
        data is Map ? data['error'] : 'استجابة غير متوقعة',
      );
    }

    showMessage('تم تعديل بيانات المدير بنجاح');
    await loadManagers();
  } catch (e) {
    showMessage('حدث خطأ أثناء التعديل: $e');
  }
}
   Future<void> loadManagers() async {
    try {
      final rolesResult = await supabase
          .from('user_roles')
          .select('user_id, role, office_id, is_active')
          .order('created_at', ascending: false);

      final roles =
          List<Map<String, dynamic>>.from(rolesResult);

      final employeesResult = await supabase
          .from('employees')
          .select('id, employee_number, full_name');

      final employees =
          List<Map<String, dynamic>>.from(employeesResult);

      final employeeMap = {
        for (final employee in employees)
          employee['id'].toString(): employee,
      };

      final officesResult = await supabase
          .from('offices')
          .select('id, office_name');

      final officeMap = {
        for (final office
            in List<Map<String, dynamic>>.from(officesResult))
          office['id'].toString(): office['office_name'].toString(),
      };

      final result = roles.map((role) {
        final employee =
            employeeMap[role['user_id'].toString()];

        return {
          ...role,
          'employee_number': employee?['employee_number'] ?? '',
          'full_name': employee?['full_name'] ?? 'اسم غير متوفر',
          'office_name':
              officeMap[role['office_id']?.toString()] ??
                  'لا يوجد مكتب محدد',
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        managers = result;
        loadingManagers = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loadingManagers = false);
      showMessage('تعذر تحميل المديرين: $e');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
    
  Future<void> createManager() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedOfficeId == null) {
      showMessage('يرجى اختيار المكتب');
      return;
    }

    setState(() => creating = true);

    try {
      final response = await supabase.functions.invoke(
        'create-manager-account',
        body: {
          'employee_number':
          _employeeNumberController.text.trim(),
          'full_name': _fullNameController.text.trim(),
          'office_id': selectedOfficeId,
          'role': selectedRole,
        },
      );

      final data = response.data;

debugPrint('CREATE MANAGER STATUS: ${response.status}');
debugPrint('CREATE MANAGER RESPONSE: $data');

      if (response.status < 200 || response.status >= 300) {
        throw Exception(data?['error'] ?? 'تعذر إنشاء الحساب');
      }

      if (data is! Map || data['success'] != true) {
        throw Exception(
          data is Map
              ? data['error'] ?? 'تعذر إنشاء الحساب'
              : 'استجابة غير متوقعة من الخادم',
        );
      }

      if (!mounted) return;

      final temporaryPassword =
          data['temporary_password']?.toString() ?? '';

      _employeeNumberController.clear();
      _fullNameController.clear();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تم إنشاء حساب المدير بنجاح'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الاسم: ${data['full_name'] ?? ''}'),
              const SizedBox(height: 8),
              Text('الرقم الوطني: ${data['employee_number'] ?? ''}'),
              const SizedBox(height: 8),
              const Text('كلمة المرور المؤقتة:'),
              const SizedBox(height: 6),
              SelectableText(
                temporaryPassword,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'احفظ كلمة المرور الآن، فلن نعرضها مرة أخرى.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: temporaryPassword),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ كلمة المرور'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('نسخ كلمة المرور'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showMessage('حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => creating = false);
      }
    }
  }
Future<void> setManagerActive(
  Map<String, dynamic> manager,
  bool isActive,
) async {
  final userId = manager['user_id'].toString();

  final actionText = isActive ? 'تفعيل' : 'إيقاف';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$actionText المدير'),
      content: Text(
        'هل أنت متأكد من $actionText المدير '
        '${manager['full_name']}؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('تأكيد $actionText'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final response = await supabase.functions.invoke(
      'manage-manager-account',
      body: {
        'action': 'set_active',
        'user_id': userId,
        'is_active': isActive,
      },
    );

    final data = response.data;

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        data is Map ? data['error'] : 'تعذر تنفيذ العملية',
      );
    }

    if (data is! Map || data['success'] != true) {
      throw Exception(
        data is Map ? data['error'] : 'استجابة غير متوقعة',
      );
    }

    showMessage(
      isActive ? 'تم تفعيل المدير بنجاح' : 'تم إيقاف المدير بنجاح',
    );

    await loadManagers();
  } catch (e) {
    showMessage('حدث خطأ: $e');
  }
}
Future<void> _testOfficeEmployees() async {
  try {
    final response = await supabase.functions.invoke(
      'manage-office-employees',
      body: {
        'action': 'list',
        'office_id': 21,
      },
    );

    debugPrint('MANAGE_EMPLOYEES_TEST: ${response.data}');

    showMessage('تم الاتصال بالدالة. راجع نتيجة الاختبار.');
  } catch (e) {
    debugPrint('MANAGE_EMPLOYEES_ERROR: $e');
    showMessage('فشل الاختبار: $e');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المديرين والصلاحيات'),
        backgroundColor: const Color(0xFF145A46),
        foregroundColor: Colors.white,
      ),
      body: loadingOffices
          ? const Center(child: CircularProgressIndicator())
          : offices.isEmpty
          ? const Center(child: Text('لا توجد مكاتب مسجلة'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
  ElevatedButton(
    onPressed: _testOfficeEmployees,
    child: const Text('اختبار إدارة موظفي المكتب'),
  ),
  const SizedBox(height: 15),
  const Text(
    'إضافة مدير جديد',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _employeeNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الرقم الوطني',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'أدخل الرقم الوطني';
                  }
                  if (!RegExp(r'^\d+$')
                      .hasMatch(value.trim())) {
                    return 'الرقم الوطني يجب أن يحتوي على أرقام فقط';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الرباعي',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().length < 3) {
                    return 'أدخل الاسم بشكل صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'نوع الصلاحية',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('مدير عام للنظام'),
                  ),
                  DropdownMenuItem(
                    value: 'office_manager',
                    child: Text('مدير مكتب'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedOfficeId,
                decoration: const InputDecoration(
                  labelText: 'المكتب التابع له',
                  border: OutlineInputBorder(),
                ),
                items: offices.map((office) {
                  return DropdownMenuItem<int>(
                    value: office['id'] as int,
                    child: Text(
                      office['office_name'].toString(),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedOfficeId = value);
                },
              ),
    const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: creating ? null : createManager,
                icon: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.person_add),
                label: Text(
                  creating
                      ? 'جارٍ إنشاء الحساب...'
                      : 'إنشاء حساب المدير',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF145A46),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Divider(),
              const Text(
                'المديرون المسجلون',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF145A46),
                ),
              ),
              const SizedBox(height: 12),

              if (loadingManagers)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (managers.isEmpty)
                const Center(
                  child: Text('لا يوجد مديرون مسجلون'),
                )
              else
                ...managers.map((manager) {
                  final isActive = manager['is_active'] == true;

                  final roleName =
                      manager['role'] == 'super_admin'
                          ? 'مدير النظام الرئيسي'
                          : manager['role'] == 'admin'
                              ? 'مدير عام للنظام'
                              : 'مدير مكتب';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(
                        manager['full_name'].toString(),
                      ),
                      subtitle: Text(
                        'الرقم الوطني: ${manager['employee_number']}\n'
                        'الصلاحية: $roleName\n'
                        'المكتب: ${manager['office_name']}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
 onSelected: (value) {
  if (value == 'toggle') {
    setManagerActive(manager, !isActive);
  } else if (value == 'edit') {
    editManager(manager);
  }
},
  itemBuilder: (context) => [
  PopupMenuItem<String>(
  value: 'edit',
  child: Row(
    children: [
      const Icon(Icons.edit, color: Colors.blue),
      const SizedBox(width: 8),
      const Text('تعديل بيانات المدير'),
    ],
  ),
),
  PopupMenuItem<String>(
      value: 'toggle',
      child: Row(
        children: [
          Icon(
            isActive ? Icons.block : Icons.check_circle,
            color: isActive ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(isActive ? 'إيقاف المدير' : 'إعادة التفعيل'),
        ],
      ),
    ),
  ],
  icon: const Icon(Icons.more_vert),
),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}