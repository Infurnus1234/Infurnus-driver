import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../core/theme.dart';

class VerificationBadge extends StatelessWidget {
  final VerificationStatus status;

  const VerificationBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case VerificationStatus.approved:
        bg = InfurnusTheme.successGreen.withOpacity(0.15);
        fg = InfurnusTheme.successGreen;
        icon = Icons.check_circle_outline;
        break;
      case VerificationStatus.underReview:
      case VerificationStatus.documentsSubmitted:
        bg = InfurnusTheme.infoBlue.withOpacity(0.15);
        fg = InfurnusTheme.infoBlue;
        icon = Icons.hourglass_top_rounded;
        break;
      case VerificationStatus.changesRequired:
      case VerificationStatus.rejected:
        bg = InfurnusTheme.dangerRed.withOpacity(0.15);
        fg = InfurnusTheme.dangerRed;
        icon = Icons.error_outline_rounded;
        break;
      case VerificationStatus.draft:
      default:
        bg = InfurnusTheme.warningAmber.withOpacity(0.15);
        fg = InfurnusTheme.warningAmber;
        icon = Icons.edit_note_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
