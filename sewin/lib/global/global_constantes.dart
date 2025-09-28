import 'package:flutter/material.dart';

class Constants {
  static String serverapp = 'http://localhost:3500';

  // Text scaling factors
  static double getTextScaleFactor(BuildContext context, {double max = 1.5}) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1000) return 1.5;
    if (width > 800) return 1.3;
    if (width > 600) return 1.1;
    return 1.0;
  }
}

class TextScaleFactor {
  static double textScaleFactor(BuildContext context, {double max = 1.5}) {
    return Constants.getTextScaleFactor(context, max: max);
  }
}

extension StringExtension on String {
  String toSearchable() => toLowerCase().trim();
}
