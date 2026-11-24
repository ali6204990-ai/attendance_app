import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeAddPage extends StatefulWidget {
  final String role;
  final int? officeId;

  const EmployeeAddPage({
    super.key,
    required this.role,
    required this.officeId,
  });

  @override
  State<EmployeeAddPage> createState() => _EmployeeAddPageState();
}

class _EmployeeAddPageState extends State<EmployeeAddPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  List<Map<String, dynamic>> _offices = [];
  int? _selectedOffice;
  String? _selectedOfficeName;

  bool _loading = true;
  bool _saving = false;
  bool _hidePassword = true;

  String? _employeeName;
  String? _employeeNumber;

  bool get _isOfficeManager => widget.role == 'office_manager';

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    try {
      if (_isOfficeManager) {
        if (widget.officeId == null) {
          throw Exception('حسابك غير مرتبط بمكتب محدد');
        }

        final office = await _supabase
            .from('offices')
            .select('id, office_name')
            .eq('id', widget.officeId!)
            .maybeSingle();

        if (office == null) {
          throw Exception('تعذر العثور على المكتب المرتبط بحسابك');
        }

        if (!mounted) return;

        setState(() {
          _selectedOffice = widget.officeId;
          _selectedOfficeName = office['office_name'].toString();
          _offices = [Map<String, dynamic>.from(office)];
          _loading = false;
        });
      } else {
        final rows = await _supabase
            .from('offices')
            .select('id, office_name')
            .order('id');

        if (!mounted) return;

        setState(() {
          _offices = rows
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل بيانات المكتب: $e')),
      );
    }
  }

  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedOffice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد المكتب')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _employeeName = null;
      _employeeNumber = null;
    });

    try {
      final body = <String, dynamic>{
        'employee_number': _numberController.text.trim(),
        'full_name': _nameController.text.trim(),
        'password': _passwordController.text,
      };

      // مدير المكتب لا يرسل رقم المكتب؛
      // الوظيفة تحدده من صلاحياته مباشرة.
      if (!_isOfficeManager) {
        body['office_id'] = _selectedOffice;
      }

      final result = await _supabase.functions.invoke(
        'create-employee-account',
        body: body,
      );

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'تعذرت إضافة الموظف');
      }

      final employee = data['employee'];

      if (!mounted) return;

      setState(() {
        _employeeName = employee?['full_name']?.toString() ??
            _nameController.text.trim();

        _employeeNumber = employee?['employee_number']?.toString() ??
            _numberController.text.trim();

        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء حساب الموظف بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذرت إضافة الموظف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _newEmployee() {
    setState(() {
      _numberController.clear();
      _nameController.clear();
      _passwordController.clear();
      _employeeName = null;
      _employeeNumber = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة موظف جديد'),
          centerTitle: true,
          backgroundColor: const Color(0xFF145A46),
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _offices.isEmpty
                ? const Center(child: Text('لا توجد بيانات مكتب متاحة'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.person_add_alt_1,
                            size: 65,
                            color: Color(0xFF145A46),
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _numberController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'الرقم الوظيفي',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال الرقم الوظيفي';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الكامل',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسم الموظف';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _hidePassword = !_hidePassword;
                                  });
                                },
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال كلمة المرور';
                              }
                              if (value.length < 6) {
                                return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          if (_isOfficeManager)
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'المكتب التابع له',
                                prefixIcon: Icon(Icons.business_outlined),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(_selectedOfficeName ?? ''),
                            )
                          else
                            DropdownButtonFormField<int>(
                              initialValue: _selectedOffice,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'المكتب التابع له',
                                prefixIcon: Icon(Icons.business_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _offices.map((office) {
                                return DropdownMenuItem<int>(
                                  value: (office['id'] as num).toInt(),
                                  child: Text(
                                    office['office_name'].toString(),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedOffice = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'يرجى اختيار المكتب';
                                }
                                return null;
                              },
                            ),

                          const SizedBox(height: 25),

                          FilledButton.icon(
                            onPressed: _saving ? null : _addEmployee,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_add),
                            label: Text(
                              _saving
                                  ? 'جارٍ إضافة الموظف...'
                                  : 'إضافة الموظف وإنشاء الحساب',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF145A46),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),

                          if (_employeeName != null) ...[
                            const SizedBox(height: 25),
                            Card(
                              color: Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 45,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'تمت إضافة الموظف بنجاح',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text('الاسم: $_employeeName'),
                                    Text('الرقم الوظيفي: $_employeeNumber'),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'احتفظ بكلمة المرور التي أدخلتها لتسليمها للموظف.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: _newEmployee,
                                      icon: const Icon(Icons.person_add),
                                      label: const Text('إضافة موظف آخر'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
