import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class OfficeLocationsPage extends StatefulWidget {
  const OfficeLocationsPage({super.key});

  @override
  State<OfficeLocationsPage> createState() =>
      _OfficeLocationsPageState();
}

class _OfficeLocationsPageState
    extends State<OfficeLocationsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _offices = [];
  int? _selectedOfficeId;
  bool _loading = true;
  bool _gettingLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _supabase
          .from('offices')
          .select(
            'id, office_name, latitude, longitude, allowed_radius_meters',
          )
          .order('id');

      final offices = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      if (!mounted) return;

      setState(() {
        _offices = offices;

        if (_selectedOfficeId == null ||
            !offices.any(
              (o) => (o['id'] as num).toInt() == _selectedOfficeId,
            )) {
          _selectedOfficeId = offices.isEmpty
              ? null
              : (offices.first['id'] as num).toInt();
        }

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

  Map<String, dynamic>? get _selectedOffice {
    for (final office in _offices) {
      if ((office['id'] as num).toInt() == _selectedOfficeId) {
        return office;
      }
    }
    return null;
  }

  Future<void> _captureAndSaveLocation() async {
    if (_selectedOfficeId == null) {
      _showMessage('اختر المكتب أولاً');
      return;
    }

    setState(() => _gettingLocation = true);

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw Exception('يرجى تشغيل خدمة الموقع GPS');
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('لم يتم السماح باستخدام الموقع');
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        throw Exception('يرجى السماح بالموقع من إعدادات الهاتف');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final result = await _supabase
          .from('offices')
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
          })
          .eq('id', _selectedOfficeId!)
          .select('id');

      if (result.isEmpty) {
        throw Exception('لم يتم حفظ الإحداثيات');
      }

      if (!mounted) return;

      final index = _offices.indexWhere(
        (o) => (o['id'] as num).toInt() == _selectedOfficeId,
      );

      if (index != -1) {
        setState(() {
          _offices[index]['latitude'] = position.latitude;
          _offices[index]['longitude'] = position.longitude;
        });
      }

      _showMessage('تم حفظ موقع المكتب بنجاح');
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final office = _selectedOffice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة مواقع المكاتب'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('تعذر تحميل المكاتب\n$_error'),
                      ElevatedButton(
                        onPressed: _loadOffices,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOffices,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'تحديد مواقع المكاتب العشرين',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'اختر المكتب، ثم اضغط على زر تحديد الموقع الحالي لحفظ إحداثياته.',
                      ),
                      const SizedBox(height: 20),

                      DropdownButtonFormField<int>(
                        initialValue: _selectedOfficeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'اختر المكتب',
                          border: OutlineInputBorder(),
                        ),
                        items: _offices.map((o) {
                          return DropdownMenuItem<int>(
                            value: (o['id'] as num).toInt(),
                            child: Text(o['office_name'].toString()),
                          );
                        }).toList(),
                        onChanged: _gettingLocation
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedOfficeId = value;
                                });
                              },
                      ),

                      const SizedBox(height: 20),

                      if (office != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  office['office_name'].toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(),
                                Text(
                                  'خط العرض: ${office['latitude'] ?? 'غير محدد'}',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'خط الطول: ${office['longitude'] ?? 'غير محدد'}',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'نطاق السماح: ${office['allowed_radius_meters']} متر',
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      ElevatedButton.icon(
                        onPressed: _gettingLocation
                            ? null
                            : _captureAndSaveLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text(
                          'تحديد الموقع الحالي وحفظه',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                        ),
                      ),

                      if (_gettingLocation) ...[
                        const SizedBox(height: 20),
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text('جارٍ تحديد الموقع وحفظه...'),
                        ),
                      ],

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: _loadOffices,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث المكاتب'),
                      ),
                    ],
                  ),
                ),
    );
  }
}