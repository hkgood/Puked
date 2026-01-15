class BrandData {
  final String brand; // Canonical Key (ID or Name)
  final String? brandName; // Display Name for Brand
  final String? logoUrl; // 远程 Logo URL (从 expand 中提取)
  final String? version; // Canonical Key (ID or String)
  final String? versionName; // Display Name for Version
  final double? kmPerEvent; // 公里/次
  final double? totalKm; // 总里程
  final int? totalEvents; // 总负体验次数
  final Map<String, double>? breakdown; // 速度区间分布

  BrandData({
    required this.brand,
    this.brandName,
    this.logoUrl,
    this.version,
    this.versionName,
    this.kmPerEvent,
    this.totalKm,
    this.totalEvents,
    this.breakdown,
  });

  String get displayName {
    final bName = brandName ?? brand;
    final vName = versionName ?? version;
    return vName != null ? '$bName $vName' : bName;
  }
}

class VersionEvolutionData {
  final String brand;
  final List<VersionPoint> evolution;

  VersionEvolutionData({
    required this.brand,
    required this.evolution,
  });
}

class VersionPoint {
  final String version;
  final double kmPerEvent;

  VersionPoint({
    required this.version,
    required this.kmPerEvent,
  });
}

class SymptomData {
  final String brand;
  final String? brandName;
  final String? version;
  final String? versionName;
  final Map<String, double> details; // key: symptom name, value: km/event
  final Map<String, int> counts; // key: symptom name, value: absolute count
  final double totalKm;
  final int tripCount;

  SymptomData({
    required this.brand,
    this.brandName,
    this.version,
    this.versionName,
    required this.details,
    required this.counts,
    required this.totalKm,
    required this.tripCount,
  });
}

class UserLeaderboardData {
  final String userName;
  final String? avatarUrl;
  final double totalKm;
  final int tripCount;

  UserLeaderboardData({
    required this.userName,
    this.avatarUrl,
    required this.totalKm,
    required this.tripCount,
  });
}
