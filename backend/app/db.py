import os
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(frozen=True)
class DbConfig:
    db_path: Path


def get_db_config() -> DbConfig:
    # Store DB inside the repo for thesis/demo simplicity.
    # For tests, allow override:
    #   INTELLIQUEUE_DB_PATH=/tmp/intelliqueue-test.db
    override = os.environ.get("INTELLIQUEUE_DB_PATH", "").strip()
    if override:
        return DbConfig(db_path=Path(override).expanduser().resolve())

    base_dir = Path(__file__).resolve().parents[1]  # backend/
    data_dir = base_dir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    return DbConfig(db_path=data_dir / "intelliqueue.db")


def _connect(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


_CONN: Optional[sqlite3.Connection] = None


def get_conn() -> sqlite3.Connection:
    global _CONN
    if _CONN is None:
        cfg = get_db_config()
        _CONN = _connect(cfg.db_path)
    return _CONN


@contextmanager
def tx():
    conn = get_conn()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise


def init_db() -> None:
    """
    Create all required tables if they don't exist.
    """
    with tx() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS app_meta (
              key TEXT PRIMARY KEY,
              value TEXT
            );

            CREATE TABLE IF NOT EXISTS branches (
              branchId TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              address TEXT,
              isActive INTEGER NOT NULL DEFAULT 1,
              createdAt TEXT NOT NULL,
              updatedAt TEXT
            );

            CREATE TABLE IF NOT EXISTS services (
              serviceId TEXT PRIMARY KEY,
              branchId TEXT NOT NULL,
              name TEXT NOT NULL,
              category TEXT,
              defaultEtaMinutes INTEGER NOT NULL DEFAULT 15,
              isActive INTEGER NOT NULL DEFAULT 1,
              createdAt TEXT NOT NULL,
              updatedAt TEXT,
              FOREIGN KEY(branchId) REFERENCES branches(branchId) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS counters (
              counterId TEXT PRIMARY KEY,
              counterName TEXT NOT NULL,
              branchId TEXT NOT NULL,
              serviceId TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              assignedStaffEmail TEXT,
              updatedAt TEXT,
              FOREIGN KEY(branchId) REFERENCES branches(branchId) ON DELETE CASCADE,
              FOREIGN KEY(serviceId) REFERENCES services(serviceId) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS staff_users (
              staffId TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE,
              role TEXT NOT NULL,
              assignedCounterId TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              passwordSalt TEXT NOT NULL,
              passwordHash TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              updatedAt TEXT,
              FOREIGN KEY(assignedCounterId) REFERENCES counters(counterId) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS customer_users (
              userPhone TEXT PRIMARY KEY,
              name TEXT,
              email TEXT,
              passwordSalt TEXT NOT NULL,
              passwordHash TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              createdAt TEXT NOT NULL,
              updatedAt TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_customer_users_email ON customer_users(email);

            CREATE TABLE IF NOT EXISTS bookings (
              bookingId TEXT PRIMARY KEY,
              userPhone TEXT NOT NULL,
              branchId TEXT NOT NULL,
              branchName TEXT,
              serviceId TEXT NOT NULL,
              serviceName TEXT,
              tokenNumber TEXT NOT NULL,
              tokenType TEXT NOT NULL,
              status TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              updatedAt TEXT,
              cancelledAt TEXT,
              skippedAt TEXT,
              completedAt TEXT,
              estimatedWaitMinutes INTEGER,
              position INTEGER,
              queueSize INTEGER,
              peopleAhead INTEGER,
              servingCounterId TEXT,
              FOREIGN KEY(branchId) REFERENCES branches(branchId),
              FOREIGN KEY(serviceId) REFERENCES services(serviceId),
              FOREIGN KEY(servingCounterId) REFERENCES counters(counterId)
            );

            CREATE INDEX IF NOT EXISTS idx_bookings_userPhone_createdAt ON bookings(userPhone, createdAt);
            CREATE INDEX IF NOT EXISTS idx_bookings_queue_status_createdAt ON bookings(branchId, serviceId, status, createdAt);
            CREATE INDEX IF NOT EXISTS idx_bookings_servingCounterId ON bookings(servingCounterId);

            CREATE TABLE IF NOT EXISTS notifications (
              notificationId TEXT PRIMARY KEY,
              userPhone TEXT,
              title TEXT NOT NULL,
              subtitle TEXT,
              type TEXT NOT NULL,
              relatedBookingId TEXT,
              isRead INTEGER NOT NULL DEFAULT 0,
              createdAt TEXT NOT NULL,
              FOREIGN KEY(relatedBookingId) REFERENCES bookings(bookingId) ON DELETE SET NULL
            );

            CREATE INDEX IF NOT EXISTS idx_notifications_userPhone_createdAt ON notifications(userPhone, createdAt);

            CREATE TABLE IF NOT EXISTS feedback (
              feedbackId TEXT PRIMARY KEY,
              userPhone TEXT NOT NULL,
              bookingId TEXT,
              message TEXT NOT NULL,
              rating INTEGER,
              createdAt TEXT NOT NULL,
              FOREIGN KEY(bookingId) REFERENCES bookings(bookingId) ON DELETE SET NULL
            );
            """
        )

