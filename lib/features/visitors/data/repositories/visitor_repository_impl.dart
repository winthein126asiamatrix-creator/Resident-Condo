import '../../domain/entities/visitor.dart';
import '../../domain/repositories/visitor_repository.dart';
import '../datasources/visitor_local_data_source.dart';

class VisitorRepositoryImpl implements VisitorRepository {
  const VisitorRepositoryImpl(this.localDataSource);

  final VisitorLocalDataSource localDataSource;

  @override
  Future<List<Visitor>> getVisitors() async {
    final visitors = await localDataSource.getVisitors();
    return List<Visitor>.of(visitors);
  }

  @override
  Future<Visitor?> getVisitor(String id) => localDataSource.getVisitor(id);

  @override
  Future<Visitor?> findByAccessCode(String code) =>
      localDataSource.findByAccessCode(code);

  @override
  Future<Visitor> registerVisitor(Visitor visitor) =>
      localDataSource.registerVisitor(visitor);

  @override
  Future<Visitor> checkIn(Visitor visitor) => localDataSource.checkIn(visitor);

  @override
  Future<Visitor> checkOut(Visitor visitor) =>
      localDataSource.checkOut(visitor);

  @override
  Future<Visitor> cancelVisitor(Visitor visitor) =>
      localDataSource.cancelVisitor(visitor);
}
