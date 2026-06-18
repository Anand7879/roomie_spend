import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A secure storage wrapper utilizing FlutterSecureStorage for local session persistence.
class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Secure Storage Keys
  static const String _keyUid = 'uid';
  static const String _keyPhone = 'phone';
  static const String _keyName = 'name';
  static const String _keyEmail = 'email';

  /// Saves session credentials into secure storage
  Future<void> saveSession({
    required String uid,
    required String phone,
    required String name,
    required String email,
  }) async {
    await _secureStorage.write(key: _keyUid, value: uid);
    await _secureStorage.write(key: _keyPhone, value: phone);
    await _secureStorage.write(key: _keyName, value: name);
    await _secureStorage.write(key: _keyEmail, value: email);
  }

  /// Retrieves the User ID
  Future<String?> getUid() async {
    return await _secureStorage.read(key: _keyUid);
  }

  /// Retrieves the Phone Number
  Future<String?> getPhone() async {
    return await _secureStorage.read(key: _keyPhone);
  }

  /// Retrieves the Name
  Future<String?> getName() async {
    return await _secureStorage.read(key: _keyName);
  }

  /// Retrieves the Email
  Future<String?> getEmail() async {
    return await _secureStorage.read(key: _keyEmail);
  }

  /// Clears all secure credentials on user logout.
  /// Uses deleteAll() for an atomic, single-operation clear — faster and safer
  /// than deleting individual keys, which could leave partial data on crash.
  Future<void> clearSession() async {
    await _secureStorage.deleteAll();
  }
}
