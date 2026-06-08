class NetWorthEntry {
  final DateTime date;
  final Map<String, double> assets;
  final Map<String, double> liabilities;

  NetWorthEntry({
    DateTime? date,
    Map<String, double>? assets,
    Map<String, double>? liabilities,
  }) : date = date ?? DateTime.now(),
       assets = assets ?? {
         'cash': 0,
         'bankAccounts': 0,
         'savings': 0,
         'investments': 0,
         'otherAssets': 0,
       },
       liabilities = liabilities ?? {
         'creditCardDebt': 0,
         'loans': 0,
         'personalDebt': 0,
         'mortgage': 0,
       };

  double get totalAssets =>
      assets.values.fold(0, (sum, v) => sum + v);
  double get totalLiabilities =>
      liabilities.values.fold(0, (sum, v) => sum + v);
  double get netWorth => totalAssets - totalLiabilities;

  factory NetWorthEntry.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] != null
        ? Map<String, double>.from(
            (json['assets'] as Map).map((k, v) => MapEntry(k, (v ?? 0).toDouble())))
        : null;
    final liabilities = json['liabilities'] != null
        ? Map<String, double>.from(
            (json['liabilities'] as Map).map((k, v) => MapEntry(k, (v ?? 0).toDouble())))
        : null;
    return NetWorthEntry(
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      assets: assets,
      liabilities: liabilities,
    );
  }
}

class NetWorthModel {
  final String id;
  final List<NetWorthEntry> entries;
  final DateTime createdAt;

  NetWorthModel({
    required this.id,
    this.entries = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalAssets => entries.isNotEmpty ? entries.last.totalAssets : 0;
  double get totalLiabilities => entries.isNotEmpty ? entries.last.totalLiabilities : 0;
  double get netWorth => totalAssets - totalLiabilities;

  factory NetWorthModel.fromJson(Map<String, dynamic> json) {
    return NetWorthModel(
      id: json['_id'] ?? json['id'] ?? '',
      entries: json['entries'] != null
          ? (json['entries'] as List).map((e) => NetWorthEntry.fromJson(e)).toList()
          : [],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => {
      'date': e.date.toIso8601String(),
      'assets': e.assets,
      'liabilities': e.liabilities,
    }).toList(),
  };
}
