import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transfer_history_export_service.dart';
class EmployeeTransferHistoryPage extends StatefulWidget {
  const EmployeeTransferHistoryPage({super.key});

  @override
  State<EmployeeTransferHistoryPage> createState() =>
      _EmployeeTransferHistoryPageState();
}

class _EmployeeTransferHistoryPageState
    extends State<EmployeeTransferHistoryPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> transfers = [];
  Map<String, Map<String, dynamic>> employees = {};
  Map<int, String> offices = {};

  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadTransfers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadTransfers() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final results = await Future.wait([
        supabase
            .from('employee_office_transfers')
            .select()
            .order('transferred_at', ascending: false),
        supabase
            .from('employees')
            .select('id, employee_number, full_name'),
        supabase
            .from('offices')
            .select('id, office_name'),
      ]);

      final transferData = List<Map<String, dynamic>>.from(results[0]);
      final employeeData = List<Map<String, dynamic>>.from(results[1]);
      final officeData = List<Map<String, dynamic>>.from(results[2]);

      final employeeMap = <String, Map<String, dynamic>>{};
      for (final employee in employeeData) {
        employeeMap[employee['id'].toString()] = employee;
      }

      final officeMap = <int, String>{};
      for (final office in officeData) {
        officeMap[int.parse(office['id'].toString())] =
            office['office_name'].toString();
      }

      if (!mounted) return;

      setState(() {
        transfers = transferData;
        employees = employeeMap;
        offices = officeMap;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return 'غير محدد';

    final date = DateTime.parse(value.toString()).toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}'
        ' - ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  List<Map<String, dynamic>> get filteredTransfers {
    final search = searchController.text.trim().toLowerCase();

    if (search.isEmpty) return transfers;

    return transfers.where((transfer) {
      final employee =
          employees[transfer['employee_id']?.toString()] ?? {};

      final name = (employee['full_name'] ?? '').toString().toLowerCase();
      final number =
          (employee['employee_number'] ?? '').toString().toLowerCase();

      final fromOffice =
          offices[int.tryParse(transfer['from_office_id'].toString()) ?? -1] ??
              '';

      final toOffice =
          offices[int.tryParse(transfer['to_office_id'].toString()) ?? -1] ??
              '';

      return name.contains(search) ||
          number.contains(search) ||
          fromOffice.toLowerCase().contains(search) ||
          toOffice.toLowerCase().contains(search);
    }).toList();
  }

  Widget buildTransferCard(Map<String, dynamic> transfer) {
    final employee =
        employees[transfer['employee_id']?.toString()] ?? {};

    final name = employee['full_name'] ?? 'موظف غير معروف';
    final number = employee['employee_number'] ?? '';

    final fromId =
        int.tryParse(transfer['from_office_id'].toString()) ?? -1;

    final toId =
        int.tryParse(transfer['to_office_id'].toString()) ?? -1;

    final fromOffice = offices[fromId] ?? 'غير معروف';
    final toOffice = offices[toId] ?? 'غير معروف';

    final reason = transfer['reason']?.toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE5F2EC),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF145A46),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'الرقم الوطني: $number',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            Row(
              children: [
                const Icon(
                  Icons.business,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('من: '),
                Expanded(
                  child: Text(
                    fromOffice,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.arrow_downward,
                  color: Color(0xFF145A46),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('إلى: '),
                Expanded(
                  child: Text(
                    toOffice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF145A46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatDate(transfer['transferred_at']),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (reason != null && reason.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'سبب النقل: $reason',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

 
  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await TransferHistoryExportService.exportPdf(
        transfers: filteredTransfers,
        employees: employees,
        offices: offices,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تجهيز ملف PDF بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر تصدير PDF: $e')),
      );
    }
  }

  Future<void> _exportExcel() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await TransferHistoryExportService.exportExcel(
        transfers: filteredTransfers,
        employees: employees,
        offices: offices,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تجهيز ملف Excel بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر تصدير Excel: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final filtered = filteredTransfers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(
          title: const Text('سجل تنقلات الموظفين'),
          backgroundColor: const Color(0xFF145A46),
          foregroundColor: Colors.white,
                  actions: [
            IconButton(
              onPressed: isLoading ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
            ),
            IconButton(
              onPressed: isLoading ? null : _exportExcel,
              icon: const Icon(Icons.table_view),
              tooltip: 'تصدير Excel',
            ),
            IconButton(
              onPressed: loadTransfers,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث السجل',
            ),
          ],        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الرقم الوطني أو المكتب',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'حدث خطأ أثناء تحميل السجل:\n$errorMessage',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text('لا توجد عمليات نقل مسجلة'),
                            )
                          : RefreshIndicator(
                              onRefresh: loadTransfers,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  return buildTransferCard(filtered[index]);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}