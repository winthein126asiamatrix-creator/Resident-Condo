import '../entities/visitor.dart';
import '../repositories/visitor_repository.dart';

class VisitorUseCases {
  const VisitorUseCases(this.repository);

  final VisitorRepository repository;

  Future<List<Visitor>> getVisitors() => repository.getVisitors();

  Future<Visitor?> getVisitor(String id) => repository.getVisitor(id);

  Future<Visitor?> findByAccessCode(String code) =>
      repository.findByAccessCode(code);

  Future<Visitor> registerVisitor(Visitor visitor) =>
      repository.registerVisitor(visitor);

  Future<Visitor> checkIn(Visitor visitor) => repository.checkIn(visitor);

  Future<Visitor> checkOut(Visitor visitor) => repository.checkOut(visitor);

  Future<Visitor> cancelVisitor(Visitor visitor) =>
      repository.cancelVisitor(visitor);
}
