import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sherpa_onnx_service.dart';

class SherpaOnnxServiceWeb implements SherpaOnnxService {
  @override
  bool get isInitialized => false;

  @override
  double get downloadProgress => 0;

  @override
  Stream<String> get statusStream => const Stream.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> startListening({
    required Function(String text) onResult,
    required Function(String category, String text) onFinalResult,
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  void dispose() {}
}

SherpaOnnxService createSherpaService() => SherpaOnnxServiceWeb();
