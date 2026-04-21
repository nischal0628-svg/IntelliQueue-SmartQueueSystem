import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';

void main() {
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('intelliqueue_hive_test_');
    await LocalAuth.initForTests(dir.path);
  });

  tearDown(() async {
    await LocalAuth.resetForTests();
  });

  test('Sign up + sign in works offline', () async {
    final r1 = await LocalAuth.signUp(
      name: 'Test User',
      phone: '9990001111',
      email: 'test@example.com',
      password: 'password123',
    );
    expect(r1.ok, true);

    await LocalAuth.signOut();

    final r2 = await LocalAuth.signIn(
      phone: '9990001111',
      password: 'password123',
    );
    expect(r2.ok, true);
    expect(LocalAuth.currentUserPhone(), '9990001111');
  });

  test('Cannot create multiple active bookings', () async {
    await LocalAuth.signUp(
      name: 'Test User',
      phone: '9990002222',
      email: 'test2@example.com',
      password: 'password123',
    );

    final branches = await LocalAuth.listBranches();
    expect(branches.isNotEmpty, true);
    final branchId = (branches.first['branchId'] ?? '').toString();
    expect(branchId.isNotEmpty, true);

    final services = await LocalAuth.listServicesForBranch(branchId);
    final service = services.firstWhere((s) => s['isActive'] == true);
    final serviceId = (service['serviceId'] ?? '').toString();
    expect(serviceId.isNotEmpty, true);

    final a = await LocalAuth.createBookingForCurrentUser(
      branchId: branchId,
      serviceId: serviceId,
      tokenType: 'Normal',
    );
    expect(a.ok, true);

    final b = await LocalAuth.createBookingForCurrentUser(
      branchId: branchId,
      serviceId: serviceId,
      tokenType: 'VIP',
    );
    expect(b.ok, false);
  });

  test('Settings toggles persist in session box', () async {
    await LocalAuth.signUp(
      name: 'Test User',
      phone: '9990003333',
      email: 'test3@example.com',
      password: 'password123',
    );

    expect(LocalAuth.notificationsEnabled(), true);
    await LocalAuth.setNotificationsEnabled(false);
    expect(LocalAuth.notificationsEnabled(), false);

    expect(LocalAuth.themeModePreference(), 'system');
    await LocalAuth.setThemeModePreference('dark');
    expect(LocalAuth.themeModePreference(), 'dark');

    await LocalAuth.setAccentColorValue(0xFF112233);
    expect(LocalAuth.accentColorValue(), 0xFF112233);
  });
}

