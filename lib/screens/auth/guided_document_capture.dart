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

  Future<void> _pick(String source) async {
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
      final next = !imageOnly && source == 'CAMERA'
          ? [...widget.draft.files, ...files]
          : files;
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

  Future<void> _chooseSource() async {
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
                    : 'Capture another document page',
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
    if (mounted && source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        _picking || widget.disabled || !widget.rule.collectionAllowed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.draft.files.isEmpty)
          Center(
            child: Container(
              key: ValueKey(
                photo ? 'circular-photo-placeholder' : 'document-placeholder',
              ),
              width: photo ? 160 : double.infinity,
              height: photo ? 160 : 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: photo ? BoxShape.circle : BoxShape.rectangle,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: photo ? null : BorderRadius.circular(12),
              ),
              child: Icon(
                photo ? Icons.person_outline : Icons.document_scanner_outlined,
                size: 64,
              ),
            ),
          ),
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
                        borderRadius: BorderRadius.circular(12),
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
            const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.picture_as_pdf, size: 64),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Selected locally — page ${i + 1}'),
            subtitle: Text(
              widget.draft.files[i].name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Remove page ${i + 1}',
              icon: const Icon(Icons.close),
              onPressed: disabled
                  ? null
                  : () {
                      widget.draft.files.removeAt(i);
                      widget.changed();
                      setState(() {});
                    },
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!widget.rule.collectionAllowed)
          const Text(
            'Identity collection is unavailable. Use an approved alternative or contact support.',
          ),
        if (widget.rule.code.startsWith('aadhaar') &&
            widget.rule.collectionAllowed)
          CheckboxListTile(
            value: widget.draft.identityConsent,
            onChanged: disabled
                ? null
                : (v) =>
                      setState(() => widget.draft.identityConsent = v == true),
            title: const Text(
              'I consent to the authorized verification purpose and confirm this is a permitted masked copy.',
            ),
          ),
        OutlinedButton.icon(
          onPressed: disabled ? null : _chooseSource,
          icon: Icon(
            photo
                ? Icons.add_a_photo_outlined
                : Icons.document_scanner_outlined,
          ),
          label: Text(
            widget.draft.files.isEmpty
                ? 'Choose source'
                : 'Replace or add pages',
          ),
        ),
        Text(
          photo
              ? 'JPEG, PNG or WebP • up to 10 MB. Camera opens only when you choose it.'
              : imageOnly
              ? 'JPEG, PNG or WebP • one image up to 10 MB.'
              : '${widget.rule.minimumPages}–5 files • up to 15 MB each, 30 MB total. Capture additional pages in order.',
        ),
        if (!photo && widget.showMetadata) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.draft.number,
            enabled: !disabled,
            decoration: const InputDecoration(
              labelText: 'Document number (optional)',
            ),
            maxLength: 100,
            onChanged: (v) => widget.draft.number = v,
          ),
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
