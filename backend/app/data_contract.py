"""
IntelliQueue Shared Data Contract (Backend)

This mirrors `lib/shared/data_contract.dart`.
Field names are intentionally stable for thesis consistency.
"""


class BookingStatus:
    WAITING = "waiting"
    SERVING = "serving"
    ACTIVE = "active"
    CANCELLED = "cancelled"
    SKIPPED = "skipped"
    COMPLETED = "completed"


class TokenType:
    NORMAL = "Normal"
    VIP = "VIP"
    SENIOR_CITIZEN = "SeniorCitizen"


class CounterStatus:
    ACTIVE = "active"
    BREAK = "break"
    INACTIVE = "inactive"


class StaffRole:
    COUNTER_OFFICER = "counter_officer"
    SUPERVISOR = "supervisor"
    ADMIN = "admin"


class BookingFields:
    BOOKING_ID = "bookingId"
    USER_PHONE = "userPhone"
    BRANCH_ID = "branchId"
    BRANCH_NAME = "branchName"
    SERVICE_ID = "serviceId"
    SERVICE_NAME = "serviceName"
    TOKEN_NUMBER = "tokenNumber"
    TOKEN_TYPE = "tokenType"
    STATUS = "status"
    CREATED_AT = "createdAt"
    UPDATED_AT = "updatedAt"
    CANCELLED_AT = "cancelledAt"
    SKIPPED_AT = "skippedAt"
    COMPLETED_AT = "completedAt"
    ESTIMATED_WAIT_MINUTES = "estimatedWaitMinutes"
    POSITION = "position"
    QUEUE_SIZE = "queueSize"
    PEOPLE_AHEAD = "peopleAhead"


class BranchFields:
    BRANCH_ID = "branchId"
    NAME = "name"
    ADDRESS = "address"
    IS_ACTIVE = "isActive"
    CREATED_AT = "createdAt"
    UPDATED_AT = "updatedAt"


class ServiceFields:
    SERVICE_ID = "serviceId"
    BRANCH_ID = "branchId"
    NAME = "name"
    CATEGORY = "category"
    DEFAULT_ETA_MINUTES = "defaultEtaMinutes"
    IS_ACTIVE = "isActive"
    CREATED_AT = "createdAt"
    UPDATED_AT = "updatedAt"


class CounterFields:
    COUNTER_ID = "counterId"
    COUNTER_NAME = "counterName"
    BRANCH_ID = "branchId"
    SERVICE_ID = "serviceId"
    STATUS = "status"
    ASSIGNED_STAFF_EMAIL = "assignedStaffEmail"
    UPDATED_AT = "updatedAt"


class NotificationFields:
    NOTIFICATION_ID = "notificationId"
    USER_PHONE = "userPhone"
    TITLE = "title"
    SUBTITLE = "subtitle"
    TYPE = "type"
    RELATED_BOOKING_ID = "relatedBookingId"
    IS_READ = "isRead"
    CREATED_AT = "createdAt"


class StaffUserFields:
    STAFF_ID = "staffId"
    NAME = "name"
    EMAIL = "email"
    ROLE = "role"
    ASSIGNED_COUNTER_ID = "assignedCounterId"
    STATUS = "status"
    PASSWORD_SALT = "passwordSalt"
    PASSWORD_HASH = "passwordHash"
    CREATED_AT = "createdAt"
    UPDATED_AT = "updatedAt"


class FeedbackFields:
    FEEDBACK_ID = "feedbackId"
    USER_PHONE = "userPhone"
    BOOKING_ID = "bookingId"
    MESSAGE = "message"
    RATING = "rating"
    CREATED_AT = "createdAt"

