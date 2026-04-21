from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field


IsoDateTime = str


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    staffId: str
    email: str
    name: str
    role: str
    assignedCounterId: Optional[str] = None
    assignedCounterName: Optional[str] = None
    assignedServiceName: Optional[str] = None


class BranchIn(BaseModel):
    branchId: str
    name: str
    address: Optional[str] = None
    isActive: bool = True


class ServiceIn(BaseModel):
    serviceId: str
    branchId: str
    name: str
    category: Optional[str] = None
    defaultEtaMinutes: int = 15
    isActive: bool = True


class CounterIn(BaseModel):
    counterId: str
    counterName: str
    branchId: str
    serviceId: str
    status: Literal["active", "break", "inactive"] = "active"
    assignedStaffEmail: Optional[str] = None


class StaffUserIn(BaseModel):
    staffId: str
    name: str
    email: str
    role: Literal["counter_officer", "supervisor", "admin"]
    status: Literal["active", "break", "inactive"] = "active"
    assignedCounterId: Optional[str] = None
    password: str = Field(min_length=4)


class StaffUserOut(BaseModel):
    staffId: str
    name: str
    email: str
    role: str
    assignedCounterId: Optional[str] = None
    assignedCounterName: Optional[str] = None
    status: str
    createdAt: str
    updatedAt: Optional[str] = None


class BookingCreateIn(BaseModel):
    userPhone: str
    branchId: str
    serviceId: str
    tokenType: Literal["Normal", "VIP", "SeniorCitizen"] = "Normal"


class StaffActionIn(BaseModel):
    staffId: str
    counterId: str
    branchId: str
    serviceId: str


class StaffCallNowIn(StaffActionIn):
    bookingId: str


class StaffCancelIn(StaffActionIn):
    bookingId: str


class NotificationIn(BaseModel):
    title: str
    subtitle: Optional[str] = None
    type: str = "staff_broadcast"
    userPhone: Optional[str] = None
    relatedBookingId: Optional[str] = None


class StaffAssignCounterIn(BaseModel):
    staffId: str
    counterId: str


class CustomerSignupIn(BaseModel):
    userPhone: str
    name: Optional[str] = None
    email: Optional[str] = None
    password: str = Field(min_length=4)


class CustomerLoginIn(BaseModel):
    userPhone: str
    password: str


class CustomerOut(BaseModel):
    userPhone: str
    name: Optional[str] = None
    email: Optional[str] = None
    status: str
    createdAt: str
    updatedAt: Optional[str] = None


class AdminResetCustomerPasswordIn(BaseModel):
    userPhone: str
    newPassword: str = Field(min_length=4)

