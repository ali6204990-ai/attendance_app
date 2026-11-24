import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceRequestsPage extends StatefulWidget {
  const DeviceRequestsPage({super.key});

  @override
  State<DeviceRequestsPage> createState() => _DeviceRequestsPageState();
}

class _DeviceRequestsPageState extends State<DeviceRequestsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _supabase.rpc(
        'get_pending_employee_device_requests',
      );

      if (!mounted) return;

      setState(() {
        _requests = (result as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحميل الطلبات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reviewRequest(
    Map<String, dynamic> request,
    bool approve,
  ) async {
    if (_isProcessing) return;

    final requestId = request['request_id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'اعتماد الهاتف' : 'رفض الطلب'),
        content: Text(
          approve
              ? 'هل تريد اعتماد هاتف الموظف ${request['full_name']}؟'
              : 'هل تريد رفض طلب اعتماد هاتف الموظف ${request['full_name']}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'اعتماد' : 'رفض'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (approve) {
        await _supabase.rpc(
          'approve_employee_device',
          params: {'p_request_id': requestId},
        );
      } else {
        await _supabase.rpc(
          'reject_employee_device_request',
          params: {
            'p_request_id': requestId,
            'p_review_note': 'تم رفض الطلب من المدير الرئيسي',
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'تم اعتماد الهاتف بنجاح' : 'تم رفض الطلب',
          ),
        ),
      );

      await _loadRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنفيذ العملية: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات اعتماد الهواتف'),
        backgroundColor: const Color(0xFF145A46),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الطلبات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadRequests,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _requests.isEmpty
                  ? const Center(
                      child: Text('لا توجد طلبات اعتماد معلقة حالياً'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final request = _requests[index];

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request['full_name']?.toString() ??
                                        'موظف بدون اسم',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'الرقم الوظيفي: ${request['employee_number'] ?? '-'}',
                                  ),
                                  Text(
                                    'المكتب: ${request['office_name'] ?? '-'}',
                                  ),
                                  Text(
                                    'الهاتف: ${request['device_name'] ?? '-'}',
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isProcessing
                                              ? null
                                              : () => _reviewRequest(
                                                    request,
                                                    true,
                                                  ),
                                          icon: const Icon(Icons.check),
                                          label: const Text('اعتماد'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isProcessing
                                              ? null
                                              : () => _reviewRequest(
                                                    request,
                                                    false,
                                                  ),
                                          icon: const Icon(Icons.close),
                                          label: const Text('رفض'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
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