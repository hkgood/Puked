import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'sherpa_onnx_service.dart';

class SherpaOnnxServiceMobile implements SherpaOnnxService {
  sherpa.OnlineRecognizer? _recognizer;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _recordStateSub;
  StreamSubscription<List<int>>? _audioStreamSub;
  sherpa.OnlineStream? _onlineStream;

  bool _isInitialized = false;
  @override
  bool get isInitialized => _isInitialized;

  bool _isInitializing = false;
  bool _isStopping = false;
  bool _hasBpe = false;
  Completer<void>? _initCompleter;

  static const Map<String, String> _fuzzyCorrections = {
    // 智驾统称
    '质检': '智驾', '指甲': '智驾', '支架': '智驾', '直接': '智驾', '治家': '智驾',
    // 违章/违规
    '胃胀': '违章', '伪装': '违章', '喂脏': '违章', '维障': '违章', '未涨': '违章',
    // 接管动作
    '监管': '接管', '尽管': '接管', '借官': '接管', '街管': '接管', '洁官': '接管', '结果': '接管',
    // 压实线 (核心高频错误)
    '压实现': '压实线', '压时限': '压实线', '要实现': '压实线', '雅诗兰': '压实线', '压食盐': '压实线',
    '压实县': '压实线', '压十线': '压实线', '亚时现': '压实线', '雅视线': '压实线', '压死线': '压实线',
    // 闯红灯
    '创红灯': '闯红灯', '穿红灯': '闯红灯', '川红灯': '闯红灯', '闯红等': '闯红灯', '闯宏灯': '闯红灯',
    // 逆行/走错
    '你行': '逆行', '泥行': '逆行', '拟行': '逆行', '逆性': '逆行',
    '走村': '走错', '走挫': '走错', '走存': '走错', '走错鹿': '走错路',
    // 误刹车/体感
    '误杀车': '误刹车', '误沙车': '误刹车', '雾刹车': '误刹车', '无刹车': '误刹车', '误删车': '误刹车',
    '重杀': '硬刹车', '硬杀': '硬刹车', '重沙': '硬刹车',
    // 画龙/轨迹
    '化龙': '画龙', '花弄': '画龙', '花笼': '画龙', '画隆': '画龙', '划龙': '画龙',
    '归集': '轨迹', '贵机': '轨迹', '硅基': '轨迹', '诡计': '轨迹',
    // 顿挫/卡死/绿灯
    '蹲坐': '顿挫', '吨座': '顿挫', '盾挫': '顿挫', '钝搓': '顿挫',
    '卡斯': '卡死', '卡丝': '卡死', '卡思': '卡死', '咔嘶': '卡死',
    '旅等': '绿灯', '驴等': '绿灯', '滤灯': '绿灯',
    '没懂': '没动', '没冻': '没动',
  };

  double _downloadProgress = 0;
  @override
  double get downloadProgress => _downloadProgress;

  final _statusController = StreamController<String>.broadcast();
  @override
  Stream<String> get statusStream => _statusController.stream;

  late String _modelDir;

  static const Map<String, List<String>> _categoryKeywords = {
    'proDisengagement': [
      '接管',
      '人工',
      '帮一把',
      '自理',
      '没动',
      '不走',
      '卡死',
      '卡住',
      '不动',
      '走错',
      '偏离',
      '自己开'
    ],
    'proViolation': [
      '违章',
      '违规',
      '闯红灯',
      '压线',
      '实线',
      '逆行',
      '导向',
      '禁止',
      '禁行',
      '不按',
      '压到',
      '违返',
      '加塞'
    ],
    'proExperience': [
      '体验',
      '体感',
      '刹车',
      '点头',
      '画龙',
      '摆动',
      '自然',
      '过快',
      '过慢',
      '急转',
      '顿挫',
      '生硬',
      '抖动',
      '轨迹',
      '不爽',
      '难受',
      '太晃',
      '晃动'
    ],
  };

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    if (_isInitializing) return _initCompleter?.future;

    _isInitializing = true;
    _initCompleter = Completer<void>();

