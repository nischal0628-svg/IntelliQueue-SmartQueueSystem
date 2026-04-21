import json
import os
import tempfile
import unittest
import sqlite3

from fastapi.testclient import TestClient


class BackendSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.NamedTemporaryFile(delete=False)
        cls.tmp.close()
        os.environ["INTELLIQUEUE_DB_PATH"] = cls.tmp.name

        # Import after env var set so DB points to temp file.
        from backend.app.main import app  # noqa

        cls._client_cm = TestClient(app)
        cls.client = cls._client_cm.__enter__()

    @classmethod
    def tearDownClass(cls):
        try:
            cls._client_cm.__exit__(None, None, None)
        except Exception:
            pass
        try:
            os.unlink(cls.tmp.name)
        except Exception:
            pass

    def _post_json(self, path, payload):
        return self.client.post(path, json=payload)

    def setUp(self):
        # Ensure each test runs with a clean DB state.
        db_path = os.environ["INTELLIQUEUE_DB_PATH"]
        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            # Order matters because of FKs.
            for table in ["notifications", "feedback", "bookings", "staff_users", "counters", "services", "branches"]:
                try:
                    cur.execute(f"DELETE FROM {table};")
                except Exception:
                    pass
            conn.commit()
        finally:
            conn.close()

    def test_booking_creation(self):
        # seed branch/service/counter
        self._post_json("/admin/branches", {"branchId": "b1", "name": "Main", "address": "Local", "isActive": True})
        self._post_json(
            "/admin/services",
            {
                "serviceId": "s1",
                "branchId": "b1",
                "name": "Customer Service",
                "category": "Support",
                "defaultEtaMinutes": 10,
                "isActive": True,
            },
        )
        r = self._post_json(
            "/customer/bookings",
            {"userPhone": "9999999999", "branchId": "b1", "serviceId": "s1", "tokenType": "Normal"},
        )
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertIn("bookingId", body)
        self.assertTrue(body["tokenNumber"].startswith("A"))

    def test_priority_ordering(self):
        self._post_json("/admin/branches", {"branchId": "b1", "name": "Main", "address": "Local", "isActive": True})
        self._post_json(
            "/admin/services",
            {
                "serviceId": "s1",
                "branchId": "b1",
                "name": "Customer Service",
                "category": "Support",
                "defaultEtaMinutes": 10,
                "isActive": True,
            },
        )
        self._post_json(
            "/admin/counters",
            {
                "counterId": "c1",
                "counterName": "Counter 1",
                "branchId": "b1",
                "serviceId": "s1",
                "status": "active",
                "assignedStaffEmail": None,
            },
        )
        # create staff assigned to c1
        self._post_json(
            "/admin/staff",
            {
                "staffId": "st1",
                "name": "Ram",
                "email": "ram@gmail.com",
                "role": "counter_officer",
                "status": "active",
                "assignedCounterId": "c1",
                "password": "Ram@1234",
            },
        )

        # create bookings in mixed priority
        self._post_json("/customer/bookings", {"userPhone": "1", "branchId": "b1", "serviceId": "s1", "tokenType": "Normal"})
        self._post_json("/customer/bookings", {"userPhone": "2", "branchId": "b1", "serviceId": "s1", "tokenType": "VIP"})
        self._post_json("/customer/bookings", {"userPhone": "3", "branchId": "b1", "serviceId": "s1", "tokenType": "SeniorCitizen"})

        q = self.client.get("/customer/queue/b1/s1").json()
        self.assertEqual(q["waitingTokens"][0]["tokenType"], "SeniorCitizen")
        self.assertEqual(q["waitingTokens"][1]["tokenType"], "VIP")

        # call next v2 should serve SeniorCitizen
        r = self.client.post("/staff/call-next-v2", params={"staffId": "st1"})
        self.assertEqual(r.status_code, 200)
        q2 = self.client.get("/customer/queue/b1/s1").json()
        self.assertEqual(q2["nowServing"][0]["tokenType"], "SeniorCitizen")

    def test_staff_skip_cancel_validation(self):
        # Setup
        self._post_json("/admin/branches", {"branchId": "b1", "name": "Main", "address": "Local", "isActive": True})
        self._post_json(
            "/admin/services",
            {"serviceId": "s1", "branchId": "b1", "name": "Customer Service", "category": "Support", "defaultEtaMinutes": 10, "isActive": True},
        )
        self._post_json(
            "/admin/counters",
            {"counterId": "c1", "counterName": "Counter 1", "branchId": "b1", "serviceId": "s1", "status": "active", "assignedStaffEmail": None},
        )
        self._post_json(
            "/admin/staff",
            {"staffId": "st1", "name": "Ram", "email": "ram@gmail.com", "role": "counter_officer", "status": "active", "assignedCounterId": "c1", "password": "Ram@1234"},
        )

        b = self._post_json("/customer/bookings", {"userPhone": "9", "branchId": "b1", "serviceId": "s1", "tokenType": "Normal"}).json()
        bid = b["bookingId"]

        # skip should fail if not serving
        r = self._post_json("/staff/skip", {"staffId": "st1", "counterId": "c1", "branchId": "b1", "serviceId": "s1", "bookingId": bid})
        self.assertNotEqual(r.status_code, 200)

        # serve it then skip should succeed
        self.client.post("/staff/call-next-v2", params={"staffId": "st1"})
        r2 = self._post_json("/staff/skip", {"staffId": "st1", "counterId": "c1", "branchId": "b1", "serviceId": "s1", "bookingId": bid})
        self.assertEqual(r2.status_code, 200)

