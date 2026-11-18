import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/condo_config.dart';

class ConfigRemoteDataSource {
  const ConfigRemoteDataSource(this._service);

  final DioApiService _service;

  Future<AppConfig> fetchAppConfig() {
    return _service.get<AppConfig>(
      ApiEndPoints.appConfig,
      parse: AppConfig.parse,
    );
  }

  Future<CondoConfig> fetchCondoConfig() {
    return _service.get<CondoConfig>(
      ApiEndPoints.condoConfig,
      parse: CondoConfig.parse,
    );
  }
}
