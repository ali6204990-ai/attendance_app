import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class HolidaysManagementPage extends StatefulWidget {
  final String role;
  final int? officeId;

  const HolidaysManagementPage({
    super.key,
    required this.role,
    required this.officeId,
  });

  @override
  State<HolidaysManagementPage> createState() =>
      _HolidaysManagementPageState();
}

class _HolidaysManagementPageState
    extends State<HolidaysManagementPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _offices = [];

  bool _loading = true;
  bool _saving = false;

  bool get _isSuperAdmin => widget.role == 'super_admin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      var query = _supabase
          .from('holidays')
          .select('*, offices(office_name)');

      if (!_isSuperAdmin) {
        query = query.eq('office_id', widget.officeId!);
      }

      final holidays = await query.order('holiday_date');

      List<Map<String, dynamic>> offices = [];

      if (_isSuperAdmin) {
        final result = await _supabase
            .from('offices')
            .select('id, office_name')
            .order('id');

        offices = List<Map<String, dynamic>>.from(result);
      }

      if (!mounted) return;

      setState(() {
        _holidays = List<Map<String, dynamic>>.from(holidays);
        _offices = offices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل العطلات: $e')),
      );
    }
  }

  String _formatDate(String value) {
    final date = DateTime.parse(value);
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showHolidayDialog({
    Map<String, dynamic>? holiday,
  }) async {
    final nameController = TextEditingController(
      text: holiday?['holiday_name']?.toString() ?? '',
    );

    DateTime selectedDate = holiday == null
        ? DateTime.now()
        : DateTime.parse(holiday['holiday_date'].toString());

    int? selectedOfficeId = holiday?['office_id'] == null
        ? null
        : (holiday!['office_id'] as num).toInt();

    if (!_isSuperAdmin) {
      selectedOfficeId = widget.officeId;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                holiday == null ? 'إضافة عطلة رسمية' : 'تعديل العطلة',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم العطلة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('تاريخ العطلة'),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                    if (_isSuperAdmin) ...[
                      const SizedBox(height: 8),
                   DropdownButtonFormField<int?>(
  isExpanded: true,
                        initialValue: selectedOfficeId,
                        decoration: const InputDecoration(
                          labelText: 'المكتب',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('عطلة عامة لجميع المكاتب'),
                          ),
                          ..._offices.map((office) {
                            return DropdownMenuItem<int?>(
                              value: (office['id'] as num).toInt(),
                            child: Text(
  office['office_name'].toString(),
  overflow: TextOverflow.ellipsis,
  maxLines: 1,
),                            );
                          }),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedOfficeId = value;
                          });
                        },
                      ),
                    ] else
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.business),
                        title: Text('مكتبك فقط'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال اسم العطلة'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => _saving = true);

                          await _saveHoliday(
                            holiday: holiday,
                            name: name,
                            date: selectedDate,
                            officeId: selectedOfficeId,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    
  }

  Future<void> _saveHoliday({
    Map<String, dynamic>? holiday,
    required String name,
    required DateTime date,
    required int? officeId,
  }) async {
    try {
      final data = {
        'holiday_name': name,
        'holiday_date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'office_id': officeId,
      };

      if (holiday == null) {
        await _supabase.from('holidays').insert({
          ...data,
          'created_by': _supabase.auth.currentUser!.id,
        });
      } else {
        await _supabase
            .from('holidays')
            .update(data)
            .eq('id', holiday['id']);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ العطلة بنجاح')),
      );

   
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ العطلة: $e')),
      );
    }
  }

  Future<void> _deleteHoliday(Map<String, dynamic> holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العطلة'),
        content: Text(
          'هل تريد حذف "${holiday['holiday_name']}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('holidays')
          .delete()
          .eq('id', holiday['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العطلة')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف العطلة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العطلات الرسمية'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showHolidayDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة عطلة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _holidays.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 140),
                        Icon(
                          Icons.event_busy,
                          size: 65,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Text('لا توجد عطلات مسجلة'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _holidays.length,
                      itemBuilder: (context, index) {
                        final holiday = _holidays[index];

                        final office = holiday['offices'];
                        final officeName = office == null
                            ? 'عطلة عامة'
                            : office['office_name']?.toString() ??
                                'مكتب غير معروف';

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.event),
                            ),
                            title: Text(
                              holiday['holiday_name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${_formatDate(holiday['holiday_date'].toString())}\n'
                              '$officeName',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showHolidayDialog(
                                    holiday: holiday,
                                  );
                                } else if (value == 'delete') {
                                  _deleteHoliday(holiday);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('تعديل'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}