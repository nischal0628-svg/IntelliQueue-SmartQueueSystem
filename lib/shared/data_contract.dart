/// IntelliQueue Shared Data Contract (Admin/Staff/Mobile + Local API)
///
/// This file defines the canonical entity field keys and allowed string values
/// used by:
/// - Local backend (FastAPI + SQLite)
/// - Admin web (Flutter Web)
/// - Staff web (Flutter Web)
/// - Customer mobile (Flutter iOS simulator)
///
/// Goal: all clients + backend speak the same "language" (IDs, fields, enums).
library;

/// Legacy/local-storage box names.
///
/// Note: Even though the thesis "sync" now uses Local API + SQLite,
/// the customer mobile portion of this repo still uses Hive for local state
/// (simulation, caching, preferences). These constants keep that code compiling.
class HiveBoxes {
  // Customer mobile boxes
  static const users = 'users';
  static const session = 'session';
  static const branches = 'branches';
  static const services = 'services';
  static const bookings = 'bookings';
  static const queueState = 'queue_state';
  static const notifications = 'notifications';
  static const feedback = 'feedback';

  // Web portal boxes (only if you still use Hive in web later)
  static const staffUsers = 'staff_users';
  static const counters = 'counters';
  static const staffSession = 'staff_session';
  static const adminSession = 'admin_session';
}

class BookingStatus {
  /// Waiting in a queue (not yet being served).
  static const waiting = 'waiting';

  /// Currently being served at a counter.
  static const serving = 'serving';

  /// Active booking (generic). Current mobile simulation uses `active`.
  static const active = 'active';

  static const cancelled = 'cancelled';
  static const skipped = 'skipped';
  static const completed = 'completed';
}

class TokenType {
  static const normal = 'Normal';
  static const vip = 'VIP';
  static const seniorCitizen = 'SeniorCitizen';
}

class CounterStatus {
  static const active = 'active';
  static const breakStatus = 'break';
  static const inactive = 'inactive';
}

class StaffRole {
  static const counterOfficer = 'counter_officer';
  static const supervisor = 'supervisor';
  static const admin = 'admin';
}

class BookingFields {
  static const bookingId = 'bookingId';
  static const userPhone = 'userPhone';
  static const branchId = 'branchId';
  static const branchName = 'branchName';
  static const serviceId = 'serviceId';
  static const serviceName = 'serviceName';
  static const tokenNumber = 'tokenNumber';
  static const tokenType = 'tokenType';
  static const status = 'status';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const cancelledAt = 'cancelledAt';
  static const skippedAt = 'skippedAt';
  static const completedAt = 'completedAt';

  // Queue projection fields stored on booking for UI convenience
  static const estimatedWaitMinutes = 'estimatedWaitMinutes';
  static const position = 'position';
  static const queueSize = 'queueSize';
  static const peopleAhead = 'peopleAhead';
}

class BranchFields {
  static const branchId = 'branchId';
  static const name = 'name';
  static const address = 'address';
  static const isActive = 'isActive';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
}

class ServiceFields {
  static const serviceId = 'serviceId';
  static const branchId = 'branchId';
  static const name = 'name'; // e.g. "Customer Service"
  static const category = 'category'; // e.g. Support/Sales/Finance/Operations
  static const defaultEtaMinutes = 'defaultEtaMinutes';
  static const isActive = 'isActive';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
}

class CounterFields {
  static const counterId = 'counterId';
  static const counterName = 'counterName';
  static const branchId = 'branchId';
  static const serviceId = 'serviceId';
  static const status = 'status'; // active/break/inactive
  static const assignedStaffEmail = 'assignedStaffEmail';
  static const updatedAt = 'updatedAt';
}

class QueueStateFields {
  // Derived key (not necessarily stored): '$branchId:$serviceId'
  static const counters = 'counters';
  static const avgWaitMinutes = 'avgWaitMinutes';
  static const lastTokenCounter = 'lastTokenCounter';
  static const waitingTokens = 'waitingTokens'; // List<Map> (priority-aware)
  static const waitingCount = 'waitingCount';
  static const nowServing = 'nowServing'; // List<Map>
  static const updatedAt = 'updatedAt';
}

class NotificationFields {
  static const notificationId = 'notificationId';
  static const userPhone = 'userPhone';
  static const title = 'title';
  static const subtitle = 'subtitle';
  static const type = 'type';
  static const relatedBookingId = 'relatedBookingId';
  static const isRead = 'isRead';
  static const createdAt = 'createdAt';
}

class StaffUserFields {
  static const staffId = 'staffId';
  static const name = 'name';
  static const email = 'email';
  static const role = 'role'; // counter_officer | supervisor | admin
  static const assignedCounterId = 'assignedCounterId'; // nullable (optional)
  static const status = 'status'; // active/break/inactive
  static const passwordSalt = 'passwordSalt';
  static const passwordHash = 'passwordHash';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
}

class FeedbackFields {
  static const feedbackId = 'feedbackId';
  static const userPhone = 'userPhone';
  static const bookingId = 'bookingId';
  static const message = 'message';
  static const rating = 'rating'; // 1..5 (optional)
  static const createdAt = 'createdAt';
}

