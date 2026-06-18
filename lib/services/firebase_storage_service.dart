import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Database service class interfacing with Firebase Storage SDK.
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a file to a specified path in Firebase Storage and returns the download URL.
  Future<String> uploadFile({
    required String path,
    required File file,
  }) async {
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Deletes a file at a specified path in Firebase Storage.
  Future<void> deleteFile(String path) async {
    final ref = _storage.ref().child(path);
    await ref.delete();
  }
}
