import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/complaint.dart';

class ComplaintLocalDataSource {
  ComplaintLocalDataSource() : _complaints = List.of(_initialComplaints);

  final List<Complaint> _complaints;

  static final List<Complaint> _initialComplaints = [
    Complaint(
      id: 'complaint-002',
      reference: 'CMP-2026-018',
      category: ComplaintCategory.noise,
      subject: 'Late night noise from Tower B',
      description:
          'Loud music after midnight on Friday and Saturday is keeping our '
          'family awake. This has happened three times this month.',
      location: 'Tower B · Level 12',
      priority: ComplaintPriority.medium,
      status: ComplaintStatus.inReview,
      createdOn: 'Sep 20, 2026',
      updatedOn: 'Sep 22, 2026',
      assignedTo: 'Maya R. · Community manager',
      comments: const [
        ComplaintComment(
          author: 'Maya R.',
          authorRole: 'Community manager',
          message: 'Thank you for reporting this. We have spoken with the '
              'neighbour and logged a warning.',
          postedOn: 'Sep 22, 2026',
        ),
        ComplaintComment(
          author: 'Alex Johnson',
          authorRole: 'Resident',
          message: 'Thank you, the last weekend was much quieter.',
          postedOn: 'Sep 23, 2026',
        ),
      ],
    ),
    Complaint(
      id: 'complaint-001',
      reference: 'CMP-2026-012',
      category: ComplaintCategory.cleanliness,
      subject: 'Recycling bins overflowing',
      description:
          'The recycling corner on level 1 is overflowing and rubbish is left in '
          'the corridor.',
      location: 'Level 1 · Bin store',
      priority: ComplaintPriority.low,
      status: ComplaintStatus.resolved,
      createdOn: 'Sep 05, 2026',
      updatedOn: 'Sep 09, 2026',
      assignedTo: 'Facilities team',
      resolution: 'Collection frequency increased to twice daily.',
      comments: const [
        ComplaintComment(
          author: 'Facilities team',
          authorRole: 'Management',
          message: 'Collection frequency increased to twice daily and new '
              'signage installed.',
          postedOn: 'Sep 09, 2026',
        ),
      ],
    ),
  ];

  Future<List<Complaint>> getComplaints() async => List.unmodifiable(_complaints);

  Future<Complaint?> getComplaint(String id) async {
    for (final complaint in _complaints) {
      if (complaint.id == id) {
        return complaint;
      }
    }
    return null;
  }

  Future<Complaint> fileComplaint(Complaint complaint) async {
    if (complaint.subject.trim().length < 4) {
      throw const AppException('Add a short subject for the complaint.');
    }
    if (complaint.description.trim().length < 10) {
      throw const AppException('Describe the issue in a little more detail.');
    }
    final created = Complaint(
      id: 'complaint-${DateTime.now().microsecondsSinceEpoch}',
      reference: 'CMP-2026-${(19 + _complaints.length).toString().padLeft(3, '0')}',
      category: complaint.category,
      subject: complaint.subject.trim(),
      description: complaint.description.trim(),
      location: complaint.location.trim(),
      priority: complaint.priority,
      status: ComplaintStatus.submitted,
      createdOn: 'Sep 25, 2026',
      updatedOn: 'Sep 25, 2026',
      comments: const [],
      isAnonymous: complaint.isAnonymous,
    );
    _complaints.insert(0, created);
    return created;
  }

  Future<Complaint> withdrawComplaint(Complaint complaint) async {
    if (!complaint.canWithdraw) {
      throw const AppException(
        'This complaint is already being handled and cannot be withdrawn.',
      );
    }
    return _replace(
      complaint.copyWith(
        status: ComplaintStatus.withdrawn,
        updatedOn: 'Sep 25, 2026',
      ),
    );
  }

  Future<Complaint> addComment(Complaint complaint, ComplaintComment comment) async {
    if (comment.message.trim().isEmpty) {
      throw const AppException('Write a message before sending.');
    }
    if (!complaint.isOpen) {
      throw const AppException('This complaint is closed.');
    }
    return _replace(
      complaint.copyWith(
        updatedOn: comment.postedOn,
        comments: List<ComplaintComment>.unmodifiable([
          ...complaint.comments,
          comment,
        ]),
      ),
    );
  }

  Complaint _replace(Complaint updated) {
    final index = _complaints.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      throw const AppException('Complaint could not be found.');
    }
    _complaints[index] = updated;
    return updated;
  }
}
