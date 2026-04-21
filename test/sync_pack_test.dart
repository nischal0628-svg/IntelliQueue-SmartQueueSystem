import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/shared/sync_pack.dart';

void main() {
  test('SyncPack rejects unsupported version', () {
    final json = '''
{
  "version": 999,
  "type": "ops",
  "generatedAt": "2026-01-01T00:00:00.000Z",
  "data": {}
}
''';
    expect(() => SyncPack.fromJsonString(json), throwsFormatException);
  });

  test('mergeByUpdatedAt newest wins', () {
    final existing = [
      {"id": "a", "updatedAt": "2026-01-01T00:00:00.000Z", "v": 1},
    ];
    final incoming = [
      {"id": "a", "updatedAt": "2026-01-02T00:00:00.000Z", "v": 2},
    ];
    final merged = mergeByUpdatedAt(existing: existing, incoming: incoming, idKey: "id");
    expect(merged.length, 1);
    expect(merged.first["v"], 2);
  });

  test('Mobile importOpsSyncPackJson merges broadcast notifications', () async {
    final dir = await Directory.systemTemp.createTemp('intelliqueue_hive_test_');
    await LocalAuth.initForTests(dir.path);
    await LocalAuth.signUp(
      name: 'User',
      phone: '9990004444',
      email: 'u4@example.com',
      password: 'password123',
    );

    final pack = SyncPack(
      version: SyncPack.currentVersion,
      type: SyncPackType.ops,
      generatedAt: DateTime.now().toIso8601String(),
      data: {
        "bookings": [],
        "queue_state": [],
        "notifications": [
          {
            "notificationId": "n_test_1",
            "userPhone": "",
            "title": "Announcement",
            "subtitle": "Queue will close in 10 minutes",
            "type": "broadcast",
            "relatedBookingId": "",
            "isRead": false,
            "createdAt": "2026-01-01T00:00:00.000Z",
            "updatedAt": "2026-01-01T00:00:00.000Z"
          }
        ]
      },
    ).toJsonString(pretty: false);

    final r = await LocalAuth.importOpsSyncPackJson(pack);
    expect(r.ok, true);

    final list = await LocalAuth.listNotificationsForCurrentUser();
    expect(list.any((n) => (n["notificationId"] ?? "") == "n_test_1"), true);

    await LocalAuth.resetForTests();
  });
}

