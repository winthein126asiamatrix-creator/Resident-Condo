import '../../domain/entities/unit.dart';
import '../models/unit_model.dart';

class UnitLocalDataSource {
  Future<UnitModel> getMyUnit() async {
    return const UnitModel(
      tower: 'Tower A',
      unitNumber: '1205',
      floor: '12th floor',
      unitType: '2 bedroom',
      area: '86 m²',
      bedrooms: 2,
      bathrooms: 2,
      ownershipStatus: 'Owner',
      occupancyStatus: 'Occupied',
      owner: UnitPerson(name: 'Alex Johnson', role: 'Owner', initials: 'AJ'),
      residents: [
        UnitPerson(name: 'Alex Johnson', role: 'Resident', initials: 'AJ'),
        UnitPerson(name: 'Sarah Johnson', role: 'Resident', initials: 'SJ'),
      ],
      tenant: UnitPerson(
        name: 'Jamie Rivera',
        role: 'Tenant',
        initials: 'JR',
      ),
      parking: ParkingInfo(
        slot: 'B2-125',
        vehicle: 'Toyota Camry',
        licensePlate: 'ABC-1234',
      ),
    );
  }
}
