import 'api_end_points.dart';
import 'dio_api_service.dart';

/// Reads and updates the signed-in resident's preferences through the shared
/// API client.
///
/// Updates are partial, so each method sends only the field the resident
/// actually changed. Authentication, refresh-and-retry, logging and error
/// translation all come from [DioApiService]; this class adds no client of its
/// own.
class UserPreferencesRemoteDataSource {
  const UserPreferencesRemoteDataSource(this._service);

  final DioApiService _service;

  /// Loads the backend preferences after a successful `/auth/me`.
  ///
  /// Returns an empty map for an unexpected response shape so a preference
  /// payload can never fail an otherwise successful sign-in.
  Future<Map<String, dynamic>> fetchPreferences() async {
    final response = await _service.get<dynamic>(ApiEndPoints.preferences);
    if (response is! Map) {
      return const <String, dynamic>{};
    }
    return response.map((key, value) => MapEntry(key.toString(), value));
  }

  /// Sends a `#RRGGBB` brand colour, never Flutter's ARGB integer.
  Future<void> updateThemeColor(String hexColor) async {
    await _service.patch<dynamic>(
      ApiEndPoints.preferences,
      data: <String, Object?>{'theme_color': hexColor},
    );
  }

  /// Sends only the new notification preference.
  Future<void> updateNotificationsEnabled(bool enabled) async {
    await _service.patch<dynamic>(
      ApiEndPoints.preferences,
      data: <String, Object?>{'notifications_enabled': enabled},
    );
  }
}
