class ScanResultModel {
  final String value;
  final String type;
  final DateTime timestamp;

  ScanResultModel({
    required this.value,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'value': value,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ScanResultModel.fromJson(Map<String, dynamic> json) =>
      ScanResultModel(
        value: json['value'] as String,
        type: json['type'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
