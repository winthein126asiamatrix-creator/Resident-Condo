import 'package:flutter/material.dart';

import '../../domain/entities/unit.dart';

class UnitPersonTile extends StatelessWidget {
  const UnitPersonTile({required this.person, super.key});

  final UnitPerson person;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFE6F3EF),
        child: Text(
          person.initials,
          style: const TextStyle(
            color: Color(0xFF0F766E),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        person.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(person.role),
    );
  }
}
