// ============================================================
// 此文件包含需要添加到 sensor_engine.dart 的新代码
// 请按照注释中的说明手动合并
// ============================================================

// ========== 1. 在 _processTick 第144行之后添加 ==========
    // ✅ 新增：静止检测与自动校准触发
    _checkStationaryAndTriggerAutoCalibration(_lastKnownSpeed, now);

// ========== 2. 在 Stage 4 之后（第166行）添加 ==========
    // ✅ Stage 5: 静止时强制归零（鲁棒性增强）
    if (_isVehicleStationary(_lastKnownSpeed, now) && _isCalibrated) {
      final stationaryDuration = now.difference(_stationaryStartTime!);
      
      // 渐进式归零：静止1-3秒，指数衰减
      if (stationaryDuration.inSeconds < 3) {
        final decay = math.pow(0.85, stationaryDuration.inSeconds.toDouble());
        processedAccel *= decay;
      } 
      // 强制归零：静止超过3秒
      else {
        processedAccel = Vector3.zero();
      }
    }

// ========== 3. 在calibrate函数之前（第369行）添加枚举 ==========
  /// ✅ 校准模式枚举
  enum _CalibrationMode {
    manual,  // 手动校准：用户点击按钮，等待采集
    auto,    // 自动校准：从缓冲区提取数据
  }

