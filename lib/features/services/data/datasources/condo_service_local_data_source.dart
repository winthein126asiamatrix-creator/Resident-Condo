import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/condo_service.dart';
import '../models/condo_service_model.dart';

class CondoServiceLocalDataSource {
  CondoServiceLocalDataSource()
    : _services = List<CondoServiceModel>.of(_initialServices),
      _requests = List<ServiceRequestModel>.of(_initialRequests);

  final List<CondoServiceModel> _services;
  final List<ServiceRequestModel> _requests;

  static final List<CondoServiceModel> _initialServices = [
    const CondoServiceModel(
      id: 1,
      category: ServiceCategory.aircon,
      name: 'AC Cleaning',
      providerName: 'BrightHome Services',
      description: 'Professional AC cleaning service.',
      pricing: ServicePricing(
        type: ServicePricingType.perUnit,
        price: 30000,
        unit: 'AC',
        currency: 'MMK',
      ),
      estimatedDurationMinutes: 60,
      bookingFields: [
        ServiceBookingField(
          key: 'ac_quantity',
          label: 'Number of AC Units',
          type: ServiceBookingFieldType.quantity,
          required: true,
          min: 1,
          max: 5,
        ),
      ],
      availableDates: [
        ServiceAvailableDate(
          date: '2026-11-07',
          slots: [
            ServiceTimeSlot(
              id: 101,
              startTime: '09:00',
              endTime: '11:00',
              status: 'available',
            ),
            ServiceTimeSlot(
              id: 102,
              startTime: '13:00',
              endTime: '15:00',
              status: 'available',
            ),
          ],
        ),
         ServiceAvailableDate(
          date: '2026-11-08',
          slots: [
            ServiceTimeSlot(
              id: 103,
              startTime: '09:00',
              endTime: '11:00',
              status: 'available',
            ),
            ServiceTimeSlot(
              id: 104,
              startTime: '13:00',
              endTime: '18:00',
              status: 'available',
            ),
          ],
        ),
        ServiceAvailableDate(
          date: '2026-11-09',
          slots: [
            ServiceTimeSlot(
              id: 103,
              startTime: '09:00',
              endTime: '11:00',
              status: 'available',
            ),
            ServiceTimeSlot(
              id: 104,
              startTime: '14:00',
              endTime: '19:00',
              status: 'available',
            ),
          ],
        ),
      ],
      isActive: true,
    ),
    const CondoServiceModel(
      id: 2,
      category: ServiceCategory.cleaning,
      name: 'Home Cleaning',
      providerName: 'BrightHome Services',
      description: 'Full home deep clean including kitchen and bathrooms.',
      pricing: ServicePricing(
        type: ServicePricingType.fixed,
        price: 55,
        currency: 'MMK',
      ),
      estimatedDurationMinutes: 240,
      bookingFields: [
        ServiceBookingField(
          key: 'bedrooms',
          label: 'Bedrooms',
          type: ServiceBookingFieldType.quantity,
          required: true,
          min: 1,
          max: 6,
        ),
        ServiceBookingField(
          key: 'bathrooms',
          label: 'Bathrooms',
          type: ServiceBookingFieldType.quantity,
          required: true,
          min: 1,
          max: 4,
        ),
      ],
      availableDates: [
        ServiceAvailableDate(
          date: '2026-11-08',
          slots: [
            ServiceTimeSlot(
              id: 201,
              startTime: '10:00',
              endTime: '12:00',
              status: 'available',
            ),
          ],
        ),
      ],
      isActive: true,
    ),
    const CondoServiceModel(
      id: 3,
      category: ServiceCategory.laundry,
      name: 'Laundry Service',
      providerName: 'FreshFold Laundry',
      description: 'Wash, dry and fold laundry.',
      pricing: ServicePricing(
        type: ServicePricingType.perUnit,
        price: 22,
        unit: '10 kg',
        currency: 'MMK',
      ),
      estimatedDurationMinutes: 120,
      bookingFields: [
        ServiceBookingField(
          key: 'laundry_weight',
          label: 'Laundry weight',
          type: ServiceBookingFieldType.quantity,
          required: true,
          min: 1,
          max: 20,
        ),
      ],
      availableDates: [],
      isActive: true,
    ),
    const CondoServiceModel(
      id: 4,
      category: ServiceCategory.moving,
      name: 'Moving Help',
      providerName: 'EasyMove Residents',
      description: 'Two helpers and a trolley for a moving slot.',
      pricing: ServicePricing(
        type: ServicePricingType.quote,
        currency: 'MMK',
      ),
      estimatedDurationMinutes: 180,
      bookingFields: [
        ServiceBookingField(
          key: 'moving_details',
          label: 'Moving details',
          type: ServiceBookingFieldType.text,
          required: true,
        ),
      ],
      availableDates: [],
      isActive: true,
    ),
    const CondoServiceModel(
      id: 5,
      category: ServiceCategory.pestControl,
      name: 'Pest Control',
      providerName: 'ShieldCare Pest Management',
      description: 'Targeted treatment for pests.',
      pricing: ServicePricing(
        type: ServicePricingType.fixed,
        price: 75,
        currency: 'MMK',
      ),
      estimatedDurationMinutes: 90,
      bookingFields: [],
      availableDates: [],
      isActive: true,
    ),
  ];

  static final List<ServiceRequestModel> _initialRequests = [];

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
      slotId: request.slotId,
      bookingDetails: request.bookingDetails,
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
    return _replace(
      request.copyWith(rating: rating, feedback: feedback.trim()),
    );
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
      slotId: updated.slotId,
      bookingDetails: updated.bookingDetails,
    );
    _requests[index] = model;
    return model;
  }
}
