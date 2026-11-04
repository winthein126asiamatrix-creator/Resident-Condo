import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../models/my_unit_models.dart';

class UnitRemoteDataSource {
  const UnitRemoteDataSource(this._service);

  final DioApiService _service;

  Future<MyUnitResponse> getMyUnit() async {
    return _service.get<MyUnitResponse>(
      ApiEndPoints.myUnit,
      parse: MyUnitResponse.parse,
    );
  }
}
