import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfficeManagementPage extends StatefulWidget {
  const OfficeManagementPage({super.key});

  @override
  State<OfficeManagementPage> createState() =>
      _OfficeManagementPageState();
}

class _OfficeManagementPageState extends State<OfficeManagementPage> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _offices = [];

  bool _loading = true;
  bool _saving = false;
  int? _uploadingOfficeId;

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    try {
      final data = await _supabase
          .from('offices')
          .select('id, office_name, logo_url')
          .order('id');

      if (!mounted) return;

      setState(() {
        _offices = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('تعذر تحميل المكاتب: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addOffice() async {
    final officeName = _nameController.text.trim();

    if (officeName.isEmpty) {
      _showMessage('يرجى إدخال اسم المكتب');
      return;
    }

    setState(() => _saving = true);

    try {
      final result = await _supabase.functions.invoke(
        'create-office',
        body: {
          'office_name': officeName,
        },
      );

      final data = result.data;

      if (result.status != 200 || data['success'] != true) {
        throw Exception(data['error'] ?? 'تعذرت إضافة المكتب');
      }

      if (!mounted) return;

      _nameController.clear();

      await _loadOffices();

      if (!mounted) return;

      _showMessage(
        'تمت إضافة المكتب رقم ${data['office']['id']} بنجاح',
      );
    } on FunctionException catch (e) {
      if (mounted) {
        _showMessage(
          'تعذر إضافة المكتب: ${e.details ?? e.reasonPhrase}',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadOfficeLogo(
    Map<String, dynamic> office,
  ) async {
    final officeId = (office['id'] as num).toInt();

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedImage == null) return;

      if (!mounted) return;

      setState(() => _uploadingOfficeId = officeId);

      final bytes = await pickedImage.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('الصورة المختارة فارغة');
      }

      final extension = pickedImage.name.contains('.')
          ? pickedImage.name.split('.').last.toLowerCase()
          : 'jpg';

      final safeExtension = RegExp(r'^[a-z0-9]+$')
              .hasMatch(extension)
          ? extension
          : 'jpg';

      final contentType = pickedImage.mimeType ??
          (safeExtension == 'png'
              ? 'image/png'
              : safeExtension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg');

      final filePath =
          'office_$officeId/logo_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

      // رفع الصورة إلى مخزن الشعارات
      await _supabase.storage
          .from('office-logos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
            ),
          );

      // الحصول على رابط الصورة العام
      final logoUrl = _supabase.storage
          .from('office-logos')
          .getPublicUrl(filePath);

      // حفظ الرابط في جدول المكاتب
      await _supabase
          .from('offices')
          .update({
            'logo_url': logoUrl,
          })
          .eq('id', officeId);

      if (!mounted) return;

      await _loadOffices();

      if (!mounted) return;

      _showMessage(
        'تم رفع شعار ${office['office_name']} بنجاح',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر رفع الشعار: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingOfficeId = null);
      }
    }
  }

  Widget _buildOfficeLogo(Map<String, dynamic> office) {
    final logoUrl = office['logo_url']?.toString();

    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF145A46),
          width: 0.7,
        ),
      ),
      child: logoUrl == null || logoUrl.isEmpty
          ? const Icon(
              Icons.business,
              size: 30,
              color: Color(0xFF145A46),
            )
          : Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المكاتب'),
        backgroundColor: const Color(0xFF145A46),
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المكتب الجديد',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _addOffice,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _saving
                                ? 'جارٍ الإضافة...'
                                : 'إضافة مكتب',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'المكاتب المسجلة (${_offices.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOffices,
                        child: ListView.builder(
                          itemCount: _offices.length,
                          itemBuilder: (context, index) {
                            final office = _offices[index];
                            final officeId =
                                (office['id'] as num).toInt();

                            final uploading =
                                _uploadingOfficeId == officeId;

                            return Card(
                              child: ListTile(
                                leading: _buildOfficeLogo(office),
                                title: Text(
                                  office['office_name'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'رقم المكتب: $officeId',
                                ),
                                trailing: IconButton(
                                  tooltip: 'رفع أو تغيير الشعار',
                                  onPressed: uploading ||
                                          _uploadingOfficeId != null
                                      ? null
                                      : () => _uploadOfficeLogo(
                                            office,
                                          ),
                                  icon: uploading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_photo_alternate,
                                          color: Color(0xFF145A46),
                                          size: 28,
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}