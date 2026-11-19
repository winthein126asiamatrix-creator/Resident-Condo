import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/semantic_version.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/usecases/config_usecases.dart';

enum UpdateRequirement { none, optional, mandatory }

class AppConfigController extends GetxController {
  AppConfigController(this.useCases);

  static const String _dismissedVersionKey = 'app.update.dismissed_version';

  final ConfigUseCases useCases;

  final config = Rxn<AppConfig>();
  final installedVersion = RxnString();
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final optionalUpdateDismissed = false.obs;

  Future<void>? _inFlight;
  bool _loaded = false;
  bool _versionLoaded = false;
  bool _dismissalLoaded = false;
  String? _dismissedVersion;

  AppVersionConfig? get versionConfig => config.value?.version;

  AppMaintenanceConfig? get maintenance => config.value?.maintenance;

  bool get maintenanceActive => maintenance?.enabled ?? false;

  bool get hasUpdateTarget => versionConfig?.hasUpdateTarget ?? false;

  UpdateRequirement get updateRequirement {
    final installed = installedVersion.value;
    final version = versionConfig;
    if (installed == null || version == null) {
      return UpdateRequirement.none;
    }
    final minSupported = version.minSupported;
    if (minSupported != null &&
        SemanticVersion.isLower(installed, minSupported)) {
      return UpdateRequirement.mandatory;
    }
    final latest = version.latest;
    if (latest != null && SemanticVersion.isLower(installed, latest)) {
      return UpdateRequirement.optional;
    }
    return UpdateRequirement.none;
  }

  bool get shouldShowOptionalUpdate =>
      updateRequirement == UpdateRequirement.optional &&
      !optionalUpdateDismissed.value;

  Future<void> load({bool force = false}) {
    final existing = _inFlight;
    if (existing != null) return existing;
    if (_loaded && !force) return Future<void>.value();
    final future = _run(force: force);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _run({required bool force}) async {
    isLoading.value = true;
    errorMessage.value = null;
    if (force) _versionLoaded = false;
    await _loadInstalledVersion();
    await _loadDismissal();
    if (!force && config.value == null) {
      final cached = await useCases.readCachedAppConfig();
      if (cached != null) {
        config.value = cached;
        _refreshDismissal();
      }
    }
    try {
      final fresh = await useCases.fetchAppConfig();
      config.value = fresh;
      _refreshDismissal();
      try {
        await useCases.cacheAppConfig(fresh);
      } on Object {
        // A local write failure must not discard a valid response.
      }
      errorMessage.value = null;
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load app configuration.';
    } finally {
      isLoading.value = false;
      _loaded = true;
    }
  }

  Future<void> _loadInstalledVersion() async {
    if (_versionLoaded) return;
    _versionLoaded = true;
    try {
      final info = await PackageInfo.fromPlatform();
      installedVersion.value = info.version;
    } catch (_) {
      // A test or unsupported platform has no package information.
    }
  }

  Future<void> _loadDismissal() async {
    if (_dismissalLoaded) return;
    _dismissalLoaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _dismissedVersion = preferences.getString(_dismissedVersionKey);
    } catch (_) {
      _dismissedVersion = null;
    }
    _refreshDismissal();
  }

  void _refreshDismissal() {
    final latest = versionConfig?.latest;
    optionalUpdateDismissed.value =
        latest != null && latest == _dismissedVersion;
  }

  Future<void> dismissOptionalUpdate() async {
    final latest = versionConfig?.latest;
    if (latest == null || latest.isEmpty) return;
    _dismissedVersion = latest;
    optionalUpdateDismissed.value = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_dismissedVersionKey, latest);
    } catch (_) {
      // The in-memory dismissal still applies for this session.
    }
  }

  Future<bool> openUpdateUrl() async {
    final raw = versionConfig?.updateUrl?.trim();
    if (raw == null || raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
