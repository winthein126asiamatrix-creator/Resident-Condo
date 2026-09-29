import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/usecases/complaint_usecases.dart';

class ComplaintController extends GetxController {
  ComplaintController(this.useCases);

  final ComplaintUseCases useCases;
  final complaints = <Complaint>[].obs;
  final selectedComplaint = Rxn<Complaint>();
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadComplaints();
  }

  int get openCount => complaints.where((complaint) => complaint.isOpen).length;

  List<Complaint> get openComplaints =>
      complaints.where((complaint) => complaint.isOpen).toList();

  List<Complaint> get closedComplaints =>
      complaints.where((complaint) => !complaint.isOpen).toList();

  Future<void> loadComplaints() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      complaints.assignAll(await useCases.getComplaints());
      final selected = selectedComplaint.value;
      if (selected != null) {
        selectedComplaint.value = _find(selected.id) ?? selected;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load your complaints.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectComplaint(Complaint complaint) {
    selectedComplaint.value = complaint;
    errorMessage.value = null;
  }

  Future<Complaint?> fileComplaint({
    required ComplaintCategory category,
    required String subject,
    required String description,
    required String location,
    required ComplaintPriority priority,
    required bool isAnonymous,
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final complaint = await useCases.fileComplaint(
        Complaint(
          id: 'local-complaint',
          reference: 'CMP-2026-000',
          category: category,
          subject: subject,
          description: description,
          location: location,
          priority: priority,
          status: ComplaintStatus.submitted,
          createdOn: 'Sep 25, 2026',
          updatedOn: 'Sep 25, 2026',
          comments: const [],
          isAnonymous: isAnonymous,
        ),
      );
      complaints.insert(0, complaint);
      selectedComplaint.value = complaint;
      return complaint;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to file the complaint.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Complaint?> withdraw(Complaint complaint) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.withdrawComplaint(complaint);
      _apply(updated);
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to withdraw the complaint.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Complaint?> addComment(Complaint complaint, String message) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.addComment(
        complaint,
        ComplaintComment(
          author: 'Alex Johnson',
          authorRole: 'Resident',
          message: message,
          postedOn: 'Sep 25, 2026',
        ),
      );
      _apply(updated);
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to send the message.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  void _apply(Complaint updated) {
    final index = complaints.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      complaints[index] = updated;
    }
    selectedComplaint.value = updated;
  }

  Complaint? _find(String id) {
    for (final complaint in complaints) {
      if (complaint.id == id) {
        return complaint;
      }
    }
    return null;
  }
}
