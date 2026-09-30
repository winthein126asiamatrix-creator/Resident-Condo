import '../../domain/entities/complaint.dart';
import '../../domain/repositories/complaint_repository.dart';
import '../datasources/complaint_local_data_source.dart';

class ComplaintRepositoryImpl implements ComplaintRepository {
  const ComplaintRepositoryImpl(this.localDataSource);

  final ComplaintLocalDataSource localDataSource;

  @override
  Future<List<Complaint>> getComplaints() => localDataSource.getComplaints();

  @override
  Future<Complaint?> getComplaint(String id) =>
      localDataSource.getComplaint(id);

  @override
  Future<Complaint> fileComplaint(Complaint complaint) =>
      localDataSource.fileComplaint(complaint);

  @override
  Future<Complaint> withdrawComplaint(Complaint complaint) =>
      localDataSource.withdrawComplaint(complaint);

  @override
  Future<Complaint> addComment(Complaint complaint, ComplaintComment comment) =>
      localDataSource.addComment(complaint, comment);
}
