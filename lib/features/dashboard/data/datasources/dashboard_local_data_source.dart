import '../../domain/entities/dashboard.dart';
import '../models/dashboard_model.dart';

class DashboardLocalDataSource {
  Future<DashboardModel> getDashboard() async {
    return const DashboardModel(
      resident: Resident(
        name: 'Alex Johnson',
        role: 'Owner',
        unitLabel: 'Tower A · 1205',
        initials: 'AJ',
      ),
      unit: UnitSummary(
        tower: 'Tower A',
        unit: '1205',
        floor: '12th floor',
        type: '2 bedroom',
        area: '86 m²',
        bedrooms: 2,
        bathrooms: 2,
        ownership: 'Owner',
        occupancy: 'Occupied',
        parkingSlot: 'B2-125',
      ),
      balance: BalanceSummary(
        outstanding: 462.40,
        dueDate: 'Sep 30, 2026',
        lastPayment: 238.10,
        lastPaymentDate: 'Sep 01, 2026',
        paidThisYear: 1192.30,
        paidYear: 2026,
      ),
      maintenance: [
        MaintenanceRequestSummary(
          title: 'Leaking kitchen sink',
          category: 'Plumbing',
          priority: 'High priority',
          status: 'In Progress',
        ),
        MaintenanceRequestSummary(
          title: 'AC not cooling',
          category: 'Air Conditioning',
          priority: 'Medium priority',
          status: 'Completed',
        ),
      ],
      inProgressMaintenance: 1,
      completedMaintenance: 2,
      reservations: [
        ReservationSummary(
          facility: 'Gym',
          date: 'Sep 24',
          time: '6:00 PM',
          status: 'Confirmed',
        ),
        ReservationSummary(
          facility: 'BBQ Area',
          date: 'Sep 27',
          time: '5:00 PM',
          status: 'Upcoming',
        ),
      ],
      announcements: [
        AnnouncementSummary(
          category: 'Emergency',
          title: 'Elevator 2 maintenance',
          description: 'Elevator 2 will be out of service tomorrow from 9–11 AM for its annual safety inspection.',
          date: 'Sep 22, 2026',
          isUrgent: true,
        ),
        AnnouncementSummary(
          category: 'Community',
          title: 'Rooftop BBQ weekend',
          description: 'Join your neighbours at the rooftop terrace this Saturday from 5 PM.',
          date: 'Sep 20, 2026',
          isUrgent: false,
        ),
        AnnouncementSummary(
          category: 'Security',
          title: 'Visitor access codes at the lobby',
          description:
              'Register a visitor and share their alphanumeric access code for a smoother lobby arrival.',
          date: 'Sep 18, 2026',
          isUrgent: false,
        ),
      ],
    );
  }
}
