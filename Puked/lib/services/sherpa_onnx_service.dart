import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sherpa_onnx_service_stub.dart'
    if (dart.library.io) 'sherpa_onnx_service_mobile.dart'
    if (dart.library.html) 'sherpa_onnx_service_web.dart';

abstract class SherpaOnnxService {
  bool get isInitialized;
  double get downloadProgress;
  Stream<String> get statusStream;

  Future<void> init();
  Future<void> startListening({
    required Function(String text) onResult,
    required Function(String category, String text) onFinalResult,
  });
  Future<void> stopListening();
  void dispose();
}

final sherpaOnnxServiceProvider = Provider<SherpaOnnxService>((ref) {
  final service = createSherpaService();
  ref.onDispose(() => service.dispose());
  return service;
});