    debugPrint('[SherpaOnnx] Initializing service...');
    try {
      sherpa.initBindings();

      final docDir = await getApplicationDocumentsDirectory();
      _modelDir = '${docDir.path}/sherpa_onnx_models';

      if (!await _checkModelsExist()) {
        _statusController.add("START_DOWNLOAD");
        debugPrint('[SherpaOnnx] Core models missing, starting download...');
        await _downloadModels();
      }

      _statusController.add("LOADING_ENGINE");

      final bpePath = '$_modelDir/bpe.model';
      _hasBpe = await File(bpePath).exists();
      debugPrint('[SherpaOnnx] Checking BPE model at $bpePath: $_hasBpe');

      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '$_modelDir/encoder.onnx',
            decoder: '$_modelDir/decoder.onnx',
            joiner: '$_modelDir/joiner.onnx',
          ),
          tokens: '$_modelDir/tokens.txt',
          bpeVocab: _hasBpe ? bpePath : '',
          numThreads: 2,
          // modelingUnit 暂时不传，让引擎根据 tokens.txt 自动推断
        ),
        decodingMethod: 'greedy_search', // 改回最稳定的贪婪搜索模式
        hotwordsScore: 0.0, // 彻底禁用热词分值
        feat: const sherpa.FeatureConfig(
          sampleRate: 16000,
          featureDim: 80,
        ),
      );
      _recognizer = sherpa.OnlineRecognizer(config);
      _isInitialized = true;
      _statusController.add("ENGINE_READY");
      debugPrint('[SherpaOnnx] Initialized successfully.');
      _initCompleter?.complete();
    } catch (e) {
      _statusController.add("INIT_FAILED");
      debugPrint('[SherpaOnnx] Initialization failed: $e');
      _initCompleter?.completeError(e);
    } finally {
      _isInitializing = false;
      _initCompleter = null;
    }
  }

  Future<bool> _checkModelsExist() async {
    final dir = Directory(_modelDir);
    if (!await dir.exists()) return false;

    final coreFiles = [
      'encoder.onnx',
      'decoder.onnx',
      'joiner.onnx',
      'tokens.txt'
    ];
    for (final f in coreFiles) {
      final file = File('$_modelDir/$f');
      if (!await file.exists()) return false;

      // 增加体积校验，防止由于 401/404 或网络中断导致的坏文件
      final length = await file.length();
      if (f.contains('encoder')) {
        // encoder.onnx 完整大小约为 330MB，这里设为 200MB 阈值
        if (length < 200 * 1024 * 1024) return false;
      } else {
        if (length < 1024) return false;
      }
    }
    // 增加 BPE 模型检查 (中英双语模型必须)
    final bpeFile = File('$_modelDir/bpe.model');
    if (!await bpeFile.exists() || await bpeFile.length() < 1024) return false;

    return true;
  }

  Future<void> _downloadModels() async {
    final dir = Directory(_modelDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    const String modelID_HF =
        "csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20";
    const String modelID_MS =
        "pkufool/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20";

    const hfBaseUrl = 'https://huggingface.co/$modelID_HF/resolve/main/';
    const msBaseUrl =
        'https://modelscope.cn/api/v1/models/$modelID_MS/repo?Revision=master&FilePath=';

    // 核心文件列表（包含 bpe.model）
    final files = [
      'encoder-epoch-99-avg-1.onnx',
      'decoder-epoch-99-avg-1.onnx',
      'joiner-epoch-99-avg-1.onnx',
      'tokens.txt',
      'bpe.model',
    ];

    final nameMap = {
      'encoder-epoch-99-avg-1.onnx': 'encoder.onnx',
      'decoder-epoch-99-avg-1.onnx': 'decoder.onnx',
      'joiner-epoch-99-avg-1.onnx': 'joiner.onnx',
      'tokens.txt': 'tokens.txt',
      'bpe.model': 'bpe.model',
    };

    for (int i = 0; i < files.length; i++) {
      final fileName = files[i];
      final targetPath = '$_modelDir/${nameMap[fileName]}';

      final file = File(targetPath);
      if (await file.exists()) {
        final length = await file.length();
        if (fileName.contains('encoder')
            ? length > 200 * 1024 * 1024
            : length > 512) {
          continue;
        }
        await file.delete();
      }

      final fileLabel = nameMap[fileName]!;
      _statusController.add("PROGRESS_STATUS:下载组件 $fileLabel");

      bool success = false;
      final urls = [
        '$hfBaseUrl$fileName',
        '$msBaseUrl${Uri.encodeComponent(fileName)}'
      ];

      for (var url in urls) {
        try {
          debugPrint('[SherpaOnnx] Attempting download: $url');
          await _downloadRobustly(url, targetPath, (percent) {
            _downloadProgress = (i + percent / 100) / files.length;
            _statusController
                .add("PROGRESS:${(_downloadProgress * 100).toInt()}");
          });
          success = true;
          break;
        } catch (e) {
          debugPrint('[SherpaOnnx] Download failed from $url: $e');
        }
      }

      if (!success) {
        throw Exception("Failed to download $fileLabel from all sources");
      }
    }

    _statusController.add("DOWNLOAD_COMPLETE");
  }

  Future<void> _downloadRobustly(
      String url, String savePath, Function(double) onProgress) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    HttpClientResponse? response;
    String currentUrl = url;

    for (int redirectCount = 0; redirectCount < 5; redirectCount++) {
      final request = await client.getUrl(Uri.parse(currentUrl));
      request.followRedirects = false;

      request.headers.set('User-Agent',
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1');
      request.headers.set('Accept', '*/*');

      response = await request.close();

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) break;
        currentUrl = Uri.parse(currentUrl).resolve(location).toString();
        debugPrint('[SherpaOnnx] Redirecting to: $currentUrl');
        continue;
      }
      break;
    }

    if (response == null || response.statusCode != 200) {
      final code = response?.statusCode ?? 0;
      throw Exception('HTTP $code');
    }

    final file = File(savePath);
    final raf = await file.open(mode: FileMode.write);

    final total = response.contentLength;
    int downloaded = 0;

    try {
      await for (var chunk in response) {
        raf.writeFromSync(chunk);
        downloaded += chunk.length;
        if (total > 0) onProgress((downloaded / total) * 100);
      }
    } finally {
      await raf.close();
      client.close();
    }
  }

  String _getHotwords() {
    final Set<String> words = {};
    // 精简热词：仅保留核心事件词，减少底层 C++ 解析压力
    for (var list in _categoryKeywords.values) {
      for (var word in list) {
        if (word.trim().length >= 2) words.add(word.trim());
      }
    }
    // 品牌词
    words.addAll(['小鹏', '华为', '蔚来', '理想', '特斯拉', '智驾', '领航']);

    // 增加一个绝对安全的保底词，确保 hotwords 永远不为空
    words.add('智驾');

    // 过滤掉可能的特殊字符，仅保留中英文和数字
    final hotwordsString = words
        .where((w) =>
            w.trim().isNotEmpty &&
            RegExp(r'^[\u4e00-\u9fa5_a-zA-Z0-9]+$').hasMatch(w))
        .join('/');

    debugPrint('[SherpaDebug] Optimized Hotwords: $hotwordsString');
    return hotwordsString;
  }

  @override
  Future<void> startListening({
    required Function(String text) onResult,
    required Function(String category, String text) onFinalResult,
  }) async {
    if (_onlineStream != null) return;

    if (!_isInitialized) await init();
    if (_recognizer == null) {
      debugPrint('[SherpaOnnx] ERROR: Recognizer is null');
      return;
    }

    if (await _recorder.hasPermission()) {
      debugPrint('[SherpaOnnx] Starting ASR listening...');
      _isStopping = false;

      // 核心热词安全性加固：只有 BPE 存在且热词不为空时才注入
      if (_hasBpe) {
        try {
          _getHotwords();
        } catch (e) {
          debugPrint('[SherpaOnnx] Error generating hotwords: $e');
        }
      }

      try {
        debugPrint(
            '[SherpaOnnx] Creating standard stream (Bypassing hotwords for stability test)');
        // 彻底不传任何热词参数，确保进入 C++ 引擎的是最干净的路径
        _onlineStream = _recognizer!.createStream();
        debugPrint('[SherpaOnnx] Stream created successfully.');
      } catch (e) {
        debugPrint('[SherpaOnnx] CRITICAL: createStream failed: $e');
        return;
      }

      final recognizer = _recognizer!;
      final onlineStream = _onlineStream!;

      // 核心加固：延迟 200ms 启动录音，确保底层引擎 Stream 状态已完全同步
      await Future.delayed(const Duration(milliseconds: 200));

      debugPrint('[SherpaOnnx] Starting recorder stream...');
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      String lastRawText = "";
      DateTime? lastVoiceTime = DateTime.now();

      _audioStreamSub = stream.listen((data) {
        if (_isStopping || _onlineStream == null) return;

        try {
          // 核心修复：增加 null 检查，并确保 byteData 是独立的副本
          final Uint8List byteData = Uint8List.fromList(data);
          if (byteData.length < 2) return;

          final samples = _convertBytesToFloat32(byteData);
          if (samples.isEmpty || _onlineStream == null) return;

          onlineStream.acceptWaveform(samples: samples, sampleRate: 16000);

          while (recognizer.isReady(onlineStream)) {
            recognizer.decode(onlineStream);
          }

          final result = recognizer.getResult(onlineStream);
          final rawText = result.text.trim();
          final now = DateTime.now();

          if (rawText.isNotEmpty && rawText != lastRawText) {
            lastRawText = rawText;
            final correctedText = _applyFuzzyCorrections(rawText);
            debugPrint('[SherpaDebug] 捕获文本: $correctedText');
            onResult(correctedText);
            lastVoiceTime = now;

            final category = _matchCategory(correctedText);
            if (category != 'manual') {
              _isStopping = true;
              debugPrint('[SherpaDebug] 命中核心关键词 [$category]');
              onFinalResult(category, correctedText);
              stopListening();
              return;
            }
          }

          if (lastVoiceTime != null) {
            final silenceMs = now.difference(lastVoiceTime!).inMilliseconds;
            if (silenceMs > 2000) {
              _isStopping = true;
              debugPrint('[SherpaDebug] 静音自动结束');
              if (lastRawText.isNotEmpty) {
                final correctedFinal = _applyFuzzyCorrections(lastRawText);
                onFinalResult(_matchCategory(correctedFinal), correctedFinal);
              } else {
                onFinalResult('none', '');
              }
              stopListening();
            }
          }
        } catch (e) {
          debugPrint('[SherpaOnnx] Error in audio listener: $e');
        }
      });
    }
  }

  Float32List _convertBytesToFloat32(Uint8List byteData) {
    try {
      // 核心修复：使用 asInt16List 严格限制读取范围，避免读取 buffer 中的无关内存
      final int16List = byteData.buffer
          .asInt16List(byteData.offsetInBytes, byteData.length ~/ 2);

      final float32List = Float32List(int16List.length);
      for (int i = 0; i < int16List.length; i++) {
        // PCM 16-bit to Float32 归一化
        float32List[i] = int16List[i] / 32768.0;
      }
      return float32List;
    } catch (e) {
      debugPrint('[SherpaOnnx] Float32 conversion failed: $e');
      return Float32List(0);
    }
  }

  String _applyFuzzyCorrections(String text) {
    String corrected = text;
    _fuzzyCorrections.forEach((key, value) {
      if (corrected.contains(key)) {
        corrected = corrected.replaceAll(key, value);
      }
    });
    return corrected;
  }

  @override
  Future<void> stopListening() async {
    debugPrint('[SherpaOnnx] Stopping ASR listening...');
    _isStopping = true;
    await _recorder.stop();
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    _onlineStream = null;
  }

  String _matchCategory(String text) {
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return 'manual';
  }

  @override
  void dispose() {
    _recordStateSub?.cancel();
    _audioStreamSub?.cancel();
    _onlineStream = null;
    _recognizer = null;
    _recorder.dispose();
  }
}

SherpaOnnxService createSherpaService() => SherpaOnnxServiceMobile();
