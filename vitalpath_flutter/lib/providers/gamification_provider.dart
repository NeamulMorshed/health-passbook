import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gamification.dart';
import '../services/gamification_service.dart';

final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return GamificationService(FirebaseFirestore.instance);
});

final gamificationProvider = StreamProvider.family<GamificationProfile, String>((ref, uid) {
  return ref.watch(gamificationServiceProvider).watchProfile(uid);
});
