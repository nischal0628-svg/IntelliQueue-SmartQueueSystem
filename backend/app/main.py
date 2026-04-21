from datetime import datetime
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

from backend.app.db import init_db, tx
from backend.app.models import (
    BookingCreateIn,
    CounterIn,
    LoginRequest,
    LoginResponse,
    CustomerSignupIn,
    CustomerLoginIn,
    CustomerOut,
    AdminResetCustomerPasswordIn,
    NotificationIn,
    ServiceIn,
    StaffActionIn,
    StaffCallNowIn,
    StaffCancelIn,
    StaffUserIn,
    StaffUserOut,
    StaffAssignCounterIn,
    BranchIn,
)
from backend.app.security import hash_password, make_salt, verify_password

app = FastAPI(title="IntelliQueue Local API", version="0.0.2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def now_iso() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _seed_admin() -> None:
    """
    Ensure the prototype admin exists.
    email: admin@gmail.com
    password: Admin@123
    """
    with tx() as conn:
        row = conn.execute("SELECT staffId FROM staff_users WHERE email = ?", ("admin@gmail.com",)).fetchone()
        if row:
            return
        salt = make_salt()
        pw_hash = hash_password("Admin@123", salt)
        staff_id = "admin-1"
        conn.execute(
            """
            INSERT INTO staff_users(staffId, name, email, role, assignedCounterId, status,
                                   passwordSalt, passwordHash, createdAt, updatedAt)
            VALUES(?,?,?,?,?,?,?,?,?,?)
            """,
            (
                staff_id,
                "Admin",
                "admin@gmail.com",
                "admin",
                None,
                "active",
                salt,
                pw_hash,
                now_iso(),
                now_iso(),
            ),
        )


def _seed_default_branch() -> None:
    """
    Seed a default branch so Admin can create services immediately.
    """
    with tx() as conn:
        row = conn.execute("SELECT branchId FROM branches LIMIT 1").fetchone()
        if row:
            return
        conn.execute(
            "INSERT INTO branches(branchId,name,address,isActive,createdAt,updatedAt) VALUES(?,?,?,?,?,?)",
            ("b1", "Main Branch", "Local Demo", 1, now_iso(), now_iso()),
        )


def _reset_non_admin_staff_once() -> None:
    """
    One-time cleanup for thesis/demo: keep only admin user.
    This runs once and then stores a marker in `app_meta`.
    """
    with tx() as conn:
        marker = conn.execute(
            "SELECT value FROM app_meta WHERE key='staff_reset_done' LIMIT 1"
        ).fetchone()
        if marker and (marker["value"] or "").strip() == "1":
            return

        # Delete all non-admin staff users.
        conn.execute("DELETE FROM staff_users WHERE role != 'admin'")

        # Clear counter staff assignment links (best-effort).
        conn.execute("UPDATE counters SET assignedStaffEmail=NULL, updatedAt=?", (now_iso(),))

        conn.execute(
            "INSERT OR REPLACE INTO app_meta(key,value) VALUES('staff_reset_done','1')"
        )


def _seed_mobile_branches_and_counters() -> None:
    """
    Seed the same 3 branches as the mobile app and ensure 3 counters each.
    This is for thesis/demo convenience so the admin portal matches mobile UI.
    """
    branches = [
        ("hetauda", "Hetauda Branch", "Buddha Chowk", 1),
        ("kathmandu", "Kathmandu Branch", "Budhanikantha", 1),
        ("lalitpur", "Lalitpur Branch", "Ekantakuma", 1),
    ]

    # Demo services per branch (kept aligned with customer app).
    services = [
        ("customer_service", "Customer Service", "Support", 15, 1),
        ("technical_support", "Technical Support", "Support", 20, 1),
        ("sales_inquiry", "Sales Inquiry", "Sales", 6, 1),
        ("billing", "Billing", "Finance", 7, 1),
        ("account_opening", "Account opening", "Operations", 15, 1),
    ]

    with tx() as conn:
        for branch_id, name, address, active in branches:
            existing = conn.execute(
                "SELECT branchId FROM branches WHERE branchId=?",
                (branch_id,),
            ).fetchone()
            if existing:
                conn.execute(
                    "UPDATE branches SET name=?, address=?, isActive=?, updatedAt=? WHERE branchId=?",
                    (name, address, active, now_iso(), branch_id),
                )
            else:
                conn.execute(
                    "INSERT INTO branches(branchId,name,address,isActive,createdAt,updatedAt) VALUES(?,?,?,?,?,?)",
                    (branch_id, name, address, active, now_iso(), now_iso()),
                )

            expected_service_ids = set()
            for key, sname, cat, eta, active in services:
                service_id = f"{branch_id}_{key}"
                expected_service_ids.add(service_id)
                svc = conn.execute(
                    "SELECT serviceId FROM services WHERE serviceId=?",
                    (service_id,),
                ).fetchone()
                if svc:
                    conn.execute(
                        """
                        UPDATE services
                        SET name=?, category=?, defaultEtaMinutes=?, isActive=?, updatedAt=?
                        WHERE serviceId=?
                        """,
                        (sname, cat, eta, active, now_iso(), service_id),
                    )
                else:
                    conn.execute(
                        """
                        INSERT INTO services(serviceId,branchId,name,category,defaultEtaMinutes,isActive,createdAt,updatedAt)
                        VALUES(?,?,?,?,?,?,?,?)
                        """,
                        (service_id, branch_id, sname, cat, eta, active, now_iso(), now_iso()),
                    )

            # Remove any extra services for this branch (demo reset expectation).
            extra = conn.execute(
                "SELECT serviceId FROM services WHERE branchId=?",
                (branch_id,),
            ).fetchall()
            for r in extra:
                sid = (r["serviceId"] or "").strip()
                if sid and sid not in expected_service_ids:
                    conn.execute("DELETE FROM services WHERE serviceId=?", (sid,))

            # Ensure each service has exactly 3 counters (Counter 1..3)
            for key, _, __, ___, ____ in services:
                service_id = f"{branch_id}_{key}"
                rows = conn.execute(
                    "SELECT counterId, counterName FROM counters WHERE branchId=? AND serviceId=?",
                    (branch_id, service_id),
                ).fetchall()
                for r in rows:
                    cname = (r["counterName"] or "").strip()
                    if cname.lower().startswith("counter "):
                        try:
                            n = int(cname.split(" ", 1)[1])
                        except Exception:
                            n = 0
                        if n > 3:
                            conn.execute("DELETE FROM counters WHERE counterId=?", (r["counterId"],))

                existing_names = {
                    (r["counterName"] or "").strip()
                    for r in conn.execute(
                        "SELECT counterName FROM counters WHERE branchId=? AND serviceId=?",
                        (branch_id, service_id),
                    ).fetchall()
                }
                for i in range(1, 4):
                    cname = f"Counter {i}"
                    if cname in existing_names:
                        continue
                    counter_id = f"{branch_id}_{key}_c{i}"
                    conn.execute(
                        """
                        INSERT OR REPLACE INTO counters(counterId,counterName,branchId,serviceId,status,assignedStaffEmail,updatedAt)
                        VALUES(?,?,?,?,?,?,?)
                        """,
                        (counter_id, cname, branch_id, service_id, "active", None, now_iso()),
                    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.on_event("startup")
def _startup():
    init_db()
    _seed_admin()
    _reset_non_admin_staff_once()
    _seed_mobile_branches_and_counters()
    _seed_default_branch()


# -----------------------
# ADMIN DASHBOARD (Phase 8)
# -----------------------


@app.get("/admin/overview")
def admin_overview():
    """
    Compute dashboard metrics from SQLite.
    """
    with tx() as conn:
        today = conn.execute("SELECT DATE('now') AS d").fetchone()["d"]

        total_daily_tokens = conn.execute(
            "SELECT COUNT(*) AS c FROM bookings WHERE DATE(createdAt)=?",
            (today,),
        ).fetchone()["c"]

        active_queues = conn.execute(
            """
            SELECT COUNT(*) AS c FROM (
              SELECT branchId, serviceId
              FROM bookings
              WHERE status IN ('active','waiting','serving') AND DATE(createdAt)=?
              GROUP BY branchId, serviceId
            )
            """,
            (today,),
        ).fetchone()["c"]

        total_staff = conn.execute(
            "SELECT COUNT(*) AS c FROM staff_users WHERE role != 'admin'",
        ).fetchone()["c"]

        # Average serving duration in minutes for completed bookings (simple)
        avg_wait = conn.execute(
            """
            SELECT AVG((julianday(completedAt) - julianday(createdAt)) * 24 * 60) AS m
            FROM bookings
            WHERE completedAt IS NOT NULL AND DATE(createdAt)=?
            """,
            (today,),
        ).fetchone()["m"]
        avg_wait_minutes = int(avg_wait) if avg_wait is not None else 0

        # Recent activity (today)
        today_activity_rows = conn.execute(
            """
            SELECT tokenNumber, serviceName, branchName, status, createdAt, updatedAt, completedAt, cancelledAt
            FROM bookings
            WHERE DATE(createdAt)=?
            ORDER BY createdAt DESC
            LIMIT 12
            """,
            (today,),
        ).fetchall()
        today_activity = [
            {
                "tokenNumber": r["tokenNumber"],
                "serviceName": r["serviceName"] or "",
                "branchName": r["branchName"] or "",
                "status": r["status"],
                "createdAt": r["createdAt"],
                "updatedAt": r["updatedAt"],
                "completedAt": r["completedAt"],
                "cancelledAt": r["cancelledAt"],
            }
            for r in today_activity_rows
        ]

        # Service distribution (today)
        dist_rows = conn.execute(
            """
            SELECT COALESCE(serviceName,'Unknown') AS serviceName, COUNT(*) AS c
            FROM bookings
            WHERE DATE(createdAt)=?
            GROUP BY COALESCE(serviceName,'Unknown')
            ORDER BY c DESC, serviceName ASC
            LIMIT 12
            """,
            (today,),
        ).fetchall()
        service_distribution = [{"serviceName": r["serviceName"], "count": int(r["c"] or 0)} for r in dist_rows]

        # System status (simple, real counts)
        active_counters = conn.execute(
            "SELECT COUNT(*) AS c FROM counters WHERE status='active'",
        ).fetchone()["c"]
        inactive_counters = conn.execute(
            "SELECT COUNT(*) AS c FROM counters WHERE status!='active'",
        ).fetchone()["c"]
        active_staff = conn.execute(
            "SELECT COUNT(*) AS c FROM staff_users WHERE status='active' AND role != 'admin'",
        ).fetchone()["c"]

        return {
            "totalDailyTokens": int(total_daily_tokens or 0),
            "activeQueues": int(active_queues or 0),
            "totalStaff": int(total_staff or 0),
            "avgWaitMinutes": int(avg_wait_minutes),
            "todayActivity": today_activity,
            "serviceDistribution": service_distribution,
            "systemStatus": {
                "allSystem": "Operational",
                "database": "Operational",
                "apiServices": "Operational",
                "activeCounters": int(active_counters or 0),
                "inactiveCounters": int(inactive_counters or 0),
                "activeStaff": int(active_staff or 0),
            },
        }


@app.get("/admin/analytics")
def admin_analytics():
    """
    Read-only analytics summary.
    """
    with tx() as conn:
        today = conn.execute("SELECT DATE('now') AS d").fetchone()["d"]
        total_daily_tokens = conn.execute(
            "SELECT COUNT(*) AS c FROM bookings WHERE DATE(createdAt)=?",
            (today,),
        ).fetchone()["c"]
        active_queues = conn.execute(
            """
            SELECT COUNT(*) AS c FROM (
              SELECT branchId, serviceId
              FROM bookings
              WHERE status IN ('active','waiting','serving') AND DATE(createdAt)=?
              GROUP BY branchId, serviceId
            )
            """,
            (today,),
        ).fetchone()["c"]
        total_staff = conn.execute(
            "SELECT COUNT(*) AS c FROM staff_users WHERE role != 'admin'",
        ).fetchone()["c"]

        # Token trend (last 7 days)
        trend_rows = conn.execute(
            """
            WITH days AS (
              SELECT DATE('now','-6 day') AS d UNION ALL
              SELECT DATE('now','-5 day') UNION ALL
              SELECT DATE('now','-4 day') UNION ALL
              SELECT DATE('now','-3 day') UNION ALL
              SELECT DATE('now','-2 day') UNION ALL
              SELECT DATE('now','-1 day') UNION ALL
              SELECT DATE('now') 
            )
            SELECT days.d AS day, COALESCE(b.c,0) AS c
            FROM days
            LEFT JOIN (
              SELECT DATE(createdAt) AS day, COUNT(*) AS c
              FROM bookings
              WHERE DATE(createdAt) BETWEEN DATE('now','-6 day') AND DATE('now')
              GROUP BY DATE(createdAt)
            ) b ON b.day = days.d
            ORDER BY days.d ASC
            """
        ).fetchall()
        last7days = [{"day": r["day"], "tokens": int(r["c"] or 0)} for r in trend_rows]

        # Service distribution (today)
        dist_rows = conn.execute(
            """
            SELECT COALESCE(serviceName,'Unknown') AS serviceName, COUNT(*) AS c
            FROM bookings
            WHERE DATE(createdAt)=?
            GROUP BY COALESCE(serviceName,'Unknown')
            ORDER BY c DESC, serviceName ASC
            LIMIT 12
            """,
            (today,),
        ).fetchall()
        service_distribution = [{"serviceName": r["serviceName"], "count": int(r["c"] or 0)} for r in dist_rows]

        # Counter performance (today): completed tokens grouped by counter
        perf_rows = conn.execute(
            """
            SELECT COALESCE(c.counterName,'Unassigned') AS counterName, COUNT(*) AS c
            FROM bookings b
            LEFT JOIN counters c ON c.counterId = b.servingCounterId
            WHERE b.completedAt IS NOT NULL AND DATE(b.createdAt)=?
            GROUP BY COALESCE(c.counterName,'Unassigned')
            ORDER BY c DESC, counterName ASC
            LIMIT 12
            """,
            (today,),
        ).fetchall()
        counter_performance = [{"counterName": r["counterName"], "served": int(r["c"] or 0)} for r in perf_rows]

        return {
            "totalDailyTokens": int(total_daily_tokens or 0),
            "activeQueues": int(active_queues or 0),
            "totalStaff": int(total_staff or 0),
            "last7Days": last7days,
            "serviceDistribution": service_distribution,
            "counterPerformance": counter_performance,
        }


# -----------------------
# AUTH (thesis-local)
# -----------------------


@app.post("/auth/login", response_model=LoginResponse)
def login(req: LoginRequest):
    with tx() as conn:
        row = conn.execute(
            """
            SELECT
              u.staffId, u.name, u.email, u.role, u.passwordSalt, u.passwordHash, u.status,
              u.assignedCounterId,
              c.counterName AS assignedCounterName,
              s.name AS assignedServiceName
            FROM staff_users u
            LEFT JOIN counters c ON c.counterId = u.assignedCounterId
            LEFT JOIN services s ON s.serviceId = c.serviceId
            WHERE u.email = ?
            """,
            (req.email,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        if (row["status"] or "active") != "active":
            raise HTTPException(status_code=403, detail="Account is not active")
        if not verify_password(req.password, row["passwordSalt"], row["passwordHash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return LoginResponse(
            staffId=row["staffId"],
            email=row["email"],
            name=row["name"],
            role=row["role"],
            assignedCounterId=row["assignedCounterId"],
            assignedCounterName=row["assignedCounterName"],
            assignedServiceName=row["assignedServiceName"],
        )


# -----------------------
# CUSTOMER AUTH (online)
# -----------------------


@app.post("/customer/auth/signup")
def customer_signup(req: CustomerSignupIn):
    phone = (req.userPhone or "").strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone is required")
    if not req.password:
        raise HTTPException(status_code=400, detail="Password is required")
    with tx() as conn:
        existing = conn.execute("SELECT userPhone FROM customer_users WHERE userPhone=?", (phone,)).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="Account already exists for this phone")
        salt = make_salt()
        pw_hash = hash_password(req.password, salt)
        conn.execute(
            """
            INSERT INTO customer_users(userPhone,name,email,passwordSalt,passwordHash,status,createdAt,updatedAt)
            VALUES(?,?,?,?,?,?,?,?)
            """,
            (
                phone,
                (req.name or "").strip() or None,
                (req.email or "").strip() or None,
                salt,
                pw_hash,
                "active",
                now_iso(),
                now_iso(),
            ),
        )
    return {"ok": True}


@app.post("/customer/auth/login")
def customer_login(req: CustomerLoginIn):
    phone = (req.userPhone or "").strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone is required")
    with tx() as conn:
        row = conn.execute(
            """
            SELECT userPhone, name, email, status, passwordSalt, passwordHash
            FROM customer_users
            WHERE userPhone=?
            """,
            (phone,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        if (row["status"] or "active") != "active":
            raise HTTPException(status_code=403, detail="Account is not active")
        if not verify_password(req.password, row["passwordSalt"], row["passwordHash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return {
            "ok": True,
            "userPhone": row["userPhone"],
            "name": row["name"],
            "email": row["email"],
        }


# -----------------------
# ADMIN: CUSTOMERS
# -----------------------


@app.get("/admin/customers", response_model=list[CustomerOut])
def admin_list_customers():
    with tx() as conn:
        # Customers can exist in 2 ways:
        # 1) Explicit account created in customer_users (online signup)
        # 2) Mobile offline-first users who only appear on server via bookings (userPhone)
        rows = conn.execute(
            """
            WITH phones AS (
              SELECT
                userPhone,
                MIN(createdAt) AS firstSeenAt,
                MAX(createdAt) AS lastSeenAt
              FROM bookings
              WHERE userPhone IS NOT NULL AND TRIM(userPhone) != ''
              GROUP BY userPhone
            )
            SELECT
              COALESCE(c.userPhone, p.userPhone) AS userPhone,
              c.name AS name,
              c.email AS email,
              COALESCE(c.status, 'active') AS status,
              COALESCE(c.createdAt, p.firstSeenAt, ?) AS createdAt,
              COALESCE(c.updatedAt, p.lastSeenAt) AS updatedAt
            FROM phones p
            LEFT JOIN customer_users c ON c.userPhone = p.userPhone

            UNION ALL

            SELECT
              c.userPhone AS userPhone,
              c.name AS name,
              c.email AS email,
              COALESCE(c.status, 'active') AS status,
              c.createdAt AS createdAt,
              c.updatedAt AS updatedAt
            FROM customer_users c
            WHERE c.userPhone NOT IN (SELECT userPhone FROM phones)

            ORDER BY createdAt DESC
            """,
            (now_iso(),),
        ).fetchall()
        return [CustomerOut(**dict(r)) for r in rows]


@app.post("/admin/customers/reset-password")
def admin_reset_customer_password(req: AdminResetCustomerPasswordIn):
    phone = (req.userPhone or "").strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone is required")
    with tx() as conn:
        salt = make_salt()
        pw_hash = hash_password(req.newPassword, salt)
        row = conn.execute("SELECT userPhone FROM customer_users WHERE userPhone=?", (phone,)).fetchone()
        if row:
            conn.execute(
                """
                UPDATE customer_users
                SET passwordSalt=?, passwordHash=?, updatedAt=?
                WHERE userPhone=?
                """,
                (salt, pw_hash, now_iso(), phone),
            )
        else:
            # Allow Admin to reset password even if the user was only seen in bookings.
            conn.execute(
                """
                INSERT INTO customer_users(userPhone,name,email,passwordSalt,passwordHash,status,createdAt,updatedAt)
                VALUES(?,?,?,?,?,?,?,?)
                """,
                (phone, None, None, salt, pw_hash, "active", now_iso(), now_iso()),
            )
    return {"ok": True}


@app.post("/admin/reset-demo")
def admin_reset_demo():
    """
    Reset demo data (customers, tokens, services, counters, non-admin staff).
    Keeps branches and the admin account.
    """
    with tx() as conn:
        # Tokens + customer-visible data
        conn.execute("DELETE FROM notifications")
        conn.execute("DELETE FROM bookings")
        conn.execute("DELETE FROM feedback")

        # Users
        conn.execute("DELETE FROM customer_users")
        conn.execute("DELETE FROM staff_users WHERE role != 'admin'")

        # Services/counters (keep branches)
        conn.execute("DELETE FROM counters")
        conn.execute("DELETE FROM services")

        # Re-seed standard branches/services/counters
        _seed_mobile_branches_and_counters()

        # Clear any staff assignment links (best-effort; counters were recreated)
        conn.execute("UPDATE counters SET assignedStaffEmail=NULL, updatedAt=?", (now_iso(),))

        # Allow the one-time startup staff reset to run again in the future if needed
        conn.execute("DELETE FROM app_meta WHERE key='staff_reset_done'")

    return {"ok": True}


# -----------------------
# ADMIN CRUD (minimal)
# -----------------------


@app.post("/admin/branches")
def upsert_branch(b: BranchIn):
    with tx() as conn:
        existing = conn.execute("SELECT branchId FROM branches WHERE branchId=?", (b.branchId,)).fetchone()
        if existing:
            conn.execute(
                "UPDATE branches SET name=?, address=?, isActive=?, updatedAt=? WHERE branchId=?",
                (b.name, b.address, 1 if b.isActive else 0, now_iso(), b.branchId),
            )
        else:
            conn.execute(
                "INSERT INTO branches(branchId,name,address,isActive,createdAt,updatedAt) VALUES(?,?,?,?,?,?)",
                (b.branchId, b.name, b.address, 1 if b.isActive else 0, now_iso(), now_iso()),
            )
    return {"ok": True}


@app.get("/admin/branches")
def list_branches():
    with tx() as conn:
        rows = conn.execute("SELECT * FROM branches ORDER BY name").fetchall()
        return [dict(r) | {"isActive": bool(r["isActive"])} for r in rows]


@app.delete("/admin/branches/{branchId}")
def delete_branch(branchId: str):
    with tx() as conn:
        conn.execute("DELETE FROM branches WHERE branchId=?", (branchId,))
    return {"ok": True}


@app.post("/admin/services")
def upsert_service(s: ServiceIn):
    with tx() as conn:
        existing = conn.execute("SELECT serviceId FROM services WHERE serviceId=?", (s.serviceId,)).fetchone()
        if existing:
            conn.execute(
                """
                UPDATE services
                SET branchId=?, name=?, category=?, defaultEtaMinutes=?, isActive=?, updatedAt=?
                WHERE serviceId=?
                """,
                (s.branchId, s.name, s.category, s.defaultEtaMinutes, 1 if s.isActive else 0, now_iso(), s.serviceId),
            )
        else:
            conn.execute(
                """
                INSERT INTO services(serviceId,branchId,name,category,defaultEtaMinutes,isActive,createdAt,updatedAt)
                VALUES(?,?,?,?,?,?,?,?)
                """,
                (s.serviceId, s.branchId, s.name, s.category, s.defaultEtaMinutes, 1 if s.isActive else 0, now_iso(), now_iso()),
            )
    return {"ok": True}


@app.get("/admin/services")
def list_services(branchId: Optional[str] = None):
    with tx() as conn:
        if branchId:
            rows = conn.execute("SELECT * FROM services WHERE branchId=? ORDER BY name", (branchId,)).fetchall()
        else:
            rows = conn.execute("SELECT * FROM services ORDER BY name").fetchall()
        return [dict(r) | {"isActive": bool(r["isActive"])} for r in rows]


@app.delete("/admin/services/{serviceId}")
def delete_service(serviceId: str):
    with tx() as conn:
        conn.execute("DELETE FROM services WHERE serviceId=?", (serviceId,))
    return {"ok": True}


@app.get("/admin/queues-summary")
def queues_summary(branchId: Optional[str] = None):
    """
    Summary for Manage Queues UI:
    - queueName (service name)
    - waitingCount (active/waiting)
    - countersCount (counters assigned to that service)
    - status (isActive)
    """
    where = ""
    args: list[str] = []
    if branchId:
        where = "WHERE s.branchId=?"
        args.append(branchId)

    with tx() as conn:
        rows = conn.execute(
            f"""
            SELECT
              s.serviceId,
              s.branchId,
              s.name AS queueName,
              s.isActive,
              COALESCE(c.countersCount, 0) AS countersCount,
              COALESCE(w.waitingCount, 0) AS waitingCount
            FROM services s
            LEFT JOIN (
              SELECT serviceId, COUNT(*) AS countersCount
              FROM counters
              GROUP BY serviceId
            ) c ON c.serviceId = s.serviceId
            LEFT JOIN (
              SELECT serviceId, branchId, COUNT(*) AS waitingCount
              FROM bookings
              WHERE status IN ('active','waiting')
              GROUP BY serviceId, branchId
            ) w ON w.serviceId = s.serviceId AND w.branchId = s.branchId
            {where}
            ORDER BY s.name
            """,
            args,
        ).fetchall()
        return [dict(r) | {"isActive": bool(r["isActive"])} for r in rows]


@app.post("/admin/counters")
def upsert_counter(c: CounterIn):
    with tx() as conn:
        existing = conn.execute("SELECT counterId FROM counters WHERE counterId=?", (c.counterId,)).fetchone()
        if existing:
            conn.execute(
                """
                UPDATE counters
                SET counterName=?, branchId=?, serviceId=?, status=?, assignedStaffEmail=?, updatedAt=?
                WHERE counterId=?
                """,
                (c.counterName, c.branchId, c.serviceId, c.status, c.assignedStaffEmail, now_iso(), c.counterId),
            )
        else:
            conn.execute(
                """
                INSERT INTO counters(counterId,counterName,branchId,serviceId,status,assignedStaffEmail,updatedAt)
                VALUES(?,?,?,?,?,?,?)
                """,
                (c.counterId, c.counterName, c.branchId, c.serviceId, c.status, c.assignedStaffEmail, now_iso()),
            )
    return {"ok": True}


@app.get("/admin/counters")
def list_counters(branchId: Optional[str] = None, serviceId: Optional[str] = None):
    where = []
    args: list[str] = []
    if branchId:
        where.append("branchId=?")
        args.append(branchId)
    if serviceId:
        where.append("serviceId=?")
        args.append(serviceId)
    clause = ("WHERE " + " AND ".join(where)) if where else ""
    with tx() as conn:
        rows = conn.execute(f"SELECT * FROM counters {clause} ORDER BY counterName", args).fetchall()
        return [dict(r) for r in rows]


@app.delete("/admin/counters/{counterId}")
def delete_counter(counterId: str):
    with tx() as conn:
        conn.execute("DELETE FROM counters WHERE counterId=?", (counterId,))
    return {"ok": True}


@app.post("/admin/staff")
def upsert_staff(u: StaffUserIn):
    salt = make_salt()
    pw_hash = hash_password(u.password, salt)
    with tx() as conn:
        # Clear old counter assignment (if editing)
        old = conn.execute(
            "SELECT email, assignedCounterId FROM staff_users WHERE staffId=?",
            (u.staffId,),
        ).fetchone()
        if old and old["assignedCounterId"] and (old["assignedCounterId"] != u.assignedCounterId):
            conn.execute(
                "UPDATE counters SET assignedStaffEmail=NULL, updatedAt=? WHERE counterId=?",
                (now_iso(), old["assignedCounterId"]),
            )

        existing = conn.execute("SELECT staffId FROM staff_users WHERE staffId=?", (u.staffId,)).fetchone()
        if existing:
            conn.execute(
                """
                UPDATE staff_users
                SET name=?, email=?, role=?, assignedCounterId=?, status=?, passwordSalt=?, passwordHash=?, updatedAt=?
                WHERE staffId=?
                """,
                (
                    u.name,
                    u.email,
                    u.role,
                    u.assignedCounterId,
                    u.status,
                    salt,
                    pw_hash,
                    now_iso(),
                    u.staffId,
                ),
            )
        else:
            conn.execute(
                """
                INSERT INTO staff_users(staffId,name,email,role,assignedCounterId,status,passwordSalt,passwordHash,createdAt,updatedAt)
                VALUES(?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    u.staffId,
                    u.name,
                    u.email,
                    u.role,
                    u.assignedCounterId,
                    u.status,
                    salt,
                    pw_hash,
                    now_iso(),
                    now_iso(),
                ),
            )

        # Apply new counter assignment
        if u.assignedCounterId:
            conn.execute(
                "UPDATE counters SET assignedStaffEmail=?, updatedAt=? WHERE counterId=?",
                (u.email, now_iso(), u.assignedCounterId),
            )
    return {"ok": True}


@app.get("/admin/staff", response_model=list[StaffUserOut])
def list_staff():
    with tx() as conn:
        rows = conn.execute(
            """
            SELECT
              u.staffId, u.name, u.email, u.role, u.assignedCounterId,
              c.counterName AS assignedCounterName,
              u.status, u.createdAt, u.updatedAt
            FROM staff_users u
            LEFT JOIN counters c ON c.counterId = u.assignedCounterId
            ORDER BY u.createdAt DESC
            """
        ).fetchall()
        return [dict(r) for r in rows]


@app.delete("/admin/staff/{staffId}")
def delete_staff(staffId: str):
    with tx() as conn:
        row = conn.execute("SELECT email, assignedCounterId FROM staff_users WHERE staffId=?", (staffId,)).fetchone()
        if row and row["assignedCounterId"]:
            conn.execute(
                "UPDATE counters SET assignedStaffEmail=NULL, updatedAt=? WHERE counterId=?",
                (now_iso(), row["assignedCounterId"]),
            )
        conn.execute("DELETE FROM staff_users WHERE staffId=?", (staffId,))
    return {"ok": True}


# -----------------------
# CUSTOMER endpoints
# -----------------------


def _priority_rank(token_type: str) -> int:
    return 0 if token_type == "SeniorCitizen" else (1 if token_type == "VIP" else 2)


@app.post("/customer/bookings")
def create_booking(inp: BookingCreateIn):
    created_at = now_iso()
    booking_id = str(int(datetime.utcnow().timestamp() * 1_000_000))
    with tx() as conn:
        # Validate branch/service exist
        br = conn.execute("SELECT name, isActive FROM branches WHERE branchId=?", (inp.branchId,)).fetchone()
        sv = conn.execute(
            "SELECT name, defaultEtaMinutes, isActive FROM services WHERE serviceId=? AND branchId=?",
            (inp.serviceId, inp.branchId),
        ).fetchone()
        if not br:
            raise HTTPException(status_code=400, detail="Invalid branchId")
        if not sv:
            raise HTTPException(status_code=400, detail="Invalid serviceId for branch")
        if not bool(br["isActive"]) or not bool(sv["isActive"]):
            raise HTTPException(status_code=400, detail="Branch/service inactive")

        # Ensure the customer exists for Admin management.
        # If the customer was created only on mobile (offline-first), we still want the Admin
        # to be able to reset their password from the portal once the phone appears on server.
        cust = conn.execute("SELECT userPhone FROM customer_users WHERE userPhone=?", (inp.userPhone,)).fetchone()
        if not cust:
            salt = make_salt()
            pw_hash = hash_password("Temp@1234", salt)
            conn.execute(
                """
                INSERT INTO customer_users(userPhone,name,email,passwordSalt,passwordHash,status,createdAt,updatedAt)
                VALUES(?,?,?,?,?,?,?,?)
                """,
                (inp.userPhone.strip(), None, None, salt, pw_hash, "active", now_iso(), now_iso()),
            )

        # Ensure one active booking per phone (simple rule)
        active = conn.execute(
            "SELECT bookingId FROM bookings WHERE userPhone=? AND status IN ('active','waiting','serving') ORDER BY createdAt DESC LIMIT 1",
            (inp.userPhone,),
        ).fetchone()
        if active:
            raise HTTPException(status_code=409, detail="User already has an active token")

        # Generate token number per queue (branchId+serviceId).
        # Use MAX() to avoid duplicates when multiple inserts share same createdAt second.
        last_num = conn.execute(
            """
            SELECT MAX(CAST(SUBSTR(tokenNumber, 2) AS INTEGER)) AS n
            FROM bookings
            WHERE branchId=? AND serviceId=? AND tokenNumber LIKE 'A%'
            """,
            (inp.branchId, inp.serviceId),
        ).fetchone()
        next_num = (int(last_num["n"]) + 1) if (last_num and last_num["n"] is not None) else 1
        token_number = f"A{str(next_num).zfill(3)}"

        conn.execute(
            """
            INSERT INTO bookings(
              bookingId,userPhone,branchId,branchName,serviceId,serviceName,
              tokenNumber,tokenType,status,createdAt,updatedAt
            )
            VALUES(?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                booking_id,
                inp.userPhone,
                inp.branchId,
                br["name"],
                inp.serviceId,
                sv["name"],
                token_number,
                inp.tokenType,
                "active",
                created_at,
                created_at,
            ),
        )
    return {"bookingId": booking_id, "tokenNumber": token_number, "status": "active"}


@app.get("/customer/bookings/{bookingId}")
def get_booking(bookingId: str):
    with tx() as conn:
        row = conn.execute("SELECT * FROM bookings WHERE bookingId=?", (bookingId,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Booking not found")
        return dict(row)


@app.get("/customer/users/{userPhone}/bookings")
def list_user_bookings(userPhone: str):
    with tx() as conn:
        rows = conn.execute(
            "SELECT * FROM bookings WHERE userPhone=? ORDER BY createdAt DESC LIMIT 200", (userPhone,)
        ).fetchall()
        return [dict(r) for r in rows]


@app.get("/customer/queue/{branchId}/{serviceId}")
def queue_status(branchId: str, serviceId: str):
    """
    Derived queue view for polling.
    """
    with tx() as conn:
        serving = conn.execute(
            "SELECT bookingId, tokenNumber, tokenType, servingCounterId, createdAt FROM bookings WHERE branchId=? AND serviceId=? AND status='serving' ORDER BY createdAt ASC",
            (branchId, serviceId),
        ).fetchall()
        waiting = conn.execute(
            "SELECT bookingId, tokenNumber, tokenType, createdAt FROM bookings WHERE branchId=? AND serviceId=? AND status IN ('active','waiting') ORDER BY createdAt ASC",
            (branchId, serviceId),
        ).fetchall()

        waiting_items = [dict(r) | {"priorityRank": _priority_rank(r["tokenType"])} for r in waiting]
        waiting_items.sort(key=lambda x: (x["priorityRank"], x["createdAt"]))

        return {
            "branchId": branchId,
            "serviceId": serviceId,
            "nowServing": [dict(r) for r in serving],
            "waitingTokens": waiting_items,
            "waitingCount": len(waiting_items),
            "updatedAt": now_iso(),
        }


# -----------------------
# STAFF operations (minimal)
# -----------------------


def _get_staff(conn, staff_id: str):
    row = conn.execute(
        "SELECT staffId,email,name,status,assignedCounterId,role FROM staff_users WHERE staffId=?",
        (staff_id,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Staff not found")
    if (row["status"] or "active") != "active":
        raise HTTPException(status_code=403, detail="Staff not active")
    return row


def _get_counter(conn, counter_id: str):
    row = conn.execute("SELECT * FROM counters WHERE counterId=?", (counter_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Counter not found")
    return row


def _get_staff_queue_context(conn, staff_id: str):
    staff = _get_staff(conn, staff_id)
    counter_id = staff["assignedCounterId"]
    if not counter_id:
        raise HTTPException(status_code=400, detail="No counter assigned")
    counter = _get_counter(conn, counter_id)
    service = conn.execute("SELECT * FROM services WHERE serviceId=?", (counter["serviceId"],)).fetchone()
    branch = conn.execute("SELECT * FROM branches WHERE branchId=?", (counter["branchId"],)).fetchone()
    return staff, counter, service, branch


def _pick_next_waiting(conn, branch_id: str, service_id: str):
    rows = conn.execute(
        "SELECT bookingId, tokenType, createdAt FROM bookings WHERE branchId=? AND serviceId=? AND status IN ('active','waiting')",
        (branch_id, service_id),
    ).fetchall()
    if not rows:
        return None
    items = [dict(r) for r in rows]
    items.sort(key=lambda r: (_priority_rank(r["tokenType"]), r["createdAt"]))
    return items[0]["bookingId"]


@app.get("/staff/context/{staffId}")
def staff_context(staffId: str):
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, staffId)
        return {
            "staffId": staff["staffId"],
            "staffName": staff["name"],
            "staffEmail": staff["email"],
            "role": staff["role"],
            "counterId": counter["counterId"],
            "counterName": counter["counterName"],
            "counterStatus": counter["status"],
            "branchId": counter["branchId"],
            "branchName": (branch["name"] if branch else None),
            "serviceId": counter["serviceId"],
            "serviceName": (service["name"] if service else None),
        }


@app.get("/staff/overview/{staffId}")
def staff_overview(staffId: str):
    """
    Staff dashboard overview scoped to staff's assigned branch/service.
    """
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, staffId)
        branch_id = counter["branchId"]
        service_id = counter["serviceId"]

        today = conn.execute("SELECT DATE('now') AS d").fetchone()["d"]

        # Queue snapshot (derived)
        q = queue_status(branch_id, service_id)

        # Counters in this branch
        active_counters = conn.execute(
            "SELECT COUNT(*) AS c FROM counters WHERE branchId=? AND status='active'",
            (branch_id,),
        ).fetchone()["c"]

        # Tokens today for this branch/service
        todays_tokens = conn.execute(
            "SELECT COUNT(*) AS c FROM bookings WHERE branchId=? AND serviceId=? AND DATE(createdAt)=?",
            (branch_id, service_id, today),
        ).fetchone()["c"]

        # Token summary (today)
        summary_rows = conn.execute(
            """
            SELECT status, COUNT(*) AS c
            FROM bookings
            WHERE branchId=? AND serviceId=? AND DATE(createdAt)=?
            GROUP BY status
            """,
            (branch_id, service_id, today),
        ).fetchall()
        summary = {r["status"]: int(r["c"] or 0) for r in summary_rows}

        # Map nowServing counter ids to names
        counters_rows = conn.execute(
            "SELECT counterId, counterName FROM counters WHERE branchId=?",
            (branch_id,),
        ).fetchall()
        counter_map = {r["counterId"]: r["counterName"] for r in counters_rows}
        now_serving = []
        for item in q.get("nowServing", []):
            m = dict(item)
            cid = m.get("servingCounterId")
            if cid:
                m["counterName"] = counter_map.get(cid)
            now_serving.append(m)

        # Latest tokens (today)
        recent_rows = conn.execute(
            """
            SELECT bookingId, tokenNumber, tokenType, status, userPhone, createdAt
            FROM bookings
            WHERE branchId=? AND serviceId=? AND DATE(createdAt)=?
            ORDER BY createdAt DESC
            LIMIT 12
            """,
            (branch_id, service_id, today),
        ).fetchall()
        recent_tokens = [dict(r) for r in recent_rows]

        return {
            "branchId": branch_id,
            "branchName": (branch["name"] if branch else None),
            "serviceId": service_id,
            "serviceName": (service["name"] if service else None),
            "activeCounters": int(active_counters or 0),
            "todaysTokens": int(todays_tokens or 0),
            "currentWaiting": int(q.get("waitingCount") or 0),
            "nowServing": now_serving,
            "waitingTokens": q.get("waitingTokens", [])[:12],
            "todaySummary": summary,
            "recentTokens": recent_tokens,
            "updatedAt": now_iso(),
        }


@app.post("/staff/assign-counter")
def staff_assign_counter(inp: StaffAssignCounterIn):
    with tx() as conn:
        staff = _get_staff(conn, inp.staffId)
        counter = _get_counter(conn, inp.counterId)

        # Enforce branch lock: once assigned, staff can only switch within same branch.
        if staff["assignedCounterId"]:
            current_counter = _get_counter(conn, staff["assignedCounterId"])
            if current_counter["branchId"] != counter["branchId"]:
                raise HTTPException(status_code=403, detail="Not allowed to switch branch")
        # Clear previous counter assignment
        if staff["assignedCounterId"] and staff["assignedCounterId"] != inp.counterId:
            conn.execute(
                "UPDATE counters SET assignedStaffEmail=NULL, updatedAt=? WHERE counterId=?",
                (now_iso(), staff["assignedCounterId"]),
            )
        # Assign new counter
        conn.execute(
            "UPDATE staff_users SET assignedCounterId=?, updatedAt=? WHERE staffId=?",
            (inp.counterId, now_iso(), inp.staffId),
        )
        conn.execute(
            "UPDATE counters SET assignedStaffEmail=?, updatedAt=? WHERE counterId=?",
            (staff["email"], now_iso(), inp.counterId),
        )
        return {"ok": True, "counterId": counter["counterId"]}


@app.post("/staff/call-next")
def staff_call_next(inp: StaffActionIn):
    with tx() as conn:
        # Enforce scope: staff can only operate on their assigned counter/branch/service.
        staff, counter, service, branch = _get_staff_queue_context(conn, inp.staffId)
        if inp.counterId and inp.counterId != counter["counterId"]:
            raise HTTPException(status_code=403, detail="Not allowed for this counter")
        if counter["status"] != "active":
            raise HTTPException(status_code=400, detail="Counter not active")

        # If already serving something on this counter, block.
        existing = conn.execute(
            "SELECT bookingId FROM bookings WHERE servingCounterId=? AND status='serving' LIMIT 1",
            (inp.counterId,),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="Counter already serving a token")

        # Ignore incoming branch/service to prevent cross-branch access.
        next_id = _pick_next_waiting(conn, counter["branchId"], counter["serviceId"])
        if not next_id:
            return {"ok": True, "message": "No waiting tokens"}

        conn.execute(
            "UPDATE bookings SET status='serving', servingCounterId=?, updatedAt=? WHERE bookingId=?",
            (inp.counterId, now_iso(), next_id),
        )
        return {"ok": True, "bookingId": next_id}


@app.post("/staff/call-next-v2")
def staff_call_next_v2(staffId: str):
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, staffId)
        if counter["status"] != "active":
            raise HTTPException(status_code=400, detail="Counter not active")

        existing = conn.execute(
            "SELECT bookingId FROM bookings WHERE servingCounterId=? AND status='serving' LIMIT 1",
            (counter["counterId"],),
        ).fetchone()
        completed_id = None
        if existing:
            completed_id = existing["bookingId"]
            # Mark the currently serving token as completed, then proceed to next.
            conn.execute(
                "UPDATE bookings SET status='completed', completedAt=?, servingCounterId=NULL, updatedAt=? WHERE bookingId=?",
                (now_iso(), now_iso(), completed_id),
            )

        next_id = _pick_next_waiting(conn, counter["branchId"], counter["serviceId"])
        if not next_id:
            return {"ok": True, "message": "No one next", "completedBookingId": completed_id}
        conn.execute(
            "UPDATE bookings SET status='serving', servingCounterId=?, updatedAt=? WHERE bookingId=?",
            (counter["counterId"], now_iso(), next_id),
        )
        return {"ok": True, "bookingId": next_id, "completedBookingId": completed_id}


@app.post("/staff/skip")
def staff_skip(inp: StaffCancelIn):
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, inp.staffId)
        if inp.counterId and inp.counterId != counter["counterId"]:
            raise HTTPException(status_code=403, detail="Not allowed for this counter")
        # Only allow skipping if this booking is currently served by this counter.
        row = conn.execute(
            "SELECT bookingId FROM bookings WHERE bookingId=? AND servingCounterId=? AND status='serving'",
            (inp.bookingId, counter["counterId"]),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=400, detail="Booking is not serving on this counter")
        conn.execute(
            "UPDATE bookings SET status='skipped', skippedAt=?, servingCounterId=NULL, updatedAt=? WHERE bookingId=?",
            (now_iso(), now_iso(), inp.bookingId),
        )
        return {"ok": True}


@app.post("/staff/complete")
def staff_complete(inp: StaffCancelIn):
    """
    Mark the currently serving token as completed for this staff's counter.
    """
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, inp.staffId)
        if inp.counterId and inp.counterId != counter["counterId"]:
            raise HTTPException(status_code=403, detail="Not allowed for this counter")

        row = conn.execute(
            "SELECT bookingId FROM bookings WHERE bookingId=? AND servingCounterId=? AND status='serving'",
            (inp.bookingId, counter["counterId"]),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=400, detail="Booking is not serving on this counter")

        now = now_iso()
        conn.execute(
            "UPDATE bookings SET status='completed', completedAt=?, servingCounterId=NULL, updatedAt=? WHERE bookingId=?",
            (now, now, inp.bookingId),
        )
        return {"ok": True, "completedBookingId": inp.bookingId}


@app.post("/staff/cancel")
def staff_cancel(inp: StaffCancelIn):
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, inp.staffId)
        if inp.counterId and inp.counterId != counter["counterId"]:
            raise HTTPException(status_code=403, detail="Not allowed for this counter")
        row = conn.execute(
            "SELECT bookingId FROM bookings WHERE bookingId=? AND servingCounterId=? AND status='serving'",
            (inp.bookingId, counter["counterId"]),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=400, detail="Booking is not serving on this counter")
        conn.execute(
            "UPDATE bookings SET status='cancelled', cancelledAt=?, servingCounterId=NULL, updatedAt=? WHERE bookingId=?",
            (now_iso(), now_iso(), inp.bookingId),
        )
        return {"ok": True}


@app.post("/staff/call-now")
def staff_call_now(inp: StaffCallNowIn):
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, inp.staffId)
        if inp.counterId and inp.counterId != counter["counterId"]:
            raise HTTPException(status_code=403, detail="Not allowed for this counter")
        if counter["status"] != "active":
            raise HTTPException(status_code=400, detail="Counter not active")

        # Enforce branch/service scope: staff cannot call tokens from other branches/services.
        booking_row = conn.execute(
            "SELECT branchId, serviceId, status, servingCounterId FROM bookings WHERE bookingId=?",
            (inp.bookingId,),
        ).fetchone()
        if not booking_row:
            raise HTTPException(status_code=404, detail="Booking not found")
        if booking_row["branchId"] != counter["branchId"] or booking_row["serviceId"] != counter["serviceId"]:
            raise HTTPException(status_code=403, detail="Not allowed for this branch/service")

        # Do not steal a token already being served by another counter.
        served_elsewhere = booking_row if booking_row["status"] == "serving" else None
        if served_elsewhere and served_elsewhere["servingCounterId"] and served_elsewhere["servingCounterId"] != inp.counterId:
            raise HTTPException(status_code=409, detail="Token is being served by another counter")

        now = now_iso()

        # If this counter is already serving, complete it first (smooth workflow).
        conn.execute(
            "UPDATE bookings SET status='completed', completedAt=?, servingCounterId=NULL, updatedAt=? WHERE servingCounterId=? AND status='serving'",
            (now, now, counter["counterId"]),
        )

        # "Call Now" should start serving this token (not complete it).
        conn.execute(
            "UPDATE bookings SET status='serving', servingCounterId=?, updatedAt=? WHERE bookingId=?",
            (counter["counterId"], now, inp.bookingId),
        )
        return {"ok": True, "bookingId": inp.bookingId}


@app.get("/staff/queue/{staffId}")
def staff_queue(staffId: str):
    """
    Convenience endpoint for Staff UI (polling).
    """
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, staffId)
        # reuse derived queue logic
        return queue_status(counter["branchId"], counter["serviceId"])


@app.get("/staff/token-list")
def staff_token_list(branchId: str, serviceId: str):
    with tx() as conn:
        rows = conn.execute(
            "SELECT * FROM bookings WHERE branchId=? AND serviceId=? ORDER BY createdAt DESC LIMIT 200",
            (branchId, serviceId),
        ).fetchall()
        return [dict(r) for r in rows]


@app.get("/staff/token-list-by-staff/{staffId}")
def staff_token_list_by_staff(staffId: str):
    """
    Token list restricted to staff's assigned branch/service.
    """
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, staffId)
        rows = conn.execute(
            "SELECT * FROM bookings WHERE branchId=? AND serviceId=? ORDER BY createdAt DESC LIMIT 200",
            (counter["branchId"], counter["serviceId"]),
        ).fetchall()
        return [dict(r) for r in rows]


@app.post("/staff/notifications")
def create_notification(n: NotificationIn):
    nid = str(uuid4())
    with tx() as conn:
        conn.execute(
            """
            INSERT INTO notifications(notificationId,userPhone,title,subtitle,type,relatedBookingId,isRead,createdAt)
            VALUES(?,?,?,?,?,?,?,?)
            """,
            (nid, n.userPhone, n.title, n.subtitle, n.type, n.relatedBookingId, 0, now_iso()),
        )
    return {"ok": True, "notificationId": nid}


@app.post("/staff/notifications-by-staff/{staffId}")
def create_notification_by_staff(staffId: str, n: NotificationIn):
    """
    Create a broadcast notification for the staff's assigned service/queue type.
    Stored as global (userPhone NULL) so all customers can fetch it via polling.
    """
    with tx() as conn:
        staff, counter, service, branch = _get_staff_queue_context(conn, staffId)
        nid = str(uuid4())
        subtitle = n.subtitle
        if not subtitle:
            subtitle = f"{(branch['name'] if branch else '')} • {(service['name'] if service else '')}".strip()
        conn.execute(
            """
            INSERT INTO notifications(notificationId,userPhone,title,subtitle,type,relatedBookingId,isRead,createdAt)
            VALUES(?,?,?,?,?,?,?,?)
            """,
            (nid, None, n.title, subtitle, n.type, n.relatedBookingId, 0, now_iso()),
        )
        return {"ok": True, "notificationId": nid}


@app.get("/customer/notifications")
def list_notifications(userPhone: Optional[str] = None):
    with tx() as conn:
        if userPhone:
            rows = conn.execute(
                "SELECT * FROM notifications WHERE userPhone=? OR userPhone IS NULL ORDER BY createdAt DESC LIMIT 200",
                (userPhone,),
            ).fetchall()
        else:
            rows = conn.execute("SELECT * FROM notifications ORDER BY createdAt DESC LIMIT 200").fetchall()
        return [dict(r) | {"isRead": bool(r["isRead"])} for r in rows]


@app.delete("/admin/notifications/staff-broadcast")
def admin_clear_staff_broadcast_notifications():
    """
    Clear all staff broadcast notifications (userPhone NULL, type staff_broadcast).
    """
    with tx() as conn:
        conn.execute(
            "DELETE FROM notifications WHERE userPhone IS NULL AND type='staff_broadcast'"
        )
    return {"ok": True}

