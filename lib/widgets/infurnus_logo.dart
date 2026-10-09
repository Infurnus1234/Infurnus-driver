import 'package:flutter/material.dart';

import '../core/theme.dart';

class InfurnusLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showSubtitle;

  const InfurnusLogo({
    super.key,
    this.iconSize = 42,
    this.fontSize = 26,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(iconSize * 0.3),
          decoration: BoxDecoration(
            color: InfurnusTheme.primaryGreen,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: InfurnusTheme.primaryGreen.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'INFURNUS',
          style: TextStyle(
            color: InfurnusTheme.textDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 2),
          const Text(
            'LOGISTICS & FLEET PLATFORM',
            style: TextStyle(
              color: InfurnusTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
