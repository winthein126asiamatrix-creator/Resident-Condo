import 'package:flutter/widgets.dart';

extension SizedBoxSpacingX on num {
  SizedBox heightBox() => SizedBox(height: toDouble());

  SizedBox widthBox() => SizedBox(width: toDouble());
}
