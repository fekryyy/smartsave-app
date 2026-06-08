class HeatmapData {
  final int year;
  final Map<String, Map<String, dynamic>> heatmap;
  final double maxSpend;

  HeatmapData({
    required this.year,
    this.heatmap = const {},
    this.maxSpend = 0,
  });

  factory HeatmapData.fromJson(Map<String, dynamic> json) {
    return HeatmapData(
      year: json['year'] ?? DateTime.now().year,
      heatmap: json['heatmap'] != null
          ? (json['heatmap'] as Map).map(
              (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)))
          : {},
      maxSpend: (json['maxSpend'] ?? 0).toDouble(),
    );
  }
}
