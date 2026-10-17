import 'package:flutter/material.dart';
import '../core/theme.dart';

class InfurnusLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showSubtitle;

  const InfurnusLogo({
    super.key,
    this.iconSize = 110,
    this.fontSize = 26,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/infurnus_logo.png',
      height: iconSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.local_shipping_rounded,
        size: iconSize,
        color: InfurnusTheme.primaryGreen,
      ),
    );
  }
}
