/// Role of the signed-in resident. Drives the role based UI across the app.
///
/// In production this is derived from the Odoo partner / unit contract record.
enum ResidentRole { owner, tenant, resident }

extension ResidentRoleLabel on ResidentRole {
  String get label {
    switch (this) {
      case ResidentRole.owner:
        return 'Owner';
      case ResidentRole.tenant:
        return 'Tenant';
      case ResidentRole.resident:
        return 'Resident';
    }
  }

  String get description {
    switch (this) {
      case ResidentRole.owner:
        return 'Owns the unit and pays the monthly condo fee to management.';
      case ResidentRole.tenant:
        return 'Rents the unit and pays the monthly rent to the owner.';
      case ResidentRole.resident:
        return 'Lives in the unit with shared access to building services.';
    }
  }

  /// Owners manage the lease and see who lives in the unit.
  bool get managesLease => this == ResidentRole.owner;

  /// Tenants follow their own rent schedule and lease expiry.
  bool get paysRent => this == ResidentRole.tenant;
}
