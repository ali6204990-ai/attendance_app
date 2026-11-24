import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentityService {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _storageKey = 'attendance_device_identity';

  static Future<String> getOrCreateDeviceId() async {
    // البحث عن رمز محفوظ سابقاً
    final existingId = await _storage.read(key: _storageKey);

    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    // إنشاء رمز عشوائي قوي بطول 256 بت
    final random = Random.secure();
    final bytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    final newId = base64Url.encode(bytes).replaceAll('=', '');

    // حفظ الرمز في التخزين الآمن
    await _storage.write(
      key: _storageKey,
      value: newId,
    );

    return newId;
  }
}