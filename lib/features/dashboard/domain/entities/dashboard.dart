class UnitSummary {
  const UnitSummary({
    required this.tower,
    required this.unit,
    required this.floor,
    required this.type,
    required this.area,
    required this.bedrooms,
    required this.bathrooms,
    required this.ownership,
    required this.occupancy,
    required this.parkingSlot,
  });

  final String tower;
  final String unit;
  final String floor;
  final String type;
  final String area;
  final int bedrooms;
  final int bathrooms;
  final String ownership;
  final String occupancy;
  final String parkingSlot;
}

class BalanceSummary {
  const BalanceSummary({
    required this.outstanding,
    required this.dueDate,
    required this.lastPayment,
    required this.lastPaymentDate,
    required this.paidThisYear,
    required this.paidYear,
  });

  final double outstanding;
  final String dueDate;
  final double lastPayment;
  final String lastPaymentDate;
  final double paidThisYear;
  final int paidYear;
}

class ReservationSummary {
  const ReservationSummary({
    required this.facility,
    required this.date,
    required this.time,
    required this.status,
  });

  final String facility;
  final String date;
  final String time;
  final String status;
}

class AnnouncementSummary {
  const AnnouncementSummary({
    required this.category,
    required this.title,
    required this.description,
    required this.date,
    required this.isUrgent,
  });

  final String category;
  final String title;
  final String description;
  final String date;
  final bool isUrgent;
}

class DashboardData {
  const DashboardData({
    required this.unit,
    required this.balance,
    required this.reservations,
    required this.announcements,
  });

  final UnitSummary unit;
  final BalanceSummary balance;
  final List<ReservationSummary> reservations;
  final List<AnnouncementSummary> announcements;
}
