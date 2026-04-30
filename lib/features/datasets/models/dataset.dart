import 'package:uuid/uuid.dart';

import '../../../shared/utils/json_preservation.dart';

const _dataSetStorageLinkJsonKeys = {'deviceId', 'storageIndices'};

const _dataSetJsonKeys = {'id', 'name', 'emoji', 'storageLinks', 'modifiedAt'};

const _dataSetDataJsonKeys = {'datasets'};

/// A reference from a DataSet to one or more storage slots on a specific device.
class DataSetStorageLink {
  final String deviceId;
  final List<int> storageIndices;
  final Map<String, dynamic> extraJson;

  const DataSetStorageLink({
    required this.deviceId,
    this.storageIndices = const [],
    this.extraJson = const {},
  });

  Map<String, dynamic> toJson() => {
    ...extraJson,
    'deviceId': deviceId,
    'storageIndices': storageIndices,
  };

  factory DataSetStorageLink.fromJson(Map<String, dynamic> json) =>
      DataSetStorageLink(
        deviceId: json['deviceId'] as String,
        storageIndices:
            (json['storageIndices'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
        extraJson: unknownJsonFields(json, _dataSetStorageLinkJsonKeys),
      );

  DataSetStorageLink mergeUnknownFieldsFrom(
    DataSetStorageLink other, {
    DataSetStorageLink? base,
  }) {
    return DataSetStorageLink.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// A named data‑set that spans one or more device storage slots.
class DataSet {
  final String id;
  final String name;
  final String emoji;
  final List<DataSetStorageLink> storageLinks;
  final DateTime modifiedAt;
  final Map<String, dynamic> extraJson;

  DataSet({
    String? id,
    required this.name,
    required this.emoji,
    this.storageLinks = const [],
    DateTime? modifiedAt,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4(),
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
      extraJson: extraJson,
    );
  }

  Map<String, dynamic> toJson() => {
    ...extraJson,
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
    storageLinks:
        (json['storageLinks'] as List<dynamic>?)
            ?.map((e) => DataSetStorageLink.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    extraJson: unknownJsonFields(json, _dataSetJsonKeys),
  );

  DataSet mergeUnknownFieldsFrom(DataSet other, {DataSet? base}) {
    final json = toJson();
    json.addAll(
      mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    );

    if (storageLinks.isNotEmpty) {
      json['storageLinks'] = [
        for (var i = 0; i < storageLinks.length; i++)
          storageLinks[i]
              .mergeUnknownFieldsFrom(
                i < other.storageLinks.length
                    ? other.storageLinks[i]
                    : const DataSetStorageLink(deviceId: ''),
                base: base != null && i < base.storageLinks.length
                    ? base.storageLinks[i]
                    : null,
              )
              .toJson(),
      ];
    }

    return DataSet.fromJson(json);
  }
}

/// Top-level data container for data‑sets, persisted to disk.
class DataSetData {
  final List<DataSet> datasets;
  final Map<String, dynamic> extraJson;

  const DataSetData({this.datasets = const [], this.extraJson = const {}});

  Map<String, dynamic> toJson() => {
    ...extraJson,
    'datasets': datasets.map((d) => d.toJson()).toList(),
  };

  factory DataSetData.fromJson(Map<String, dynamic> json) => DataSetData(
    datasets:
        (json['datasets'] as List<dynamic>?)
            ?.map((e) => DataSet.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    extraJson: unknownJsonFields(json, _dataSetDataJsonKeys),
  );
}
