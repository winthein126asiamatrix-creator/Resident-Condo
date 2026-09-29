import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/visitor.dart';
import '../../domain/usecases/visitor_usecases.dart';

enum VisitorFilter { upcoming, checkedIn, history }

extension VisitorFilterLabel on VisitorFilter {
  String get label {
    switch (this) {
      case VisitorFilter.upcoming:
        return 'Pre-registered';
      case VisitorFilter.checkedIn:
        return 'On site';
      case VisitorFilter.history:
        return 'History';
    }
  }
}

class VisitorController extends GetxController {
  VisitorController(this.useCases);

  final VisitorUseCases useCases;
  final visitors = <Visitor>[].obs;
  final selectedVisitor = Rxn<Visitor>();
  final filter = VisitorFilter.upcoming.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  final verificationCode = ''.obs;
  final verification = Rxn<VisitorVerification>();
  final isVerifying = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadVisitors();
  }

  int get activeCount =>
      visitors.where((visitor) => visitor.status.isActive).length;

  int get onSiteCount => visitors
      .where((visitor) => visitor.status == VisitorStatus.checkedIn)
      .length;

  List<Visitor> get visibleVisitors {
    switch (filter.value) {
      case VisitorFilter.upcoming:
        return visitors
            .where((visitor) => visitor.status == VisitorStatus.preRegistered)
            .toList();
      case VisitorFilter.checkedIn:
        return visitors
            .where((visitor) => visitor.status == VisitorStatus.checkedIn)
            .toList();
      case VisitorFilter.history:
        return visitors
            .where(
              (visitor) =>
                  visitor.status == VisitorStatus.checkedOut ||
                  visitor.status == VisitorStatus.cancelled ||
                  visitor.status == VisitorStatus.expired,
            )
            .toList();
    }
  }

  int countFor(VisitorFilter value) {
    switch (value) {
      case VisitorFilter.upcoming:
        return visitors
            .where((visitor) => visitor.status == VisitorStatus.preRegistered)
            .length;
      case VisitorFilter.checkedIn:
        return visitors
            .where((visitor) => visitor.status == VisitorStatus.checkedIn)
            .length;
      case VisitorFilter.history:
        return visitors
            .where(
              (visitor) =>
                  visitor.status == VisitorStatus.checkedOut ||
                  visitor.status == VisitorStatus.cancelled ||
                  visitor.status == VisitorStatus.expired,
            )
            .length;
    }
  }

  Future<void> loadVisitors() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      visitors.assignAll(await useCases.getVisitors());
      final selected = selectedVisitor.value;
      if (selected != null) {
        selectedVisitor.value = _find(selected.id) ?? selected;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load visitor records.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectFilter(VisitorFilter value) {
    filter.value = value;
  }

  void selectVisitor(Visitor visitor) {
    selectedVisitor.value = visitor;
    errorMessage.value = null;
  }

  Future<Visitor?> registerVisitor({
    required String name,
    required String phone,
    required VisitorRelation relation,
    required String purpose,
    required String date,
    required String arrivalWindow,
    String? vehiclePlate,
    String notes = '',
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final visitor = await useCases.registerVisitor(
        Visitor(
          id: 'local-visitor',
          name: name,
          phone: phone,
          relation: relation,
          purpose: purpose,
          date: date,
          arrivalWindow: arrivalWindow,
          status: VisitorStatus.preRegistered,
          accessCode: '',
          registeredBy: 'Alex Johnson',
          registeredOn: 'Sep 25, 2026',
          vehiclePlate: vehiclePlate,
          notes: notes,
        ),
      );
      visitors.insert(0, visitor);
      filter.value = VisitorFilter.upcoming;
      return visitor;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to register the visitor.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Visitor?> checkIn(Visitor visitor) => _run(
    visitor,
    () => useCases.checkIn(visitor),
    'checked in',
  );

  Future<Visitor?> checkOut(Visitor visitor) => _run(
    visitor,
    () => useCases.checkOut(visitor),
    'checked out',
  );

  Future<Visitor?> cancelVisitor(Visitor visitor) => _run(
    visitor,
    () => useCases.cancelVisitor(visitor),
    'cancelled',
  );

  void onVerificationChanged(String value) {
    verificationCode.value = value;
    if (_lastVerifiedCode.isNotEmpty && value.trim() != _lastVerifiedCode) {
      verification.value = null;
    }
  }

  String _lastVerifiedCode = '';

  Future<VisitorVerification?> verifyCode() async {
    final code = verificationCode.value.trim();
    if (code.isEmpty) {
      errorMessage.value = 'Enter the access code given by the visitor.';
      return null;
    }
    isVerifying.value = true;
    errorMessage.value = null;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final visitor = await useCases.findByAccessCode(code);
      _lastVerifiedCode = code;
      final result = visitor == null
          ? const VisitorVerification(
              isValid: false,
              message: 'No visitor matches that access code. Ask the visitor to '
                  'check the code in their message.',
            )
          : visitor.status == VisitorStatus.cancelled
          ? VisitorVerification(
              isValid: false,
              message: 'This pass was cancelled and cannot be used.',
              visitor: visitor,
            )
          : visitor.status == VisitorStatus.checkedOut
          ? VisitorVerification(
              isValid: false,
              message: 'This visitor already checked out at '
                  '${visitor.checkedOutAt ?? 'an earlier time'}.',
              visitor: visitor,
            )
          : VisitorVerification(
              isValid: true,
              message: visitor.status == VisitorStatus.checkedIn
                  ? 'Visitor is currently on site.'
                  : 'Access code verified. Ready to check in.',
              visitor: visitor,
            );
      verification.value = result;
      if (visitor != null) {
        selectedVisitor.value = visitor;
      }
      return result;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to verify the access code.';
      return null;
    } finally {
      isVerifying.value = false;
    }
  }

  void clearVerification() {
    verification.value = null;
    verificationCode.value = '';
    _lastVerifiedCode = '';
  }

  Future<Visitor?> _run(
    Visitor visitor,
    Future<Visitor> Function() action,
    String outcome,
  ) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await action();
      final index = visitors.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        visitors[index] = updated;
      }
      selectedVisitor.value = updated;
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Visitor could not be $outcome.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Visitor? _find(String id) {
    for (final visitor in visitors) {
      if (visitor.id == id) {
        return visitor;
      }
    }
    return null;
  }
}
