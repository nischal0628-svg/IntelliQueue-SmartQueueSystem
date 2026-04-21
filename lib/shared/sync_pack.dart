import 'dart:convert';

import 'package:intelliqueue/shared/data_contract.dart';

/// Sync Pack types
/// - config: Admin -> Mobile (branches/services/counters/staff)
/// - ops: Mobile -> Admin (bookings/queue_state/notifications)
class SyncPackType {
  static const config = 'config';
  static const ops = 'ops';
}

class SyncPackKeys {
  static const version = 'version';
  static const type = 'type';
  static const generatedAt = 'generatedAt';
  static const data = 'data';
}

class SyncPackDataKeys {
  static const branches = HiveBoxes.branches;
  static const services = HiveBoxes.services;
  static const counters = HiveBoxes.counters;
  static const staffUsers = HiveBoxes.staffUsers;

  static const bookings = HiveBoxes.bookings;
  static const queueState = HiveBoxes.queueState;
  static const notifications = HiveBoxes.notifications;
}

class SyncPack {
  static const int currentVersion = 1;

  final int version;
  final String type;
  final String generatedAt; // ISO8601
  final Map<String, dynamic> data;

  const SyncPack({
    required this.version,
    required this.type,
    required this.generatedAt,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        SyncPackKeys.version: version,
        SyncPackKeys.type: type,
        SyncPackKeys.generatedAt: generatedAt,
        SyncPackKeys.data: data,
      };

  String toJsonString({bool pretty = true}) {
    final obj = toJson();
    if (!pretty) return jsonEncode(obj);
    return const JsonEncoder.withIndent('  ').convert(obj);
  }

  static SyncPack fromJsonString(String input) {
    final decoded = jsonDecode(input);
    if (decoded is! Map) {
      throw const FormatException('Invalid JSON (expected object)');
    }
    final map = Map<String, dynamic>.from(decoded);
    final version = map[SyncPackKeys.version];
    final type = map[SyncPackKeys.type];
    final generatedAt = map[SyncPackKeys.generatedAt];
    final dataRaw = map[SyncPackKeys.data];

    if (version is! int) throw const FormatException('Missing/invalid version');
    if (version <= 0 || version > SyncPack.currentVersion) {
      throw FormatException('Unsupported sync pack version: $version');
    }
    if (type is! String || type.isEmpty) throw const FormatException('Missing/invalid type');
    if (generatedAt is! String || generatedAt.isEmpty) {
      throw const FormatException('Missing/invalid generatedAt');
    }
    if (dataRaw is! Map) throw const FormatException('Missing/invalid data');

    return SyncPack(
      version: version,
      type: type,
      generatedAt: generatedAt,
      data: Map<String, dynamic>.from(dataRaw),
    );
  }
}

/// Generic merge helper:
/// - `idKey` identifies unique record
/// - `updatedAtKey` used for “newest wins”
List<Map<String, dynamic>> mergeByUpdatedAt({
  required List<Map<String, dynamic>> existing,
  required List<Map<String, dynamic>> incoming,
  required String idKey,
  String updatedAtKey = 'updatedAt',
}) {
  final out = <String, Map<String, dynamic>>{};

  int ts(String? iso) {
    if (iso == null || iso.isEmpty) return -1;
    try {
      return DateTime.parse(iso).millisecondsSinceEpoch;
    } catch (_) {
      return -1;
    }
  }

  for (final r in existing) {
    final id = (r[idKey] ?? '').toString();
    if (id.isEmpty) continue;
    out[id] = Map<String, dynamic>.from(r);
  }

  for (final r in incoming) {
    final id = (r[idKey] ?? '').toString();
    if (id.isEmpty) continue;
    final next = Map<String, dynamic>.from(r);
    final cur = out[id];
    if (cur == null) {
      out[id] = next;
      continue;
    }

    final curTs = ts((cur[updatedAtKey] ?? cur['createdAt'])?.toString());
    final nextTs = ts((next[updatedAtKey] ?? next['createdAt'])?.toString());
    if (nextTs >= curTs) out[id] = next;
  }

  return out.values.toList();
}

