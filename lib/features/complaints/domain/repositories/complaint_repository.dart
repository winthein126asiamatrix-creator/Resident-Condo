import '../entities/complaint.dart';

abstract interface class ComplaintRepository {
  Future<List<Complaint>> getComplaints();

  Future<Complaint?> getComplaint(String id);

  Future<Complaint> fileComplaint(Complaint complaint);

  Future<Complaint> withdrawComplaint(Complaint complaint);

  Future<Complaint> addComment(Complaint complaint, ComplaintComment comment);
}
