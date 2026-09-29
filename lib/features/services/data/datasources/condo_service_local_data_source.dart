import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/condo_service.dart';
import '../models/condo_service_model.dart';

/// Condo services (cleaning, laundry, pest control…) are a completely separate
/// workflow from maintenance / repair requests.
class CondoServiceLocalDataSource {
  CondoServiceLocalDataSource()
    : _services = List<CondoServiceModel>.of(_initialServices),
      _requests = List<ServiceRequestModel>.of(_initialRequests);

  final List<CondoServiceModel> _services;
  final List<ServiceRequestModel> _requests;

  static final List<CondoServiceModel> _initialServices = [
    const CondoServiceModel(
      id: 'service-cleaning',
      name: 'Deep cleaning',
      category: ServiceCategory.cleaning,
      description:
          'Full home deep clean including kitchen, bathrooms, windows and floors.',
      price: 55,
      unit: 'per visit',
      leadTimeDays: 2,
      provider: 'BrightHome Services',
    ),
    const CondoServiceModel(
      id: 'service-laundry',
      name: 'Laundry & ironing',
      category: ServiceCategory.laundry,
      description: 'Wash, dry and fold up to 10 kg of laundry per visit.',
      price: 22,
      unit: 'per 10 kg',
      leadTimeDays: 1,
      provider: 'FreshFold Laundry',
    ),
    const CondoServiceModel(
      id: 'service-pest',
      name: 'Pest control',
      category: ServiceCategory.pestControl,
      description: 'Targeted treatment for cockroaches, ants or mosquitoes.',
      price: 75,
      unit: 'per unit',
      leadTimeDays: 3,
      provider: 'ShieldCare Pest Management',
    ),
    const CondoServiceModel(
      id: 'service-waste',
      name: 'Bulky item disposal',
      category: ServiceCategory.waste,
      description: 'Collection and disposal of furniture or e-waste up to 3 items.',
      price: 40,
      unit: 'per collection',
      leadTimeDays: 4,
      provider: 'CityWaste Services',
    ),
    const CondoServiceModel(
      id: 'service-aircon',
      name: 'Aircon filter cleaning',
      category: ServiceCategory.aircon,
      description: 'Filter cleaning and coil check for up to two split units.',
      price: 60,
      unit: 'per 2 units',
      leadTimeDays: 2,
      provider: 'CoolBreeze Engineering',
    ),
    const CondoServiceModel(
      id: 'service-catering',
      name: 'Private catering',
      category: ServiceCategory.catering,
      description: 'In-unit catering for up to eight guests with setup and cleanup.',
      price: 120,
      unit: 'per booking',
      leadTimeDays: 5,
      provider: 'The Lobby Kitchen',
    ),
    const CondoServiceModel(
      id: 'service-moving',
      name: 'Moving help',
      category: ServiceCategory.moving,
      description: 'Two helpers and a trolley for a three hour moving slot.',
      price: 90,
      unit: 'per 3 hours',
      leadTimeDays: 7,
      provider: 'EasyMove Residents',
    ),
  ];

  static final List<ServiceRequestModel> _initialRequests = [
    const ServiceRequestModel(
      id: 'service-request-002',
      serviceId: 'service-aircon',
      serviceName: 'Aircon filter cleaning',
      category: ServiceCategory.aircon,
      scheduledDate: 'Sep 27, 2026',
      scheduledSlot: '9:00 AM – 11:00 AM',
      status: ServiceRequestStatus.scheduled,
      price: 60,
      requestedOn: 'Sep 23, 2026',
      provider: 'CoolBreeze Engineering',
      notes: 'Please focus on the living room and master bedroom units.',
    ),
    const ServiceRequestModel(
      id: 'service-request-001',
      serviceId: 'service-cleaning',
      serviceName: 'Deep cleaning',
      category: ServiceCategory.cleaning,
      scheduledDate: 'Sep 18, 2026',
      scheduledSlot: '1:00 PM – 4:00 PM',
      status: ServiceRequestStatus.completed,
      price: 55,
      requestedOn: 'Sep 15, 2026',
      provider: 'BrightHome Services',
      feedback: 'Great work, the kitchen looks brand new.',
      rating: 5,
    ),
  ];

  Future<List<CondoServiceModel>> getServices() async {
    return List<CondoServiceModel>.unmodifiable(_services);
  }

  Future<List<ServiceRequestModel>> getRequests() async {
    return List<ServiceRequestModel>.unmodifiable(_requests);
  }

  Future<ServiceRequestModel> createRequest(ServiceRequest request) async {
    final index = _services.indexWhere(
      (service) => service.id == request.serviceId,
    );
    if (index == -1) {
      throw const AppException('Service could not be found.');
    }
    final service = _services[index];
    if (request.scheduledDate.isEmpty) {
      throw const AppException('Choose a preferred date.');
    }
    final created = ServiceRequestModel(
      id: 'service-request-${DateTime.now().microsecondsSinceEpoch}',
      serviceId: service.id,
      serviceName: service.name,
      category: service.category,
      scheduledDate: request.scheduledDate,
      scheduledSlot: request.scheduledSlot,
      status: ServiceRequestStatus.requested,
      price: service.price,
      requestedOn: 'Sep 25, 2026',
      provider: service.provider,
      notes: request.notes,
    );
    _requests.insert(0, created);
    return created;
  }

  Future<ServiceRequestModel> updateStatus(
    ServiceRequest request,
    ServiceRequestStatus status,
  ) async {
    return _replace(request.copyWith(status: status));
  }

  Future<ServiceRequestModel> cancelRequest(ServiceRequest request) async {
    if (!request.canCancel) {
      throw const AppException(
        'This request can no longer be cancelled. Contact the concierge.',
      );
    }
    return _replace(request.copyWith(status: ServiceRequestStatus.cancelled));
  }

  Future<ServiceRequestModel> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  ) async {
    if (request.status != ServiceRequestStatus.completed) {
      throw const AppException('Only completed services can be rated.');
    }
    if (rating < 1 || rating > 5) {
      throw const AppException('Choose a rating between 1 and 5.');
    }
    return _replace(request.copyWith(rating: rating, feedback: feedback.trim()));
  }

  ServiceRequestModel _replace(ServiceRequest updated) {
    final index = _requests.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      throw const AppException('Service request could not be found.');
    }
    final model = ServiceRequestModel(
      id: updated.id,
      serviceId: updated.serviceId,
      serviceName: updated.serviceName,
      category: updated.category,
      scheduledDate: updated.scheduledDate,
      scheduledSlot: updated.scheduledSlot,
      status: updated.status,
      price: updated.price,
      requestedOn: updated.requestedOn,
      provider: updated.provider,
      notes: updated.notes,
      feedback: updated.feedback,
      rating: updated.rating,
    );
    _requests[index] = model;
    return model;
  }
}
