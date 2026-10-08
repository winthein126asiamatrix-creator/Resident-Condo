import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../domain/entities/unit.dart';

class UnitPersonTile extends StatelessWidget {
  const UnitPersonTile({required this.person, super.key});

  final UnitPerson person;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: tokens.brandTint,
        child: Text(
          person.initials,
          style: TextStyle(
            color: tokens.brand,
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
