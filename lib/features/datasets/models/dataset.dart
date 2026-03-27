import 'package:uuid/uuid.dart';

/// A reference from a DataSet to one or more storage slots on a specific device.
class DataSetStorageLink {
  final String deviceId;
  final List<int> storageIndices;

  const DataSetStorageLink({
    required this.deviceId,
    this.storageIndices = const [],
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'storageIndices': storageIndices,
      };

  factory DataSetStorageLink.fromJson(Map<String, dynamic> json) =>
      DataSetStorageLink(
        deviceId: json['deviceId'] as String,
        storageIndices: (json['storageIndices'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
      );
}

/// A named data‑set that spans one or more device storage slots.
class DataSet {
  final String id;
  final String name;
  final String emoji;
  final List<DataSetStorageLink> storageLinks;
  final DateTime modifiedAt;

  DataSet({
    String? id,
    required this.name,
    required this.emoji,
    this.storageLinks = const [],
    DateTime? modifiedAt,
  })  : id = id ?? const Uuid().v4(),
        modifiedAt = modifiedAt ?? DateTime.now();

  DataSet copyWith({
    String? name,
    String? emoji,
    List<DataSetStorageLink>? storageLinks,
    DateTime? modifiedAt,
  }) {
    return DataSet(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      storageLinks: storageLinks ?? this.storageLinks,
      modifiedAt: modifiedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        if (storageLinks.isNotEmpty)
          'storageLinks': storageLinks.map((l) => l.toJson()).toList(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  factory DataSet.fromJson(Map<String, dynamic> json) => DataSet(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '📁',
        storageLinks: (json['storageLinks'] as List<dynamic>?)
                ?.map((e) =>
                    DataSetStorageLink.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      );
}

/// Top-level data container for data‑sets, persisted to disk.
class DataSetData {
  final List<DataSet> datasets;

  const DataSetData({this.datasets = const []});

  Map<String, dynamic> toJson() => {
        'datasets': datasets.map((d) => d.toJson()).toList(),
      };

  factory DataSetData.fromJson(Map<String, dynamic> json) => DataSetData(
        datasets: (json['datasets'] as List<dynamic>?)
                ?.map((e) => DataSet.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
