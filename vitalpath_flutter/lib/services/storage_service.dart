import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/constants/app_constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfilePhoto(String uid, File file) async {
    try {
      final ref = _storage.ref().child('${AppConstants.storageProfilePhotos}/$uid.jpg');
      final task = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadPrescription(String prescriptionId, File file) async {
    try {
      final ext = file.path.split('.').last;
      final ref = _storage.ref().child('${AppConstants.storagePrescriptions}/$prescriptionId.$ext');
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  // Upload with progress callback
  UploadTask uploadWithProgress(String path, File file) {
    final ref = _storage.ref().child(path);
    return ref.putFile(file);
  }
}
