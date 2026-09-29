import '../entities/complaint.dart';
import '../repositories/complaint_repository.dart';

class ComplaintUseCases {
  const ComplaintUseCases(this.repository);

  final ComplaintRepository repository;

  Future<List<Complaint>> getComplaints() => repository.getComplaints();

  Future<Complaint?> getComplaint(String id) => repository.getComplaint(id);

  Future<Complaint> fileComplaint(Complaint complaint) =>
      repository.fileComplaint(complaint);

  Future<Complaint> withdrawComplaint(Complaint complaint) =>
      repository.withdrawComplaint(complaint);

  Future<Complaint> addComment(Complaint complaint, ComplaintComment comment) =>
      repository.addComment(complaint, comment);
}
