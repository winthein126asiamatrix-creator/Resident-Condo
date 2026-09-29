import '../entities/visitor.dart';

abstract interface class VisitorRepository {
  Future<List<Visitor>> getVisitors();

  Future<Visitor?> getVisitor(String id);

  Future<Visitor?> findByAccessCode(String code);

  Future<Visitor> registerVisitor(Visitor visitor);

  Future<Visitor> checkIn(Visitor visitor);

  Future<Visitor> checkOut(Visitor visitor);

  Future<Visitor> cancelVisitor(Visitor visitor);
}
