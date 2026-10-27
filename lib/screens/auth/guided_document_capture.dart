import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/onboarding_rules.dart';
import '../../services/api_service.dart';
import '../../widgets/calendar_field.dart';
import '../../widgets/onboarding_cards.dart';

/// Memory-only drafts: never written to shared storage, never treated as uploads.
class CaptureDraft {
  List<DocumentFile> files = [];
  bool identityConsent = false;
  String source = 'GALLERY', expiry = '', number = '', licenceClasses = '';
}

Future<String?> validateCaptureDraft(
  DocumentRule rule,
  CaptureDraft draft,
) async {
  for (final file in draft.files) {
    final mime = lookupMimeType('', headerBytes: file.bytes.take(32).toList());
    if (![
      'image/jpeg',
      'image/png',
      'image/webp',
      if (!rule.imageOnly) 'application/pdf',
    ].contains(mime)) {
      return 'Choose a valid JPEG, PNG, WebP${rule.imageOnly ? '' : ' or PDF'} file.';
    }
    if (mime!.startsWith('image/')) {
      try {
        final codec = await ui.instantiateImageCodec(file.bytes);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } catch (_) {
        return 'This image cannot be decoded. Replace it before uploading.';
      }
    }
  }
  return null;
}

typedef CapturePicker = Future<List<DocumentFile>> Function(
  String source,
  bool photo,
);

class GuidedDocumentCapture extends StatefulWidget {
  final DocumentRule rule;
  final CaptureDraft draft;
  final CapturePicker? picker;
  final bool disabled;
  final VoidCallback changed;
  final String scope;
  final bool showMetadata;
  final ValueChanged<bool>? onBusyChanged;
  const GuidedDocumentCapture({
    super.key,
    required this.rule,
    required this.draft,
    required this.changed,
    this.picker,
    this.disabled = false,
    this.scope = 'unscoped',
    this.showMetadata = true,
    this.onBusyChanged,
  });
  @override
  State<GuidedDocumentCapture> createState() => _GuidedDocumentCaptureState();
}

