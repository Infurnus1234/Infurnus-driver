import 'package:flutter/material.dart';

import '../core/operations_theme.dart';

/// Segmented progress bar inspired by Uber Driver onboarding.
class SegmentedProgressBar extends StatelessWidget {
  final int totalSegments;
  final int completedSegments;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final double spacing;

  const SegmentedProgressBar({
    super.key,
    required this.totalSegments,
    required this.completedSegments,
    this.activeColor = Ops.actionPrimary,
    this.inactiveColor = const Color(0xFFE2E8F0),
    this.height = 4.0,
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSegments <= 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(totalSegments, (index) {
        final isCompleted = index < completedSegments;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(
              right: index < totalSegments - 1 ? spacing : 0,
            ),
            decoration: BoxDecoration(
              color: isCompleted ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
      }),
    );
  }
}

/// Stylized sample Aadhaar card illustration matching visual reference.
class AadhaarCardGraphic extends StatelessWidget {
  final String? maskedNumber;
  const AadhaarCardGraphic({super.key, this.maskedNumber});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        height: 165,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Green Band
            Container(
              height: 24,
              width: double.infinity,
              color: const Color(0xFF22C55E),
              alignment: Alignment.center,
              child: const Text(
                'AADHAAR CARD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Govt of India header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.account_balance,
                          size: 16,
                          color: Color(0xFF334155),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'भारत सरकार',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'GOVERNMENT OF INDIA',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Middle: photo, lines, QR code
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF94A3B8),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _line(40),
                              const SizedBox(height: 4),
                              _line(70),
                              const SizedBox(height: 4),
                              _line(55),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.qr_code_2,
                            size: 28,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Masked Number in Green
                    Text(
                      maskedNumber ?? 'XXXX  XXXX  XXXX',
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(double width) => Container(
    width: width,
    height: 5,
    decoration: BoxDecoration(
      color: const Color(0xFFCBD5E1),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// Stylized sample Driving Licence card illustration matching visual reference with callouts.
class DrivingLicenceCardGraphic extends StatelessWidget {
  const DrivingLicenceCardGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 300,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Card Base
            Container(
              width: 280,
              height: 165,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: const [
                        Text(
                          'Transport Department Government',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Licence To Drive Vehicles Throughout India',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chip
                      Container(
                        width: 32,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37)
                              .withValues(alpha: 0.25),
                          border: Border.all(
                            color: const Color(0xFFCA8A04),
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.memory,
                          size: 16,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _line(60),
                            const SizedBox(height: 4),
                            _line(90),
                            const SizedBox(height: 4),
                            _line(50),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Photo
                      Container(
                        width: 44,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF94A3B8),
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line(80),
                          const SizedBox(height: 3),
                          _line(60),
                        ],
                      ),
                      const Text(
                        'Issuing Authority',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Floating Callout: Licence No
            Positioned(
              left: 10,
              top: 36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Licence No. : ',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'DL00 0000000000',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Floating Callout: Expiry / DOB
            Positioned(
              left: 60,
              top: 68,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'DOB / Expiry : YYYY-MM-DD',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(double width) => Container(
    width: width,
    height: 4.5,
    decoration: BoxDecoration(
      color: const Color(0xFFCBD5E1),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Dual upload box for Front side and Back side as seen in the reference screenshot.
class DualSideUploadArea extends StatelessWidget {
  final VoidCallback onUploadFront;
  final VoidCallback onUploadBack;
  final bool frontUploaded;
  final bool backUploaded;
  final bool disabled;

  const DualSideUploadArea({
    super.key,
    required this.onUploadFront,
    required this.onUploadBack,
    this.frontUploaded = false,
    this.backUploaded = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _UploadTile(
            label: frontUploaded ? 'Front side selected' : 'Upload front side',
            icon: frontUploaded
                ? Icons.check_circle_outline
                : Icons.file_upload_outlined,
            isCompleted: frontUploaded,
            disabled: disabled,
            onTap: onUploadFront,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _UploadTile(
            label: backUploaded ? 'Back side selected' : 'Upload back side',
            icon: backUploaded
                ? Icons.check_circle_outline
                : Icons.file_upload_outlined,
            isCompleted: backUploaded,
            disabled: disabled,
            onTap: onUploadBack,
          ),
        ),
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool disabled;
  final VoidCallback onTap;

  const _UploadTile({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCompleted
        ? Ops.actionPrimary
        : const Color(0xFF93C5FD);
    final bgColor = isCompleted
        ? const Color(0xFFECFDF5)
        : const Color(0xFFEFF6FF);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isCompleted ? 1.5 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isCompleted ? Ops.actionPrimary : const Color(0xFF2563EB),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCompleted
                    ? Ops.actionPrimary
                    : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean document checklist card inspired by Ola Driver Application Summary.
class DocumentChecklistCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? statusLabel;
  final Color? statusColor;
  final bool isCompleted;
  final VoidCallback? onTap;

  const DocumentChecklistCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusColor,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                if (isCompleted)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 20,
                  )
                else
                  Icon(icon, color: const Color(0xFF475569), size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
