import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intelliqueue/shared/data_contract.dart';
import 'package:intelliqueue/shared/sync_pack.dart';
import 'package:intelliqueue/shared/api_config.dart';
import 'package:http/http.dart' as http;

class LocalAuthResult {
  final bool ok;
  final String? message;

  const LocalAuthResult._(this.ok, this.message);

  const LocalAuthResult.ok() : this._(true, null);

  const LocalAuthResult.fail(String message) : this._(false, message);
}

enum _BackendLoginResult {
  ok,
  invalidCredentials,
  offline,
  notConfigured,
}

class LocalAuth {
  static const String _usersBoxName = HiveBoxes.users;
  static const String _sessionBoxName = HiveBoxes.session;
  static const String _sessionKeyCurrentPhone = 'currentUserPhone';
  static const String _sessionKeyNotificationsEnabled = 'notificationsEnabled';
  static const String _sessionKeyThemeMode = 'themeMode'; // system/light/dark
  static const String _sessionKeyAccentColor = 'accentColor'; // int ARGB
  static const String _sessionKeyApiBaseUrl = 'apiBaseUrl';
  static const String _sessionKeyWipeDemoDone = 'wipeDemoDone_v1';
  static const String _branchesBoxName = HiveBoxes.branches;
  static const String _servicesBoxName = HiveBoxes.services;
  static const String _bookingsBoxName = HiveBoxes.bookings;
  static const String _queueStateBoxName = HiveBoxes.queueState;
  static const String _notificationsBoxName = HiveBoxes.notifications;
  static const String _feedbackBoxName = HiveBoxes.feedback;

  static late Box<Map> _usersBox;
  static late Box _sessionBox;
  static late Box<Map> _branchesBox;
  static late Box<Map> _servicesBox;
  static late Box<Map> _bookingsBox;
  static late Box<Map> _queueStateBox;
  static late Box<Map> _notificationsBox;
  static late Box<Map> _feedbackBox;
  static Timer? _queueTimer;
  static const int _defaultCounters = 3;
  static bool _initialized = false;
  static const Set<String> _activeBookingStatuses = {'active', 'waiting', 'serving'};

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _usersBox = await Hive.openBox<Map>(_usersBoxName);
    _sessionBox = await Hive.openBox(_sessionBoxName);
    _branchesBox = await Hive.openBox<Map>(_branchesBoxName);
    _servicesBox = await Hive.openBox<Map>(_servicesBoxName);
    _bookingsBox = await Hive.openBox<Map>(_bookingsBoxName);
    _queueStateBox = await Hive.openBox<Map>(_queueStateBoxName);
    _notificationsBox = await Hive.openBox<Map>(_notificationsBoxName);
    _feedbackBox = await Hive.openBox<Map>(_feedbackBoxName);

    // One-time demo reset: remove previously created users/tokens/services from Hive.
    // This gives a clean start for thesis demo data.
    if (_sessionBox.get(_sessionKeyWipeDemoDone) != true) {
      await _usersBox.clear();
      await _bookingsBox.clear();
      await _queueStateBox.clear();
      await _notificationsBox.clear();
      await _feedbackBox.clear();
      await _sessionBox.clear();
      await _sessionBox.put(_sessionKeyWipeDemoDone, true);
    }

    await _seedMasterDataIfNeeded();
    if (_sessionBox.get(_sessionKeyNotificationsEnabled) == null) {
      await _sessionBox.put(_sessionKeyNotificationsEnabled, true);
    }
    if (_sessionBox.get(_sessionKeyThemeMode) == null) {
      await _sessionBox.put(_sessionKeyThemeMode, 'system');
    }
    final api = apiBaseUrlPreference();
    if (api != null && api.isNotEmpty) {
      ApiConfig.setRuntimeBaseUrl(api);
    }
    _initialized = true;