class _GuidedDocumentCaptureState extends State<GuidedDocumentCapture> {
  bool _picking = false, _settings = false;
  String? _error;
  bool get photo => widget.rule.code == 'profile_photo';
  bool get imageOnly => widget.rule.imageOnly;
  static const _native = MethodChannel('infurnus/capture');
  static const _storage = FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    if (widget.picker == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _recover();
    }
  }

  Future<void> _recover() async {
    try {
      final pending = await _storage.read(key: 'onboarding_picker_task');
      final prefix = '${widget.scope}:${widget.rule.code}:';
      if (pending == null || !pending.startsWith(prefix)) return;
      final lost = await ImagePicker().retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      final files = <DocumentFile>[];
      for (final file in lost.files ?? <XFile>[]) {
        final bytes = await file.readAsBytes();
        files.add(
          DocumentFile(
            file.name,
            bytes,
            lookupMimeType('', headerBytes: bytes.take(32).toList()) ??
                'application/octet-stream',
          ),
        );
      }
      if (!mounted || files.isEmpty) return;
      // Recovered files are a draft only; upload validation still applies.
      widget.draft.files = files;
      widget.draft.source = pending.substring(prefix.length);
      setState(
        () => _error = 'Recovered an interrupted selection. Check the preview and replace it if needed before uploading.',
      );
      widget.changed();
      await _storage.delete(key: 'onboarding_picker_task');
    } catch (_) {
      /* No recoverable selection; normal picker remains available. */
    }
  }

  Future<List<DocumentFile>> _nativePick(String source, bool photo) async {
    if (source == 'FILE') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          if (!imageOnly) 'pdf',
        ],
        allowMultiple: !imageOnly,
        withData: true,
      );
      if (result != null && result.files.any((file) => file.bytes == null)) {
        throw const ApiException(
          'The provider could not download this file. Check your connection and try again.',
        );
      }
      return [
        for (final f in result?.files ?? <PlatformFile>[])
          if (f.bytes != null)
            DocumentFile(
              f.name,
              f.bytes!,
              lookupMimeType('', headerBytes: f.bytes!.take(32).toList()) ??
                  'application/octet-stream',
            ),
      ];
    }
    final picker = ImagePicker();
    final images = source == 'CAMERA' || imageOnly
        ? [
            await picker.pickImage(
              source: source == 'CAMERA'
                  ? ImageSource.camera
                  : ImageSource.gallery,
            ),
          ].whereType<XFile>().toList()
        : await picker.pickMultiImage(limit: 5);
    final result = <DocumentFile>[];
    for (final f in images) {
      final bytes = await f.readAsBytes();
      result.add(
        DocumentFile(
          f.name,
          bytes,
          lookupMimeType('', headerBytes: bytes.take(32).toList()) ??
              'application/octet-stream',
        ),
      );
    }
    return result;
  }

  /// Pick files from [source] and merge them into the draft.
  ///
  /// [targetSide] controls dual-side documents:
  ///   null  → standard append / replace behaviour (single-file or multi-page).
  ///   0     → replace the front side (index 0) only.
  ///   1     → replace or append the back side (index 1) only.
  Future<void> _pick(String source, {int? targetSide}) async {
    widget.onBusyChanged?.call(true);
    setState(() {
      _picking = true;
      _error = null;
      _settings = false;
    });
    try {
      if (widget.picker == null && !kIsWeb) {
        await _storage.write(
          key: 'onboarding_picker_task',
          value: '${widget.scope}:${widget.rule.code}:$source',
        );
      }
      final files = await (widget.picker ?? _nativePick)(source, photo);
      if (widget.picker == null && !kIsWeb) {
        await _storage.delete(key: 'onboarding_picker_task');
      }
      if (!mounted || files.isEmpty) {
        return; // Cancellation preserves the prior selection.
      }
      for (final f in files) {
        final limit = (imageOnly ? 10 : 15) * 1024 * 1024;
        if (f.bytes.isEmpty || f.bytes.length > limit) {
          throw ApiException(
            'Each file must be nonempty and at most ${imageOnly ? 10 : 15} MB.',
          );
        }
        if (f.mimeType.startsWith('image/')) {
          if (!['image/jpeg', 'image/png', 'image/webp'].contains(f.mimeType)) {
            throw const ApiException('Choose a JPEG, PNG or WebP image.');
          }
          final codec = await ui.instantiateImageCodec(
            Uint8List.fromList(f.bytes),
          );
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          codec.dispose();
        } else if (imageOnly || f.mimeType != 'application/pdf') {
          throw const ApiException(
            'This file is not a supported image or PDF.',
          );
        }
      }

      List<DocumentFile> next;
      if (photo) {
        // Profile photo: always single image, replace entirely.
        next = files.take(1).toList();
      } else if (targetSide != null) {
        // Dual-side button: surgically replace the targeted index only,
        // without wiping the other side.
        final current = List<DocumentFile>.from(widget.draft.files);
        final replacement = files.first;
        if (targetSide == 0) {
          // Replace or insert front at index 0.
          if (current.isEmpty) {
            current.add(replacement);
          } else {
            current[0] = replacement;
          }
        } else {
          // Replace or append back at index 1.
          if (current.length <= 1) {
            current.add(replacement);
          } else {
            current[1] = replacement;
          }
        }
        next = current;
      } else if (source == 'CAMERA' && !imageOnly) {
        // Camera in multi-page mode: append.
        next = [...widget.draft.files, ...files];
      } else {
        // Gallery / File / imageOnly: replace (standard behaviour).
        next = files;
      }

      if (next.length > (imageOnly ? 1 : 5) ||
          next.fold<int>(0, (n, f) => n + f.bytes.length) > 30 * 1024 * 1024) {
        throw const ApiException('Use at most 5 pages and 30 MB in total.');
      }
      widget.draft.files = next;
      widget.draft.source = source;
      widget.changed();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = e.code.contains('denied') || e.code.contains('restricted');
        _error = _settings
            ? 'Access was denied. Allow camera or photo access in app settings, then try again. You can also choose another source.'
            : 'The camera or picker is unavailable. Try another source.';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to read this image. Choose another file.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  Future<void> _chooseSource({int? targetSide}) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              subtitle: Text(
                photo
                    ? 'Take or retake your photo'
                    : targetSide == null
                    ? 'Capture another document page'
                    : targetSide == 0
                    ? 'Capture the front side'
                    : 'Capture the back side',
              ),
              onTap: () => Navigator.pop(context, 'CAMERA'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              subtitle: const Text('Select an image from your photos'),
              onTap: () => Navigator.pop(context, 'GALLERY'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Drive'),
              subtitle: const Text(
                'System files and available cloud providers; choose Drive if installed',
              ),
              onTap: () => Navigator.pop(context, 'FILE'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (mounted && source != null) await _pick(source, targetSide: targetSide);
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        _picking || widget.disabled || !widget.rule.collectionAllowed;
    final isAadhaar = widget.rule.code.startsWith('aadhaar');
    final isLicence = widget.rule.code == 'driver_license';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.draft.files.isEmpty) ...[
          if (photo)
            Center(
              child: Container(
                key: const ValueKey('circular-photo-placeholder'),
                width: 160,
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(height: 4),
                    Icon(Icons.camera_alt, size: 20, color: Color(0xFF00A14D)),
                  ],
                ),
              ),
            )
          else if (isAadhaar) ...[
            const AadhaarCardGraphic(),
            Container(
              key: const ValueKey('document-placeholder'),
              child: const SizedBox.shrink(),
            ),
          ] else if (isLicence) ...[
            const DrivingLicenceCardGraphic(),
            Container(
              key: const ValueKey('document-placeholder'),
              child: const SizedBox.shrink(),
            ),
          ] else ...[
            Center(
              child: Container(
                key: const ValueKey('document-placeholder'),
                width: double.infinity,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.rule.code.contains('vehicle')
                          ? Icons.directions_car_outlined
                          : Icons.document_scanner_outlined,
                      size: 48,
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.rule.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        for (var i = 0; i < widget.draft.files.length; i++) ...[
          if (widget.draft.files[i].mimeType.startsWith('image/'))
            Center(
              child: photo
                  ? ClipOval(
                      key: const ValueKey('circular-photo-preview'),
                      child: SizedBox.square(
                        dimension: 160,
                        child: Image.memory(
                          Uint8List.fromList(widget.draft.files[i].bytes),
                          fit: BoxFit.cover,
                          semanticLabel: 'Selected profile photo',
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: 1.586,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          Uint8List.fromList(widget.draft.files[i].bytes),
                          fit: BoxFit.contain,
                          semanticLabel:
                              'Selected ${widget.rule.label}, page ${i + 1}',
                          errorBuilder: (_, _, _) => const Text(
                            'Preview unavailable. Replace this image.',
                          ),
                        ),
                      ),
                    ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    size: 40,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.draft.files[i].name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected locally — page ${i + 1} (${widget.draft.files[i].name})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove page ${i + 1}',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  onPressed: disabled
                      ? null
                      : () {
                          widget.draft.files.removeAt(i);
                          widget.changed();
                          setState(() {});
                        },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Dual-side upload buttons inspired by Ola Driver Aadhaar upload screen
        if (!photo && widget.rule.minimumPages >= 1) ...[
          DualSideUploadArea(
            onUploadFront: () => _chooseSource(targetSide: 0),
            onUploadBack: () => _chooseSource(targetSide: 1),
            frontUploaded: widget.draft.files.isNotEmpty,
            backUploaded: widget.draft.files.length >= 2,
            disabled: disabled,
          ),
          const SizedBox(height: 12),
        ],

        if (!widget.rule.collectionAllowed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Identity collection is unavailable. Use an approved alternative or contact support.',
              style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          ),

        if (widget.rule.code.startsWith('aadhaar') &&
            widget.rule.collectionAllowed)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: widget.draft.identityConsent
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.draft.identityConsent
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              value: widget.draft.identityConsent,
              activeColor: const Color(0xFF16A34A),
              onChanged: disabled
                  ? null
                  : (v) => setState(
                      () => widget.draft.identityConsent = v == true,
                    ),
              title: const Text(
                'I consent to the authorized verification purpose and confirm this is a permitted masked copy.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ),

        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: disabled ? null : _chooseSource,
            icon: Icon(
              photo
                  ? Icons.add_a_photo_outlined
                  : Icons.document_scanner_outlined,
              size: 20,
            ),
            label: Text(
              widget.draft.files.isEmpty
                  ? 'Choose source'
                  : 'Replace or add pages',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          photo
              ? 'JPEG, PNG or WebP • up to 10 MB. Camera opens only when you choose it.'
              : imageOnly
              ? 'JPEG, PNG or WebP • one image up to 10 MB.'
              : '${widget.rule.minimumPages}–5 files • up to 15 MB each, 30 MB total. Capture additional pages in order.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        if (!photo && widget.showMetadata) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.draft.number,
            enabled: !disabled,
            decoration: InputDecoration(
              labelText: isAadhaar
                  ? 'Aadhaar number (optional)'
                  : 'Document number (optional)',
              hintText: isAadhaar ? 'XXXX-XXXX-1234' : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLength: 100,
            onChanged: (v) => widget.draft.number = v,
          ),
          if (!isAadhaar)
            CalendarField(
              key: ValueKey('${widget.scope}:${widget.rule.code}:expiry'),
              label:
                  'Expiry (YYYY-MM-DD${widget.rule.requiresExpiry ? ', required' : ', optional'})',
              initialValue: widget.draft.expiry,
              validator: (value) {
                final date = value?.trim() ?? '';
                if (date.isEmpty) {
                  return widget.rule.requiresExpiry
                      ? 'Expiry is required by this document policy.'
                      : null;
                }
                return !OnboardingRules.validDate(date) ||
                        date.compareTo(OnboardingRules.today()) < 0
                    ? 'Enter a valid date today or later.'
                    : null;
              },
              enabled: !disabled,
              onChanged: (v) => widget.draft.expiry = v,
            ),
        ],
        if (_picking)
          const LinearProgressIndicator(semanticsLabel: 'Opening image source'),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_settings)
          TextButton(
            onPressed: () async {
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                try {
                  await _native.invokeMethod<void>('settings');
                } on PlatformException catch (_) {
                  /* instructions remain visible */
                }
              } else if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.iOS) {
                await launchUrl(Uri.parse('app-settings:'));
              }
            },
            child: const Text('Open app settings'),
          ),
      ],
    );
  }
}
