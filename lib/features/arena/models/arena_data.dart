class BrandData {
  final String brand;
  final String? version;
  final double? kmPerEvent; // 公里/次
  final double? totalKm; // 总里程

  BrandData({
    required this.brand,
    this.version,
    this.kmPerEvent,
    this.totalKm,
  });

  String get displayName => version != null ? '$brand $version' : brand;
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
  final String? version;
  final Map<String, double> details; // key: symptom name, value: km/event
  final Map<String, int> counts; // key: symptom name, value: absolute count
  final double totalKm;
  final int tripCount;

  SymptomData({
    required this.brand,
    this.version,
    required this.details,
    required this.counts,
    required this.totalKm,
    required this.tripCount,
  });
}
