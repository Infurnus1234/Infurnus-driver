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
          padding: EdgeInsets.all(iconSize * 0.1),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: InfurnusTheme.primaryGreen.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: InfurnusTheme.primaryGreen.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/infurnus_logo.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.local_shipping_rounded,
                size: iconSize,
                color: InfurnusTheme.primaryGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'INFURNUS',
          style: TextStyle(
            color: InfurnusTheme.textDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
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
