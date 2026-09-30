import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/maintenance_request.dart';
import '../models/maintenance_request_model.dart';

class MaintenanceLocalDataSource {
  MaintenanceLocalDataSource()
    : _requests = List<MaintenanceRequestModel>.of(_initialRequests);

  final List<MaintenanceRequestModel> _requests;

  static final List<MaintenanceRequestModel> _initialRequests = [
    const MaintenanceRequestModel(
      id: 'maintenance-001',
      title: 'Leaking kitchen sink',
      category: MaintenanceCategory.plumbing,
      description: 'The pipe below the kitchen sink is dripping continuously.',
      location: 'Kitchen',
      priority: MaintenancePriority.high,
      status: MaintenanceStatus.inProgress,
      createdAt: 'Sep 20, 2026',
      preferredDate: 'Sep 26, 2026',
      preferredTime: '10:00 AM',
      photoNames: ['kitchen-sink.jpg'],
      technician: 'Carlos M.',
    ),
    const MaintenanceRequestModel(
      id: 'maintenance-002',
      title: 'AC not cooling',
      category: MaintenanceCategory.airConditioning,
      description:
          'The living room air conditioner is running but not cooling.',
      location: 'Living room',
      priority: MaintenancePriority.medium,
      status: MaintenanceStatus.completed,
      createdAt: 'Sep 12, 2026',
      preferredDate: 'Sep 14, 2026',
      preferredTime: '2:00 PM',
      photoNames: [],
      technician: 'Priya S.',
    ),
    const MaintenanceRequestModel(
      id: 'maintenance-003',
      title: 'Bedroom window seal',
      category: MaintenanceCategory.commonArea,
      description: 'The bedroom window seal has separated from the frame.',
      location: 'Bedroom',
      priority: MaintenancePriority.low,
      status: MaintenanceStatus.completed,
      createdAt: 'Sep 05, 2026',
      preferredDate: 'Sep 08, 2026',
      preferredTime: '11:00 AM',
      photoNames: [],
      technician: 'Carlos M.',
    ),
    const MaintenanceRequestModel(
      id: 'maintenance-004',
      title: 'Hallway light flickering',
      category: MaintenanceCategory.electrical,
      description: 'The hallway light outside the unit flickers at night.',
      location: 'Hallway',
      priority: MaintenancePriority.medium,
      status: MaintenanceStatus.assigned,
      createdAt: 'Sep 22, 2026',
      preferredDate: 'Sep 27, 2026',
      preferredTime: '9:00 AM',
      photoNames: [],
      technician: 'Maya R.',
    ),
  ];

  Future<List<MaintenanceRequestModel>> getRequests() async {
    return List<MaintenanceRequestModel>.unmodifiable(_requests);
  }

  Future<MaintenanceRequestModel> createRequest(
    MaintenanceRequest request,
  ) async {
    final created = MaintenanceRequestModel(
      id: 'maintenance-${DateTime.now().microsecondsSinceEpoch}',
      title: request.title,
      category: request.category,
      description: request.description,
      location: request.location,
      priority: request.priority,
      status: MaintenanceStatus.submitted,
      createdAt: 'Sep 25, 2026',
      preferredDate: request.preferredDate,
      preferredTime: request.preferredTime,
      photoNames: List<String>.unmodifiable(request.photoNames),
      photoPaths: List<String>.unmodifiable(request.photoPaths),
    );
    _requests.insert(0, created);
    return created;
  }

  Future<MaintenanceRequestModel> updateStatus(
    String id,
    MaintenanceStatus status,
  ) async {
    final index = _requests.indexWhere((request) => request.id == id);
    if (index == -1) {
      throw const AppException('Maintenance request could not be found.');
    }
    final request = _requests[index];
    final updated = MaintenanceRequestModel(
      id: request.id,
      title: request.title,
      category: request.category,
      description: request.description,
      location: request.location,
      priority: request.priority,
      status: status,
      createdAt: request.createdAt,
      preferredDate: request.preferredDate,
      preferredTime: request.preferredTime,
      photoNames: request.photoNames,
      technician:
          request.technician ??
          (status == MaintenanceStatus.assigned ? 'Maintenance team' : null),
      photoPaths: request.photoPaths,
    );
    _requests[index] = updated;
    return updated;
  }
}
