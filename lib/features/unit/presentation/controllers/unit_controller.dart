import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../features/session/presentation/controllers/session_controller.dart';
import '../../data/datasources/unit_local_data_source.dart';
import '../../domain/entities/unit.dart';
import '../../domain/usecases/unit_usecases.dart';

class UnitController extends GetxController {
  UnitController(
    this.useCases, {
    UnitLocalDataSource? cache,
    SessionController? sessionController,
  })  : _cache = cache,
        _sessionController = sessionController;

  final UnitUseCases useCases;
  final UnitLocalDataSource? _cache;
  final SessionController? _sessionController;

  final unit = Rxn<Unit>();
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = RxnString();
  final hasLoaded = false.obs;

  Future<Unit?>? _inFlight;
  int _requestSeq = 0;
  int? _ownerUserId;

  Unit? get myUnit => unit.value;
  Rxn<Unit> get myUnitRx => unit;

  SessionController? get _session =>
      _sessionController ??
      (Get.isRegistered<SessionController>()
          ? Get.find<SessionController>()
          : null);

  int? get _currentUserId => _session?.currentUser?.id;

  Future<Unit?> prefetch() async {
    final userId = _currentUserId;
    if (userId == null) return unit.value;
    if (unit.value != null && _ownerUserId == userId) return unit.value;
    if (_inFlight != null) return _inFlight;
    return loadMyUnit();
  }

  Future<Unit?> loadMyUnit({bool force = false}) async {
    if (_inFlight != null) return _inFlight;
    final userId = _currentUserId;
    final seq = ++_requestSeq;
    final future = _run(seq, userId, force);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<Unit?> _run(int seq, int? userId, bool force) async {
    try {
      if (!force && unit.value == null) {
        final cached = await _cache?.read(userId);
        if (cached != null && seq == _requestSeq) {
          unit.value = cached;
        }
      }
      if (seq != _requestSeq) return unit.value;
      final hasData = unit.value != null;
      if (hasData) {
        isRefreshing.value = true;
      } else {
        isLoading.value = true;
      }
      errorMessage.value = null;

      final data = await useCases.getMyUnit();
      if (seq != _requestSeq) return unit.value;
      if (userId != _currentUserId) return unit.value;
      unit.value = data;
      _ownerUserId = userId;
      hasLoaded.value = true;
      errorMessage.value = null;
      await _cache?.save(userId, data);
      return data;
    } on AppException catch (error) {
      if (seq != _requestSeq) return unit.value;
      if (userId != _currentUserId) return unit.value;
      errorMessage.value = error.message;
      return unit.value;
    } catch (_) {
      if (seq != _requestSeq) return unit.value;
      if (userId != _currentUserId) return unit.value;
      errorMessage.value = unit.value == null
          ? 'Unable to load your unit information.'
          : 'Unable to refresh your unit information.';
      return unit.value;
    } finally {
      if (seq == _requestSeq) {
        isLoading.value = false;
        isRefreshing.value = false;
      }
    }
  }

  Future<void> refresh() async {
    await loadMyUnit(force: true);
  }

  void clear() {
    _requestSeq++;
    _inFlight = null;
    unit.value = null;
    errorMessage.value = null;
    isLoading.value = false;
    isRefreshing.value = false;
    hasLoaded.value = false;
    _ownerUserId = null;
    _cache?.clear();
  }
}
