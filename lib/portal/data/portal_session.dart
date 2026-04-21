class PortalSession {
  final String staffId;
  final String email;
  final String name;
  final String role; // admin | supervisor | counter_officer
  final String? assignedCounterId;
  final String? assignedCounterName;
  final String? assignedServiceName;

  const PortalSession({
    required this.staffId,
    required this.email,
    required this.name,
    required this.role,
    this.assignedCounterId,
    this.assignedCounterName,
    this.assignedServiceName,
  });

  bool get isAdmin => role == 'admin';
}