    // Best-effort: if an active booking exists, try syncing it to backend once.
    unawaited(_trySyncActiveBookingToBackend());
  }

  static bool isInitialized() => _initialized;

  /// Test-only initializer: uses a provided directory path instead of platform
  /// application documents storage. Keeps production `init()` unchanged.
  static Future<void> initForTests(String hivePath) async {
    if (_initialized) return;
    Hive.init(hivePath);
    _usersBox = await Hive.openBox<Map>(_usersBoxName);
    _sessionBox = await Hive.openBox(_sessionBoxName);
    _branchesBox = await Hive.openBox<Map>(_branchesBoxName);
    _servicesBox = await Hive.openBox<Map>(_servicesBoxName);
    _bookingsBox = await Hive.openBox<Map>(_bookingsBoxName);
    _queueStateBox = await Hive.openBox<Map>(_queueStateBoxName);
    _notificationsBox = await Hive.openBox<Map>(_notificationsBoxName);
    _feedbackBox = await Hive.openBox<Map>(_feedbackBoxName);
    await _seedMasterDataIfNeeded();
    if (_sessionBox.get(_sessionKeyNotificationsEnabled) == null) {
      await _sessionBox.put(_sessionKeyNotificationsEnabled, true);
    }
    if (_sessionBox.get(_sessionKeyThemeMode) == null) {
      await _sessionBox.put(_sessionKeyThemeMode, 'system');
    }
    _initialized = true;
  }

  /// Test-only reset helper: closes Hive and cancels simulation timer.
  static Future<void> resetForTests() async {
    stopQueueSimulation();
    if (!_initialized) return;
    await Hive.close();
    _initialized = false;
  }

  // ----------------------------
  // Offline Sync Packs (Phase 2, Hive-only)
  // ----------------------------

  /// Import Admin "Config Sync Pack" JSON into mobile Hive.
  /// Applies: branches + services (counters/staff users are ignored on mobile for now).
  static Future<LocalAuthResult> importConfigSyncPackJson(String json) async {
    if (!_initialized) return const LocalAuthResult.fail('Local database is not initialized');
    try {
      final pack = SyncPack.fromJsonString(json);
      if (pack.type != SyncPackType.config) {
        return const LocalAuthResult.fail('Invalid sync pack type (expected config)');
      }

      final data = pack.data;
      final incomingBranches = _asListOfMaps(data[SyncPackDataKeys.branches]);
      final incomingServices = _asListOfMaps(data[SyncPackDataKeys.services]);

      // Merge branches by branchId (newest updatedAt wins)
      final existingBranches =
          _branchesBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
      final mergedBranches = mergeByUpdatedAt(
        existing: existingBranches,
        incoming: incomingBranches,
        idKey: 'branchId',
      );
      for (final b in mergedBranches) {
        final id = (b['branchId'] ?? '').toString();
        if (id.isEmpty) continue;
        await _branchesBox.put(id, b);
      }

      // Merge services by serviceId
      final existingServices =
          _servicesBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
      final mergedServices = mergeByUpdatedAt(
        existing: existingServices,
        incoming: incomingServices,
        idKey: 'serviceId',
      );
      for (final s in mergedServices) {
        final id = (s['serviceId'] ?? '').toString();
        if (id.isEmpty) continue;
        await _servicesBox.put(id, s);
      }

      return const LocalAuthResult.ok();
    } catch (e) {
      return LocalAuthResult.fail('Import failed: ${e.toString()}');
    }
  }

  /// Export Mobile "Ops Sync Pack" JSON (today's bookings + notifications + all queue_state).
  static Future<String> exportOpsSyncPackJson({bool pretty = true}) async {
    if (!_initialized) throw StateError('Local database is not initialized');

    final now = DateTime.now();
    bool isToday(String iso) {
      try {
        final dt = DateTime.parse(iso).toLocal();
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } catch (_) {
        return false;
      }
    }

    final bookingsToday = _bookingsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((b) => isToday((b['createdAt'] ?? '').toString()))
        .toList();

    final notificationsToday = _notificationsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((n) => isToday((n['createdAt'] ?? '').toString()))
        .toList();

    final queueStateAll =
        _queueStateBox.values.map((e) => Map<String, dynamic>.from(e)).toList();

    final pack = SyncPack(
      version: SyncPack.currentVersion,
      type: SyncPackType.ops,
      generatedAt: DateTime.now().toIso8601String(),
      data: {
        SyncPackDataKeys.bookings: bookingsToday,
        SyncPackDataKeys.queueState: queueStateAll,
        SyncPackDataKeys.notifications: notificationsToday,
      },
    );

    return pack.toJsonString(pretty: pretty);
  }

  /// Import Web/Admin "Ops Sync Pack" JSON into mobile Hive.
  /// Phase 6 use-case: bring in broadcast notifications sent from staff web.
  static Future<LocalAuthResult> importOpsSyncPackJson(String json) async {
    if (!_initialized) return const LocalAuthResult.fail('Local database is not initialized');
    try {
      final pack = SyncPack.fromJsonString(json);
      if (pack.type != SyncPackType.ops) {
        return const LocalAuthResult.fail('Invalid sync pack type (expected ops)');
      }

      final data = pack.data;
      final incomingBookings = _asListOfMaps(data[SyncPackDataKeys.bookings]);
      final incomingQueue = _asListOfMaps(data[SyncPackDataKeys.queueState]);
      final incomingNotifs = _asListOfMaps(data[SyncPackDataKeys.notifications]);

      // Notifications: newest wins per notificationId
      final existingNotifs =
          _notificationsBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
      final mergedNotifs = mergeByUpdatedAt(
        existing: existingNotifs,
        incoming: incomingNotifs,
        idKey: NotificationFields.notificationId,
      );
      for (final n in mergedNotifs) {
        final id = (n[NotificationFields.notificationId] ?? '').toString();
        if (id.isEmpty) continue;
        await _notificationsBox.put(id, n);
      }

      // Bookings + queue_state import are optional; keep safe + newest-wins.
      if (incomingBookings.isNotEmpty) {
        final existingBookings =
            _bookingsBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
        final mergedBookings = mergeByUpdatedAt(
          existing: existingBookings,
          incoming: incomingBookings,
          idKey: BookingFields.bookingId,
        );
        for (final b in mergedBookings) {
          final id = (b[BookingFields.bookingId] ?? '').toString();
          if (id.isEmpty) continue;
          await _bookingsBox.put(id, b);
        }
      }

      if (incomingQueue.isNotEmpty) {
        String queueKeyOf(Map<String, dynamic> m) {
          final qk = (m['queueKey'] ?? '').toString();
          if (qk.isNotEmpty) return qk;
          final b = (m[BookingFields.branchId] ?? m['branchId'] ?? '').toString();
          final s = (m[BookingFields.serviceId] ?? m['serviceId'] ?? '').toString();
          final k = '$b:$s';
          return k == ':' ? '' : k;
        }

        final existingQueue =
            _queueStateBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
        final normalizedExisting = existingQueue.map((e) {
          e['queueKey'] = queueKeyOf(e);
          return e;
        }).toList();
        final normalizedIncoming = incomingQueue.map((e) {
          e['queueKey'] = queueKeyOf(e);
          return e;
        }).toList();

        final mergedQueue = mergeByUpdatedAt(
          existing: normalizedExisting,
          incoming: normalizedIncoming,
          idKey: 'queueKey',
        );
        for (final q in mergedQueue) {
          final queueKey = (q['queueKey'] ?? '').toString();
          if (queueKey.isEmpty) continue;
          await _queueStateBox.put(queueKey, q);
        }
      }

      return const LocalAuthResult.ok();
    } catch (e) {
      return LocalAuthResult.fail('Import failed: ${e.toString()}');
    }
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static ValueListenable<Box> sessionListenable() => _sessionBox.listenable();
  static ValueListenable<Box> usersListenable() => _usersBox.listenable();
  static ValueListenable<Box> bookingsListenable() => _bookingsBox.listenable();
  static ValueListenable<Box> queueStateListenable() => _queueStateBox.listenable();
  static ValueListenable<Box> notificationsListenable() => _notificationsBox.listenable();
  static ValueListenable<Box> feedbackListenable() => _feedbackBox.listenable();

  static String? currentUserPhone() {
    final value = _sessionBox.get(_sessionKeyCurrentPhone);
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static Map? currentUser() {
    final phone = currentUserPhone();
    if (phone == null) return null;
    return _usersBox.get(phone);
  }

  static Future<LocalAuthResult> updateCurrentUserProfile({
    required String name,
    required String email,
  }) async {
    final phone = currentUserPhone();
    if (phone == null) return const LocalAuthResult.fail('Please login first');
    final existing = _usersBox.get(phone);
    if (existing == null) return const LocalAuthResult.fail('User not found');

    final updated = Map<String, dynamic>.from(existing);
    updated['name'] = name.trim();
    updated['email'] = email.trim();
    updated['updatedAt'] = DateTime.now().toIso8601String();
    await _usersBox.put(phone, updated);
    return const LocalAuthResult.ok();
  }

  // ----------------------------
  // Help & support feedback (Phase 9)
  // ----------------------------

  static Future<LocalAuthResult> submitFeedback({
    required String category,
    required String message,
    int? rating,
  }) async {
    final phone = currentUserPhone();
    if (phone == null) return const LocalAuthResult.fail('Please login first');

    final trimmed = message.trim();
    if (trimmed.isEmpty) return const LocalAuthResult.fail('Message is required');
    if (trimmed.length < 5) return const LocalAuthResult.fail('Message is too short');

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _feedbackBox.put(id, <String, dynamic>{
      'feedbackId': id,
      'userPhone': phone,
      'category': category,
      'message': trimmed,
      'rating': rating,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'new',
    });
    return const LocalAuthResult.ok();
  }

  static Future<List<Map<String, dynamic>>> listFeedbackForCurrentUser() async {
    final phone = currentUserPhone();
    if (phone == null) return [];
    final items = _feedbackBox.values
        .where((f) => f['userPhone'] == phone)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    items.sort((a, b) =>
        (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    return items;
  }

  static Future<LocalAuthResult> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      return const LocalAuthResult.fail('Phone number is required');
    }
    if (_usersBox.containsKey(normalizedPhone)) {
      return const LocalAuthResult.fail('An account already exists for this phone');
    }

    final salt = _generateSalt(normalizedPhone);
    final passwordHash = _hashPassword(password: password, salt: salt);

    await _usersBox.put(normalizedPhone, <String, dynamic>{
      'name': name.trim(),
      'phone': normalizedPhone,
      'email': email.trim(),
      'passwordSalt': salt,
      'passwordHash': passwordHash,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _sessionBox.put(_sessionKeyCurrentPhone, normalizedPhone);
    // Best-effort: register on backend (so Admin can reset password).
    await _tryRegisterCustomerToBackend(
      userPhone: normalizedPhone,
      name: name.trim(),
      email: email.trim(),
      password: password,
    );
    return const LocalAuthResult.ok();
  }

  static Future<LocalAuthResult> signIn({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = phone.trim();

    // If backend is configured, try backend auth first.
    // Important: do NOT fall back to local auth when backend is reachable but credentials are wrong,
    // otherwise old local passwords would still work after an admin reset.
    final backend = await _tryLoginCustomerFromBackend(
      userPhone: normalizedPhone,
      password: password,
    );
    if (backend == _BackendLoginResult.ok) {
      await _sessionBox.put(_sessionKeyCurrentPhone, normalizedPhone);
      return const LocalAuthResult.ok();
    }
    if (backend == _BackendLoginResult.invalidCredentials) {
      return const LocalAuthResult.fail('Incorrect password');
    }

    final user = _usersBox.get(normalizedPhone);
    if (user == null) {
      return const LocalAuthResult.fail('No account found for this phone');
    }

    final salt = user['passwordSalt'];
    final expectedHash = user['passwordHash'];
    if (salt is! String || expectedHash is! String) {
      return const LocalAuthResult.fail('Account data is corrupted');
    }

    final actualHash = _hashPassword(password: password, salt: salt);
    if (actualHash != expectedHash) {
      return const LocalAuthResult.fail('Incorrect password');
    }

    await _sessionBox.put(_sessionKeyCurrentPhone, normalizedPhone);
    // Best-effort: ensure this customer exists on backend so Admin can reset password.
    final name = (user['name'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString().trim();
    await _tryRegisterCustomerToBackend(
      userPhone: normalizedPhone,
      name: name,
      email: email,
      password: password,
    );
    return const LocalAuthResult.ok();
  }

  static Future<void> _tryRegisterCustomerToBackend({
    required String userPhone,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // If the runtime base URL wasn't set, this will likely fail (offline) and we ignore.
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/customer/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userPhone': userPhone,
              'name': name.isEmpty ? null : name,
              'email': email.isEmpty ? null : email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 2));

      // 200 = ok, 409 = already exists; both fine.
      if (res.statusCode == 200 || res.statusCode == 409) return;
    } catch (_) {
      // ignore (offline)
    }
  }

  static Future<_BackendLoginResult> _tryLoginCustomerFromBackend({
    required String userPhone,
    required String password,
  }) async {
    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return _BackendLoginResult.notConfigured;
    try {
      final res = await http
          .post(
            Uri.parse('$base/customer/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userPhone': userPhone, 'password': password}),
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) return _BackendLoginResult.ok;
      if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403 || res.statusCode == 404) {
        return _BackendLoginResult.invalidCredentials;
      }
      return _BackendLoginResult.offline;
    } catch (_) {
      return _BackendLoginResult.offline;
    }
  }

  static Future<void> signOut() async {
    await _sessionBox.delete(_sessionKeyCurrentPhone);
  }

  static String? apiBaseUrlPreference() {
    final value = _sessionBox.get(_sessionKeyApiBaseUrl);
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static Future<void> setApiBaseUrlPreference(String url) async {
    final normalized = url.trim();
    await _sessionBox.put(_sessionKeyApiBaseUrl, normalized);
    if (normalized.isNotEmpty) {
      ApiConfig.setRuntimeBaseUrl(normalized);
    }
  }

  static bool notificationsEnabled() {
    final value = _sessionBox.get(_sessionKeyNotificationsEnabled);
    if (value is bool) return value;
    return true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _sessionBox.put(_sessionKeyNotificationsEnabled, enabled);
  }

  static String themeModePreference() {
    final value = _sessionBox.get(_sessionKeyThemeMode);
    if (value is String && value.isNotEmpty) return value;
    return 'system';
  }

  static Future<void> setThemeModePreference(String mode) async {
    // mode: system/light/dark
    await _sessionBox.put(_sessionKeyThemeMode, mode);
  }

  static int? accentColorValue() {
    final value = _sessionBox.get(_sessionKeyAccentColor);
    if (value is int) return value;
    return null;
  }

  static Future<void> setAccentColorValue(int? argb) async {
    if (argb == null) {
      await _sessionBox.delete(_sessionKeyAccentColor);
      return;
    }
    await _sessionBox.put(_sessionKeyAccentColor, argb);
  }

  // ----------------------------
  // Master data (Phase 1)
  // ----------------------------

  static Future<List<Map>> listBranches() async {
    final values = _branchesBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
    values.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return values;
  }

  static Future<List<Map>> listServicesForBranch(String branchId) async {
    final values = _servicesBox.values
        .where((e) => e['branchId'] == branchId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    values.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return values;
  }

  static Future<void> _seedMasterDataIfNeeded() async {
    // Branches
    final branches = <Map<String, dynamic>>[
      {
        'branchId': 'hetauda',
        'name': 'Hetauda Branch',
        'area': 'Buddha Chowk',
        'distanceKm': 12,
        'isActive': true,
      },
      {
        'branchId': 'kathmandu',
        'name': 'Kathmandu Branch',
        'area': 'Budhanikantha',
        'distanceKm': 8,
        'isActive': true,
      },
      {
        'branchId': 'lalitpur',
        'name': 'Lalitpur Branch',
        'area': 'Ekantakuma',
        'distanceKm': 3,
        'isActive': true,
      },
    ];

    // Always upsert branch master data so label fixes propagate even after first install.
    for (final b in branches) {
      final id = b['branchId'] as String;
      final existing = _branchesBox.get(id);
      if (existing is Map) {
        final merged = <String, dynamic>{
          ...Map<String, dynamic>.from(existing),
          ...b,
        };
        await _branchesBox.put(id, merged);
      } else {
        await _branchesBox.put(id, b);
      }
    }

    // Services (per branch)
    List<Map<String, dynamic>> servicesFor(String branchId) => [
          {
            'serviceId': '${branchId}_customer_service',
            'branchId': branchId,
            'name': 'Customer Service',
            'defaultEtaMinutes': 15,
            'isActive': true,
            'isDisabledMessage': null,
          },
          {
            'serviceId': '${branchId}_technical_support',
            'branchId': branchId,
            'name': 'Technical Support',
            'defaultEtaMinutes': 20,
            'isActive': true,
            'isDisabledMessage': null,
          },
          {
            'serviceId': '${branchId}_sales_inquiry',
            'branchId': branchId,
            'name': 'Sales Inquiry',
            'defaultEtaMinutes': 12,
            'isActive': true,
            'isDisabledMessage': null,
          },
          {
            'serviceId': '${branchId}_billing',
            'branchId': branchId,
            'name': 'Billing',
            'defaultEtaMinutes': 7,
            'isActive': true,
            'isDisabledMessage': null,
          },
          {
            'serviceId': '${branchId}_account_opening',
            'branchId': branchId,
            'name': 'Account opening',
            'defaultEtaMinutes': 15,
            'isActive': true,
            'isDisabledMessage': null,
          },
        ];

    // Ensure the service set is exactly the current expected list.
    // This keeps the customer app aligned with the Admin Manage Services list.
    final expectedIds = <String>{};
    for (final b in branches) {
      final branchId = b['branchId'] as String;
      for (final s in servicesFor(branchId)) {
        expectedIds.add((s['serviceId'] ?? '').toString());
        await _servicesBox.put(s['serviceId'] as String, s);
      }
    }
    // Remove old demo services like Track Queue or deprecated ids.
    for (final key in _servicesBox.keys.toList()) {
      final id = key.toString();
      if (!expectedIds.contains(id)) {
        await _servicesBox.delete(key);
      }
    }
  }

  // ----------------------------
  // Booking + notifications (Phase 2)
  // ----------------------------

  static Future<Map<String, dynamic>?> getActiveBookingForCurrentUser() async {
    final phone = currentUserPhone();
    if (phone == null) return null;
    final bookings = _bookingsBox.values
        .where((b) => b['userPhone'] == phone && _activeBookingStatuses.contains((b['status'] ?? '').toString()))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (bookings.isEmpty) return null;
    bookings.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    return bookings.first;
  }

  static Map<String, dynamic>? getActiveBookingForCurrentUserSync() {
    final phone = currentUserPhone();
    if (phone == null) return null;
    final bookings = _bookingsBox.values
        .where((b) => b['userPhone'] == phone && _activeBookingStatuses.contains((b['status'] ?? '').toString()))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (bookings.isEmpty) return null;
    bookings.sort((a, b) =>
        (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    return bookings.first;
  }

  static Map<String, dynamic> getQueueStateSync({
    required String branchId,
    required String serviceId,
  }) {
    final queueKey = '$branchId:$serviceId';
    return Map<String, dynamic>.from(
      _queueStateBox.get(queueKey) ?? <String, dynamic>{},
    );
  }

  static Future<LocalAuthResult> createBookingForCurrentUser({
    required String branchId,
    required String serviceId,
    String tokenType = 'Normal', // Normal/VIP/SeniorCitizen
    int counters = 3,
  }) async {
    final phone = currentUserPhone();
    if (phone == null) return const LocalAuthResult.fail('Please login first');

    final existing = await getActiveBookingForCurrentUser();
    if (existing != null) {
      return const LocalAuthResult.fail('You already have an active token');
    }

    final branch = _branchesBox.get(branchId);
    final service = _servicesBox.get(serviceId);
    if (branch == null || service == null) {
      return const LocalAuthResult.fail('Invalid branch/service selection');
    }

    final isActive = service['isActive'] == true;
    if (!isActive) {
      return const LocalAuthResult.fail('Selected service is unavailable');
    }

    final queueKey = '$branchId:$serviceId';
    final queue = Map<String, dynamic>.from(_queueStateBox.get(queueKey) ?? <String, dynamic>{});
    final lastCounter = (queue['lastTokenCounter'] as int?) ?? 0;
    final waitingQueueForCalc = _normalizeWaitingQueue(queue['waitingTokens']);
    final nowServing = (queue['nowServing'] is List) ? (queue['nowServing'] as List) : <dynamic>[];
    final avgWaitMinutes = (queue['avgWaitMinutes'] as int?) ??
        (service['defaultEtaMinutes'] as int?) ??
        15;
    final rawCounters = (queue['counters'] as int?) ?? counters;
    final countersCount = rawCounters > _defaultCounters ? _defaultCounters : rawCounters;

    final nextCounter = lastCounter + 1;
    final tokenNumber = 'A${nextCounter.toString().padLeft(3, '0')}';

    final normalizedType = _normalizeTokenType(tokenType);
    final priorityRank = _priorityRank(normalizedType);

    final nowServingCount = nowServing.length;
    final position = nowServingCount + waitingQueueForCalc.length + 1;
    final peopleAhead = position - 1;

    final etaMinutes = _estimateEtaMinutes(
      peopleAhead: peopleAhead,
      avgMinutesPerCustomer: avgWaitMinutes,
      counters: countersCount,
    );

    final bookingId = DateTime.now().microsecondsSinceEpoch.toString();
    final createdAt = DateTime.now().toIso8601String();

    final booking = <String, dynamic>{
      'bookingId': bookingId,
      'userPhone': phone,
      'branchId': branchId,
      'branchName': (branch['name'] ?? '').toString(),
      'serviceId': serviceId,
      'serviceName': (service['name'] ?? '').toString(),
      'tokenNumber': tokenNumber,
      'tokenType': normalizedType,
      'createdAt': createdAt,
      'status': 'active',
      'estimatedWaitMinutes': etaMinutes,
      'position': position,
      'queueSize': nowServingCount + waitingQueueForCalc.length + 1,
      'peopleAhead': peopleAhead,
    };

    await _bookingsBox.put(bookingId, booking);

    // Update queue_state
    queue['lastTokenCounter'] = nextCounter;
    final waitingQueue = _normalizeWaitingQueue(queue['waitingTokens']);
    _insertIntoWaitingQueue(
      waitingQueue,
      tokenNumber: tokenNumber,
      tokenType: normalizedType,
      priorityRank: priorityRank,
      createdAt: createdAt,
    );
    queue['waitingTokens'] = waitingQueue;
    queue['waitingCount'] = waitingQueue.length;
    queue['avgWaitMinutes'] = avgWaitMinutes;
    queue['updatedAt'] = createdAt;
    queue['nowServing'] = nowServing;
    queue['counters'] = countersCount <= 0 ? _defaultCounters : countersCount;
    await _queueStateBox.put(queueKey, queue);

    // Create local notification
    await _createNotification(
      userPhone: phone,
      title: 'Booking Confirmed',
      subtitle: '${booking['branchName']} • ${booking['serviceName']}',
      type: 'booking_confirmed',
      relatedBookingId: bookingId,
    );

    // Best-effort: also create the booking on backend so Staff/Admin portal can see it.
    unawaited(_syncBookingToBackend(
      userPhone: phone,
      branchId: branchId,
      serviceId: serviceId,
      tokenType: normalizedType,
      localBookingId: bookingId,
    ));

    return const LocalAuthResult.ok();
  }

  static Future<void> _trySyncActiveBookingToBackend() async {
    try {
      final booking = getActiveBookingForCurrentUserSync();
      if (booking == null) return;
      final synced = booking['backendSynced'] == true;
      if (synced) return;
      final phone = currentUserPhone();
      if (phone == null || phone.isEmpty) return;

      await _syncBookingToBackend(
        userPhone: phone,
        branchId: (booking['branchId'] ?? '').toString(),
        serviceId: (booking['serviceId'] ?? '').toString(),
        tokenType: (booking['tokenType'] ?? 'Normal').toString(),
        localBookingId: (booking['bookingId'] ?? '').toString(),
      );
    } catch (_) {
      // ignore (offline-first)
    }
  }

  static Future<void> _syncBookingToBackend({
    required String userPhone,
    required String branchId,
    required String serviceId,
    required String tokenType,
    required String localBookingId,
  }) async {
    if (userPhone.isEmpty || branchId.isEmpty || serviceId.isEmpty) return;

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/customer/bookings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userPhone': userPhone,
              'branchId': branchId,
              'serviceId': serviceId,
              'tokenType': tokenType,
            }),
          )
          .timeout(const Duration(seconds: 2));

      // 200: created
      // 409: backend says "already has an active token" — do NOT overwrite local booking mapping.
      if (res.statusCode == 409) return;

      if (res.statusCode == 200) {
        final raw = _bookingsBox.get(localBookingId);
        if (raw != null) {
          final updated = Map<String, dynamic>.from(raw);
          updated['backendSynced'] = true;
          try {
            final decoded = jsonDecode(res.body);
            if (decoded is Map) {
              if (decoded['bookingId'] != null) {
                updated['backendBookingId'] = decoded['bookingId'].toString();
              }
              if (decoded['tokenNumber'] != null) {
                updated['tokenNumber'] = decoded['tokenNumber'].toString();
              }
              if (decoded['status'] != null) {
                // Keep local status if already completed/cancelled; otherwise follow backend.
                final s = decoded['status'].toString();
                final localStatus = (updated['status'] ?? '').toString();
                if (localStatus == 'active' || localStatus == 'waiting' || localStatus == 'serving') {
                  updated['status'] = s;
                }
              }
            }
          } catch (_) {}
          await _bookingsBox.put(localBookingId, updated);
        }
      }
    } catch (_) {
      // offline / backend not reachable: ignore
    }
  }

  static Future<void> refreshActiveBookingFromBackend() async {
    final phone = currentUserPhone();
    if (phone == null || phone.isEmpty) return;
    final booking = getActiveBookingForCurrentUserSync();
    if (booking == null) return;

    final localId = (booking['bookingId'] ?? '').toString();
    if (localId.isEmpty) return;
    final backendId = (booking['backendBookingId'] ?? '').toString();
    final backendSynced = booking['backendSynced'] == true;

    // If we don't have a reliable backend link, do not guess.
    // This prevents wrongly marking a new token as completed.
    if (!backendSynced && backendId.isEmpty) return;

    try {
      if (backendId.isNotEmpty) {
        final res = await http
            .get(Uri.parse('${ApiConfig.baseUrl}/customer/bookings/$backendId'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode != 200) return;
        final decoded = jsonDecode(res.body);
        if (decoded is! Map) return;
        final status = (decoded['status'] ?? '').toString();
        if (status.isEmpty) return;

        final updated = Map<String, dynamic>.from(booking);
        updated['status'] = status;
        if (status == 'completed') updated['completedAt'] = decoded['completedAt'];
        if (status == 'cancelled') updated['cancelledAt'] = decoded['cancelledAt'];
        if (decoded['tokenNumber'] != null) updated['tokenNumber'] = decoded['tokenNumber'].toString();
        await _bookingsBox.put(localId, updated);
        return;
      }
    } catch (_) {
      // ignore
    }
  }

  static Future<int> syncNotificationsFromBackend() async {
    final phone = currentUserPhone();
    if (phone == null || phone.isEmpty) return 0;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/customer/notifications')
          .replace(queryParameters: {'userPhone': phone});
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) return 0;
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return 0;

      final incomingIds = <String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final id = (item['notificationId'] ?? '').toString();
        if (id.isNotEmpty) incomingIds.add(id);
      }

      // Prune old staff broadcasts that no longer exist on server.
      for (final entry in _notificationsBox.toMap().entries) {
        final id = entry.key.toString();
        final raw = Map<String, dynamic>.from(entry.value);
        final userPhone = raw['userPhone'];
        final type = (raw['type'] ?? '').toString();
        final isBroadcast = (userPhone == null) || (userPhone.toString().trim().isEmpty);
        if (isBroadcast && type == 'staff_broadcast' && !incomingIds.contains(id)) {
          await _notificationsBox.delete(id);
        }
      }

      var upserted = 0;
      for (final item in decoded) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final id = (m['notificationId'] ?? '').toString();
        if (id.isEmpty) continue;
        // Normalize isRead to bool
        final isRead = m['isRead'] == true;
        m['isRead'] = isRead;
        await _notificationsBox.put(id, m);
        upserted++;
      }
      return upserted;
    } catch (_) {
      // ignore (offline)
      return 0;
    }
  }

  static String _normalizeTokenType(String tokenType) {
    final t = tokenType.trim();
    if (t.toLowerCase() == 'vip') return 'VIP';
    if (t.toLowerCase().contains('senior')) return 'SeniorCitizen';
    return 'Normal';
  }

  static int _priorityRank(String tokenType) {
    // Lower rank = higher priority.
    return switch (tokenType) {
      'SeniorCitizen' => 0,
      'VIP' => 1,
      _ => 2,
    };
  }

  static List<Map<String, dynamic>> _normalizeWaitingQueue(dynamic raw) {
    if (raw is List) {
      if (raw.isEmpty) return <Map<String, dynamic>>[];
      // Old format: List<String>
      if (raw.first is String) {
        return raw
            .map((e) => <String, dynamic>{
                  'tokenNumber': e.toString(),
                  'tokenType': 'Normal',
                  'priorityRank': 2,
                  'createdAt': DateTime.now().toIso8601String(),
                })
            .toList();
      }
      // New format: List<Map>
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  static void _insertIntoWaitingQueue(
    List<Map<String, dynamic>> queue, {
    required String tokenNumber,
    required String tokenType,
    required int priorityRank,
    required String createdAt,
  }) {
    final item = <String, dynamic>{
      'tokenNumber': tokenNumber,
      'tokenType': tokenType,
      'priorityRank': priorityRank,
      'createdAt': createdAt,
    };

    var insertAt = queue.length;
    for (var i = 0; i < queue.length; i++) {
      final r = queue[i]['priorityRank'];
      final rank = r is int ? r : 2;
      if (priorityRank < rank) {
        insertAt = i;
        break;
      }
    }
    queue.insert(insertAt, item);
  }

  static int _estimateEtaMinutes({
    required int peopleAhead,
    required int avgMinutesPerCustomer,
    required int counters,
  }) {
    final c = counters <= 0 ? 1 : counters;
    final p = peopleAhead < 0 ? 0 : peopleAhead;
    final base = ((p * avgMinutesPerCustomer) / c).ceil();
    return base < 1 ? 1 : base;
  }

  static Future<void> _createNotification({
    required String userPhone,
    required String title,
    required String subtitle,
    required String type,
    String? relatedBookingId,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _notificationsBox.put(id, <String, dynamic>{
      'notificationId': id,
      'userPhone': userPhone,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'relatedBookingId': relatedBookingId,
    });
  }

  static bool _notificationExists({
    required String userPhone,
    required String type,
    required String relatedBookingId,
    Duration within = const Duration(hours: 24),
  }) {
    final now = DateTime.now();
    for (final n in _notificationsBox.values) {
      if (n['userPhone'] != userPhone) continue;
      if (n['type'] != type) continue;
      if (n['relatedBookingId'] != relatedBookingId) continue;
      final createdAt = n['createdAt'];
      if (createdAt is String) {
        try {
          final dt = DateTime.parse(createdAt).toLocal();
          if (now.difference(dt) <= within) return true;
        } catch (_) {
          return true;
        }
      } else {
        return true;
      }
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> listNotificationsForCurrentUser() async {
    final phone = currentUserPhone();
    if (phone == null) return [];
    final items = _notificationsBox.values
        .where((n) =>
            // personal
            (n['userPhone'] == phone) ||
            // broadcast (null or empty)
            (n['userPhone'] == null) ||
            ((n['userPhone'] ?? '').toString().trim().isEmpty))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    items.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    return items;
  }

  static Future<void> markNotificationRead(String notificationId) async {
    final existing = _notificationsBox.get(notificationId);
    if (existing == null) return;
    final copy = Map<String, dynamic>.from(existing);
    copy['isRead'] = true;
    await _notificationsBox.put(notificationId, copy);
  }

  // ----------------------------
  // Queue simulation (Phase 4)
  // ----------------------------

  static void startQueueSimulation({
    Duration tick = const Duration(seconds: 5),
  }) {
    if (_queueTimer != null) return;
    _queueTimer = Timer.periodic(tick, (_) {
      // Best-effort: timer must never crash the app.
      _tickQueues();
    });
  }

  static void stopQueueSimulation() {
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  static Future<void> _tickQueues() async {
    if (!_initialized) return;
    // Iterate all queue_state entries and move tokens into "Now Serving".
    try {
      for (final key in _queueStateBox.keys) {
        final raw = _queueStateBox.get(key);
        if (raw == null) continue;
        final queue = Map<String, dynamic>.from(raw);

        // Force all queues to max 3 counters (global setting).
        final rawCounters = (queue['counters'] as int?) ?? _defaultCounters;
        final counters = rawCounters > _defaultCounters ? _defaultCounters : rawCounters;
        final waitingQueue = _normalizeWaitingQueue(queue['waitingTokens']);
        final nowServing = (queue['nowServing'] is List)
            ? List<Map<String, dynamic>>.from(
                (queue['nowServing'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : <Map<String, dynamic>>[];

        // If old data had more counters, move extra "now serving" entries back to waiting.
        // Keep Counter 1..counters active; anything above goes back to the front of the queue.
        final overflow = <Map<String, dynamic>>[];
        nowServing.removeWhere((e) {
          final name = (e['counterName'] ?? '').toString();
          final idxStr = name.replaceAll(RegExp(r'[^0-9]'), '');
          final idx = int.tryParse(idxStr) ?? 0;
          final isOverflow = idx > counters && (e['tokenNumber'] ?? '').toString().isNotEmpty;
          if (isOverflow) overflow.add(e);
          return isOverflow;
        });
        if (overflow.isNotEmpty) {
          // Put overflow tokens back at the front in original order.
          for (final e in overflow.reversed) {
            waitingQueue.insert(0, <String, dynamic>{
              'tokenNumber': (e['tokenNumber'] ?? '').toString(),
              'tokenType': 'Normal',
              'priorityRank': 2,
              'createdAt': DateTime.now().toIso8601String(),
            });
          }
        }

        // Fill counters from waiting queue.
        final now = DateTime.now().toIso8601String();
        final existingCounters =
            nowServing.map((e) => (e['counterName'] ?? '').toString()).toSet();
        for (var i = 1; i <= counters; i++) {
          if (waitingQueue.isEmpty) break;
          final counterName = 'Counter $i';
          if (existingCounters.contains(counterName)) continue;
          final token = (waitingQueue.removeAt(0)['tokenNumber'] ?? '').toString();
          nowServing.add({
            'tokenNumber': token,
            'counterName': counterName,
            'startedAt': now,
          });
          existingCounters.add(counterName);
        }

        queue['waitingTokens'] = waitingQueue;
        queue['waitingCount'] = waitingQueue.length;
        queue['nowServing'] = nowServing;
        queue['updatedAt'] = now;
        queue['counters'] = counters <= 0 ? _defaultCounters : counters;
        await _queueStateBox.put(key, queue);

        // Update any active bookings that belong to this queue.
        final parts = key.toString().split(':');
        if (parts.length != 2) continue;
        final branchId = parts[0];
        final serviceId = parts[1];
        await _recalculateBookingsForQueue(
          branchId: branchId,
          serviceId: serviceId,
          counters: counters,
          waitingQueue: waitingQueue,
          nowServing: nowServing,
        );
      }
    } catch (_) {
      // Swallow errors to keep offline timer robust.
    }
  }

  static Future<void> _recalculateBookingsForQueue({
    required String branchId,
    required String serviceId,
    required int counters,
    required List<Map<String, dynamic>> waitingQueue,
    required List<Map<String, dynamic>> nowServing,
  }) async {
    final avgWaitMinutes = (() {
      final service = _servicesBox.get(serviceId);
      return (service?['defaultEtaMinutes'] as int?) ?? 15;
    })();

    final queueSize = nowServing.length + waitingQueue.length;

    for (final entry in _bookingsBox.toMap().entries) {
      final bookingId = entry.key.toString();
      final raw = entry.value;
      if (raw['status'] != 'active') continue;
      if (raw['branchId'] != branchId) continue;
      if (raw['serviceId'] != serviceId) continue;

      final token = (raw['tokenNumber'] ?? '').toString();
      final updated = Map<String, dynamic>.from(raw);
      final userPhone = (updated['userPhone'] ?? '').toString();

      final isServing = nowServing.any((e) => e['tokenNumber'] == token);
      if (isServing) {
        updated['position'] = 1;
        updated['peopleAhead'] = 0;
        updated['queueSize'] = queueSize <= 0 ? 1 : queueSize;
        updated['estimatedWaitMinutes'] = 0;

        if (notificationsEnabled() &&
            userPhone.isNotEmpty &&
            !_notificationExists(
              userPhone: userPhone,
              type: 'now_serving',
              relatedBookingId: bookingId,
              within: const Duration(hours: 12),
            )) {
          await _createNotification(
            userPhone: userPhone,
            title: 'Now Serving',
            subtitle: '${updated['branchName'] ?? ''} • ${updated['serviceName'] ?? ''}',
            type: 'now_serving',
            relatedBookingId: bookingId,
          );
        }
      } else {
        final idx = waitingQueue.indexWhere((e) => e['tokenNumber'] == token);
        if (idx >= 0) {
          final position = nowServing.length + idx + 1;
          final peopleAhead = position - 1;
          updated['position'] = position;
          updated['peopleAhead'] = peopleAhead;
          updated['queueSize'] = queueSize <= 0 ? 1 : queueSize;
          updated['estimatedWaitMinutes'] = _estimateEtaMinutes(
            peopleAhead: peopleAhead,
            avgMinutesPerCustomer: avgWaitMinutes,
            counters: counters,
          );

          if (notificationsEnabled() &&
              userPhone.isNotEmpty &&
              peopleAhead <= 2 &&
              !_notificationExists(
                userPhone: userPhone,
                type: 'turn_soon',
                relatedBookingId: bookingId,
                within: const Duration(hours: 12),
              )) {
            await _createNotification(
              userPhone: userPhone,
              title: 'Your turn is coming soon',
              subtitle: '$peopleAhead people ahead of you',
              type: 'turn_soon',
              relatedBookingId: bookingId,
            );
          }
        } else {
          // Token missing from queue_state lists; keep previous values.
          updated['queueSize'] = queueSize <= 0 ? (updated['queueSize'] ?? 1) : queueSize;
        }
      }

      await _bookingsBox.put(bookingId, updated);
    }
  }

  static Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    final raw = _bookingsBox.get(bookingId);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  static Map<String, dynamic>? getBookingByIdSync(String bookingId) {
    final raw = _bookingsBox.get(bookingId);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  static Future<List<Map<String, dynamic>>> listBookingsForCurrentUser({
    String? status,
  }) async {
    final phone = currentUserPhone();
    if (phone == null) return [];
    final items = _bookingsBox.values
        .where((b) => b['userPhone'] == phone)
        .where((b) => status == null ? true : b['status'] == status)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    items.sort((a, b) =>
        (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    return items;
  }

  static Future<LocalAuthResult> cancelActiveBooking(String bookingId) async {
    final phone = currentUserPhone();
    if (phone == null) return const LocalAuthResult.fail('Please login first');

    final existing = _bookingsBox.get(bookingId);
    if (existing == null) return const LocalAuthResult.fail('Token not found');
    if (existing['userPhone'] != phone) {
      return const LocalAuthResult.fail('Not allowed');
    }
    if (existing['status'] != 'active') {
      return const LocalAuthResult.fail('Token is not active');
    }

    final updated = Map<String, dynamic>.from(existing);
    updated['status'] = 'cancelled';
    updated['cancelledAt'] = DateTime.now().toIso8601String();
    await _bookingsBox.put(bookingId, updated);

    // Best-effort queue_state adjustment (offline simulation).
    final branchId = (updated['branchId'] ?? '').toString();
    final serviceId = (updated['serviceId'] ?? '').toString();
    if (branchId.isNotEmpty && serviceId.isNotEmpty) {
      final queueKey = '$branchId:$serviceId';
      final queue = Map<String, dynamic>.from(_queueStateBox.get(queueKey) ?? <String, dynamic>{});
      final token = (updated['tokenNumber'] ?? '').toString();
      final waitingQueue = _normalizeWaitingQueue(queue['waitingTokens']);
      final nowServing = (queue['nowServing'] is List)
          ? List<Map<String, dynamic>>.from(
              (queue['nowServing'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
            )
          : <Map<String, dynamic>>[];

      waitingQueue.removeWhere((e) => e['tokenNumber'] == token);
      nowServing.removeWhere((e) => e['tokenNumber'] == token);

      queue['waitingTokens'] = waitingQueue;
      queue['waitingCount'] = waitingQueue.length;
      queue['nowServing'] = nowServing;
      queue['updatedAt'] = DateTime.now().toIso8601String();
      await _queueStateBox.put(queueKey, queue);
    }

    await _createNotification(
      userPhone: phone,
      title: 'Token Cancelled',
      subtitle: '${updated['branchName'] ?? ''} • ${updated['serviceName'] ?? ''}',
      type: 'token_cancelled',
      relatedBookingId: bookingId,
    );

    return const LocalAuthResult.ok();
  }

  static String _hashPassword({
    required String password,
    required String salt,
  }) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  static String _generateSalt(String phone) {
    // Deterministic per user (simple + acceptable for offline demo).
    // If you want stronger: use random bytes and store them.
    final bytes = utf8.encode('intelliqueue::$phone::salt');
    return sha256.convert(bytes).toString();
  }
}

