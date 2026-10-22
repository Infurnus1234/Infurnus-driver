import 'onboarding_rules.dart';
import 'provider_status.dart';
import '../providers/driver_session.dart';

enum RequirementState {
  missing,
  uploaded,
  pending,
  approved,
  rejected,
  expired,
}

class JourneyTask {
  final String id, title, explanation;
  final DocumentRule? rule;
  const JourneyTask(this.id, this.title, this.explanation, {this.rule});
}

abstract final class OnboardingJourney {
  static bool vehicleCode(String code) =>
      code.startsWith('vehicle_') ||
      ['insurance', 'permit', 'fitness', 'rc'].contains(code);
  static RequirementState state(Map<String, dynamic>? document) {
    if (document == null) return RequirementState.missing;
    if (OnboardingRules.expired(document)) return RequirementState.expired;
    return switch (providerStatus(document['verificationStatus'])) {
      ProviderStatus.approved => RequirementState.approved,
      ProviderStatus.rejected ||
      ProviderStatus.changesRequested => RequirementState.rejected,
      ProviderStatus.pending ||
      ProviderStatus.submitted ||
      ProviderStatus.underReview => RequirementState.pending,
      ProviderStatus.expired => RequirementState.expired,
      _ => RequirementState.uploaded,
    };
  }

  static String label(RequirementState state) => switch (state) {
    RequirementState.missing => 'Not uploaded',
    RequirementState.uploaded => 'Uploaded',
    RequirementState.pending => 'Pending review',
    RequirementState.approved => 'Approved',
    RequirementState.rejected => 'Correction required',
    RequirementState.expired => 'Expired — replace document',
  };
  static List<JourneyTask> tasks(DriverSession session) {
    final rules = {
      for (final r in session.documentRules.where((r) => r.required)) r.code: r,
    };
    final licence = JourneyTask(
      'licence',
      'Your driving licence',
      'Add your licence photo, number and expiry together. Your licence remains subject to review.',
      rule:
          rules.remove('driver_license') ??
          const DocumentRule('driver_license', required: true),
    );
    final photo = JourneyTask(
      'profile_photo',
      'Your profile photo',
      'Use a clear, recent photo with your face visible. Uploading does not approve your identity.',
      rule:
          rules.remove('profile_photo') ?? const DocumentRule('profile_photo'),
    );
    return [
      // A new driver needs a real profile before any document upload.
      if (session.profile == null) licence,
      photo,
      if (session.profile != null) licence,
      const JourneyTask(
        'vehicle',
        'Connect your vehicle',
        'Use the assignment code provided by your fleet, or manage a vehicle you own. Assignment is confirmed by the server.',
      ),
      for (final r in rules.values.where((r) => vehicleCode(r.code)))
        JourneyTask(
          r.code,
          r.label,
          'Required for your vehicle category. Upload the current document.',
          rule: r,
        ),
      if (session.api.hasFleetRole)
        const JourneyTask(
          'fleet',
          'Your fleet business',
          'Review your business and owned vehicles using the existing provider verification service.',
        ),
      for (final r in rules.values.where((r) => !vehicleCode(r.code)))
        JourneyTask(
          r.code,
          r.label,
          'Required by your current document policy.',
          rule: r,
        ),
      const JourneyTask(
        'summary',
        'Ready for review',
        'Check your saved requirements and submit them for review. Only server approval permits driver operations.',
      ),
    ];
  }

  static bool satisfied(JourneyTask task, DriverSession s) {
    if (task.id == 'licence' &&
        (s.profile == null ||
            OnboardingRules.validateProfile(s.profile!) != null)) {
      return false;
    }
    if (task.rule != null) {
      final doc = s.requirementDocument(task.rule!.code);
      final status = state(doc);
      return doc != null &&
          status != RequirementState.rejected &&
          status != RequirementState.expired &&
          !s.missingUploads.any((r) => r.code == task.rule!.code);
    }
    return switch (task.id) {
      'setup' || 'licence' =>
        s.profile != null &&
            OnboardingRules.validateProfile(s.profile!) == null,
      'vehicle' => s.assignedVehicle != null,
      'fleet' => false,
      _ => false,
    };
  }

  static int resume(List<JourneyTask> tasks, DriverSession s) {
    for (var i = 0; i < tasks.length; i++) {
      if (!s.deferredSteps.contains(tasks[i].id) && !satisfied(tasks[i], s)) {
        return i;
      }
    }
    return tasks.length - 1;
  }
}