// ========== 4. 完全替换 calibrate 函数（第370-472行） ==========
  /// 顶级校准逻辑：增加状态重置、方差校验和陀螺仪守卫，确保校准是绝对干净的
  /// 外部调用接口（向后兼容）
  Future<void> calibrate({double currentSpeedMs = 0.0}) async {
    await _calibrateInternal(
      currentSpeedMs: currentSpeedMs,
      mode: _CalibrationMode.manual,
      durationSeconds: 3,
    );
  }

  /// ✅ 统一的校准内核：支持手动和自动两种模式
  Future<void> _calibrateInternal({
    required double currentSpeedMs,
    required _CalibrationMode mode,
    required int durationSeconds,
  }) async {
    // 0. 车辆静止守卫：通过 GPS 速度判定 (放宽到 0.5m/s = 1.8km/h)
    if (currentSpeedMs > 0.5) {
      throw Exception("calibration_failed_stationary");
    }

    List<Vector3> accelSamples = [];
    List<Vector3> magSamples = [];
    List<double> gyroMagnitudes = [];

    // 根据模式选择数据采集策略
    if (mode == _CalibrationMode.manual) {
      // === 手动模式：实时采集数据 ===
      const int sampleCount = 60; // 3秒 @ 20Hz
      const int skipSamples = 10; // 丢弃前0.5秒
      
      // 1. 彻底清空旧的校准状态，确保二次校准不受干扰
      _isCalibrated = false;
      _rotationMatrix = Matrix3.identity();
      _staticGravityRaw = Vector3.zero();
      _dynamicYawOffset = 0.0;
      _isHeadingAligned = false;
      _headingLearningBuffer.clear();
      
      for (int i = 0; i < sampleCount + skipSamples; i++) {
        if (i >= skipSamples) {
          accelSamples.add(_latestAccel.clone());
          magSamples.add(_latestMag.clone());
          gyroMagnitudes.add(_latestGyro.length);
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
    } else {
      // === 自动模式：从缓冲区提取数据 ===
      // 提取最近N秒的数据（已经是完全静止的数据）
      final now = DateTime.now();
      final startTime = now.subtract(Duration(seconds: durationSeconds));
      
      // 从缓冲区筛选指定时间范围的数据
      final relevantData = _buffer.where((d) => 
        d.timestamp.isAfter(startTime) && d.timestamp.isBefore(now)
      ).toList();
      
      if (relevantData.isEmpty || relevantData.length < 30) {
        throw Exception("calibration_failed_insufficient_data");
      }
      
      // 提取原始传感器数据
      for (var data in relevantData) {
        accelSamples.add(data.accelerometer.clone());
        magSamples.add(data.magnetometer.clone());
        gyroMagnitudes.add(data.gyroscope.length);
      }
      
      debugPrint('🔍 [Auto-Calibration] Extracted ${accelSamples.length} samples from buffer');
    }

    // === 以下逻辑对两种模式完全相同 ===
    
    // 2. 陀螺仪守卫：检测校准期间是否有任何晃动
    final maxGyro = gyroMagnitudes.reduce(math.max);
    if (maxGyro > 0.3) {
      throw Exception("calibration_failed_motion");
    }

    // 3. 计算均值和方差
    Vector3 gMean = Vector3.zero();
    Vector3 mMean = Vector3.zero();
    for (int i = 0; i < accelSamples.length; i++) {
      gMean += accelSamples[i];
      mMean += magSamples[i];
    }
    gMean /= accelSamples.length.toDouble();
    mMean /= magSamples.length.toDouble();

    double variance = 0;
    for (var s in accelSamples) {
      variance += (s - gMean).length2;
    }
    variance /= accelSamples.length;

    if (variance > 0.15) {
      throw Exception("calibration_failed_motion");
    }

    final gravityMag = gMean.length;
    if (gravityMag < 8.0 || gravityMag > 12.0) {
      throw Exception("sensor_error");
    }

    // 4. 构建 3D 姿态矩阵 (支持水平倾斜/Yaw 对齐)
    // 第一性原理：利用重力确定垂直面，利用磁力计锁定水平参考
    final unitZ = gMean.normalized();

    // 计算 X 轴：磁场与重力的叉乘得到"水平东向"
    Vector3 unitX = mMean.cross(unitZ).normalized();
    // 鲁棒性：如果磁力计失效或与重力共线，退回到默认参考
    if (unitX.length < 0.1) {
      Vector3 reference =
          unitZ.y.abs() > 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
      unitX = reference.cross(unitZ).normalized();
    }

    // 计算 Y 轴：Z 和 X 叉乘得到"水平北向"
    final unitY = unitZ.cross(unitX).normalized();

    final rot = Matrix3.columns(unitX, unitY, unitZ);
    
    // ✅ 自动模式下只更新重力向量，保持旋转矩阵不变（避免重置航向）
    if (mode == _CalibrationMode.auto && _isCalibrated) {
      // 只更新重力向量，不重置其他状态
      _staticGravityRaw = gMean.clone();
      debugPrint('🔄 [Auto-Calibration] Updated gravity vector only');
    } else {
      // 手动模式：应用完整校准
      _rotationMatrix = rot.isIdentity() ? rot : Matrix3.copy(rot)..invert();
      _staticGravityRaw = gMean.clone();
      _isCalibrated = true;
    }

    // 5. 计算物理角度用于输出验证
    final pitch = math.asin(-unitZ.y.clamp(-1.0, 1.0)) * 180 / math.pi;
    final roll = math.atan2(unitZ.x, unitZ.z) * 180 / math.pi;

    debugPrint("=== Calibration Confirmed [${mode.name.toUpperCase()}] ===");
    debugPrint(
        "Orientation: Pitch ${pitch.toStringAsFixed(1)}°, Roll ${roll.toStringAsFixed(1)}°");
    debugPrint(
        "Static Gravity Vector: ${gMean.x.toStringAsFixed(3)}, ${gMean.y.toStringAsFixed(3)}, ${gMean.z.toStringAsFixed(3)}");
    debugPrint(
        "Variance: ${variance.toStringAsFixed(4)}, Max Gyro: ${maxGyro.toStringAsFixed(3)} rad/s");
    debugPrint(
        "Sample Count: ${accelSamples.length}");

    _processTick(DateTime.now());

    final firstPoint = _rotationMatrix.transformed(gMean - _staticGravityRaw);
    debugPrint(
        "Initial Processed (Should be 0): ${firstPoint.x.toStringAsFixed(3)}, ${firstPoint.y.toStringAsFixed(3)}, ${firstPoint.z.toStringAsFixed(3)}");
    debugPrint("==============================");
  }
