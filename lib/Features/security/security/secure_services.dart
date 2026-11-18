// lib/security/secure_services.dart
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecureServices {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'app_pin';
  static const _encKeyKey = 'enc_key';

  static enc.Key? _aesKey;

  // ================== التهيئة العامة (تستدعى في main) ==================
  static Future<void> init() async {
    // توليد مفتاح تشفير عشوائي مرة واحدة فقط
    String? keyBase64 = await _storage.read(key: _encKeyKey);
    if (keyBase64 == null) {
      final rand = Random.secure();
      final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
      keyBase64 = base64UrlEncode(bytes);
      await _storage.write(key: _encKeyKey, value: keyBase64);
    }
    _aesKey = enc.Key(base64Url.decode(keyBase64));
  }

  // ================== تشفير / فك تشفير نص ==================
  static String encryptText(String plain) {
    if (_aesKey == null) {
      throw Exception('SecureServices.init() لم تُستدعى');
    }
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    // نخزن الـ iv مع النص
    final out = jsonEncode({
      'iv': base64UrlEncode(iv.bytes),
      'data': encrypted.base64,
    });
    return out;
  }

  static String decryptText(String cipherJson) {
    if (_aesKey == null) {
      throw Exception('SecureServices.init() لم تُستدعى');
    }
    final map = jsonDecode(cipherJson) as Map<String, dynamic>;
    final ivBytes = base64Url.decode(map['iv'] as String);
    final dataBase64 = map['data'] as String;

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt64(dataBase64, iv: iv);
    return decrypted;
  }

  // ================== إدارة رقم الدخول (PIN) ==================
  static Future<bool> hasPin() async {
    final val = await _storage.read(key: _pinKey);
    return val != null && val.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    // ممكن هنا تشفّر الـ pin أو تعمل له hash، لكن secure_storage أصلاً مشفّر
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<bool> validatePin(String pin) async {
    final saved = await _storage.read(key: _pinKey);
    if (saved == null) return false;
    return saved == pin;
  }

  // ================== البصمة / FaceID ==================
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'الرجاء التحقق بالبصمة / Face ID للدخول',
      );
      return result;
    } catch (_) {
      return false;
    }
  }
}
