import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../core/operations_theme.dart';
import '../../models/onboarding_rules.dart';
import '../../providers/driver_session.dart';
import '../../services/api_service.dart';

class DocumentUploadDialog extends StatefulWidget {
  final DriverSession session;
  final DocumentRule rule;
  final Future<bool> Function(
    DocumentRule,
    List<DocumentFile>,
    Map<String, String>,
  )?
  uploader;
  final String? Function()? errorMessage;
  const DocumentUploadDialog({
    super.key,
    required this.session,
    required this.rule,
    this.uploader,
    this.errorMessage,
  });
  @override
  State<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends State<DocumentUploadDialog> {
  final _number = TextEditingController();
  final _holderName = TextEditingController(),
      _licenceClasses = TextEditingController();
  final _authority = TextEditingController();
  final _issued = TextEditingController();
  final _expiry = TextEditingController();
  final List<DocumentFile> _files = [];
  String _source = 'FILE';
  String _side = 'FRONT';
  String? _error;
  bool _busy = false;
  bool _identityConsent = false;
  @override
  void dispose() {
    _number.dispose();
    _holderName.dispose();
    _licenceClasses.dispose();
    _authority.dispose();
    _issued.dispose();
    _expiry.dispose();
    super.dispose();
  }

  String _resolveMime(String name, List<int> bytes) {
    final nameLower = name.toLowerCase();
    var mime =
        lookupMimeType(
          name,
          headerBytes: bytes.take(min(32, bytes.length)).toList(),
        ) ??
        'application/octet-stream';
    if (mime == 'application/octet-stream' || mime == 'image/jpg') {
      if (nameLower.endsWith('.jpg') || nameLower.endsWith('.jpeg')) {
        mime = 'image/jpeg';
      } else if (nameLower.endsWith('.png')) {
        mime = 'image/png';
      } else if (nameLower.endsWith('.webp')) {
        mime = 'image/webp';
      } else if (nameLower.endsWith('.pdf')) {
        mime = 'application/pdf';
      }
    }
    return mime;
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final initialDate =
        DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _pick(String source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final nextFiles = <DocumentFile>[];
      if (source == 'FILE') {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: widget.rule.code != 'profile_photo',
          type: FileType.custom,
          allowedExtensions: widget.rule.code == 'profile_photo'
              ? ['jpg', 'jpeg', 'png', 'webp']
              : ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          withData: true,
        );
        if (result != null) {
          for (final file in result.files) {
            if (file.bytes != null) {
              nextFiles.add(
                DocumentFile(
                  file.name,
                  file.bytes!,
                  _resolveMime(file.name, file.bytes!),
                ),
              );
            }
          }
        }
      } else {
        final picker = ImagePicker();
        final List<XFile> images;
        if (source == 'CAMERA' || widget.rule.code == 'profile_photo') {
          final image = await picker.pickImage(
            source: source == 'CAMERA'
                ? ImageSource.camera
                : ImageSource.gallery,
          );
          images = image == null ? [] : [image];
        } else {
          images = await picker.pickMultiImage(limit: 5);
        }
        for (final image in images) {
          final bytes = await image.readAsBytes();
          nextFiles.add(
            DocumentFile(image.name, bytes, _resolveMime(image.name, bytes)),
          );
        }
      }
      if (!mounted || nextFiles.isEmpty) return;
      final resultingFiles = source == 'CAMERA' && _source == 'CAMERA'
          ? [..._files, ...nextFiles]
          : nextFiles;
      final maxFiles = widget.rule.code == 'profile_photo' ? 1 : 5;
      final limit = widget.rule.code == 'profile_photo' ? 10 : 15;
      if (resultingFiles.length > maxFiles ||
          resultingFiles.any(
            (f) => f.bytes.isEmpty || f.bytes.length > limit * 1024 * 1024,
          ) ||
          resultingFiles.fold<int>(0, (n, f) => n + f.bytes.length) >
              30 * 1024 * 1024) {
        throw ApiException(
          'Select up to $maxFiles files, each at most $limit MB, with a combined limit of 30 MB.',
        );
      }
      setState(() {
        _files
          ..clear()
          ..addAll(resultingFiles);
        _source = source;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to select the document. Check permissions and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (widget.session.busy) {
      setState(
        () => _error = 'Please wait for the current status refresh to finish.',
      );
      return;
    }
    final metadata = <String, String>{
      if (_identityConsent) ...{
        'identityConsent': 'true',
        'maskedIdentity': 'true',
      },
      'uploadSource': _source,
      if (_number.text.trim().isNotEmpty)
        'documentNumber': widget.rule.code == 'pan'
            ? _number.text.trim().toUpperCase()
            : _number.text.trim(),
      if (_holderName.text.trim().isNotEmpty)
        'holderName': _holderName.text.trim(),
      if (_licenceClasses.text.trim().isNotEmpty)
        'licenceClasses': _licenceClasses.text.trim(),
      if (_authority.text.trim().isNotEmpty)
        'issuingAuthority': _authority.text.trim(),
      if (_issued.text.trim().isNotEmpty) 'issuedAt': _issued.text.trim(),
      if (_expiry.text.trim().isNotEmpty) 'expiresAt': _expiry.text.trim(),
      if (_files.length == 1) 'side': _side,
    };
    final validation = OnboardingRules.validateFiles(
      widget.rule,
      _files,
      metadata,
    );
    if (validation == null &&
        widget.rule.code == 'pan' &&
        !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
            .hasMatch(_number.text.trim().toUpperCase())) {
      setState(() => _error = 'Enter the PAN number printed on the document.');
      return;
    }
    if (validation == null &&
        [
          'pan',
          'driving_licence',
          'driver_license',
        ].contains(widget.rule.code) &&
        _holderName.text.trim().length < 2) {
      setState(() => _error = 'Enter the name printed on the document.');
      return;
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await (widget.uploader ?? widget.session.uploadDocument)(
      widget.rule,
      List.of(_files),
      metadata,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = widget.errorMessage?.call() ?? widget.session.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => !widget.rule.collectionAllowed
      ? AlertDialog(
          title: const Text('Identity collection unavailable'),
          content: const Text(
            'Use an approved alternative identity workflow. Aadhaar collection needs an authorized policy and a permitted masked-copy process.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        )
      : AlertDialog(
          title: Text('Upload ${widget.rule.label}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Ops.surfaceOverlay,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Ops.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.rule.required
                              ? 'Required document'
                              : 'Optional document',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.rule.required
                              ? 'Upload at least ${widget.rule.minimumPages} page(s) (up to 5). Accepted: JPEG, PNG, WebP or PDF.'
                              : 'This document is optional. If you choose to upload it, provide at least ${widget.rule.minimumPages} page/file (up to 5 total).',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Ops.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick('CAMERA'),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text(
                            'Camera',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick('GALLERY'),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Gallery',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick('FILE'),
                          icon: const Icon(
                            Icons.folder_open_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Files',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < _files.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _files[index].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${index + 1}: ${index == 0
                            ? 'Front'
                            : index == 1
                            ? 'Back'
                            : 'Page'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index > 0)
                            IconButton(
                              tooltip: 'Move up',
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      final file = _files.removeAt(index);
                                      _files.insert(index - 1, file);
                                    }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _files.removeAt(index)),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  if (_files.length == 1 && widget.rule.code != 'profile_photo')
                    DropdownButtonFormField<String>(
                      initialValue: _side,
                      decoration: const InputDecoration(
                        labelText: 'Document side',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: ['FRONT', 'BACK', 'PAGE']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (s) {
                              if (s != null) setState(() => _side = s);
                            },
                    ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Document metadata (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ([
                    'pan',
                    'driving_licence',
                    'driver_license',
                    'aadhaar',
                    'aadhaar_masked',
                  ].contains(widget.rule.code)) ...[
                    TextField(
                      controller: _holderName,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Name printed on document',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if ([
                      'driving_licence',
                      'driver_license',
                    ].contains(widget.rule.code)) ...[
                      TextField(
                        controller: _licenceClasses,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Licence classes (if applicable)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (widget.rule.code.startsWith('aadhaar')) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _identityConsent,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _identityConsent = v == true),
                      title: const Text(
                        'I consent to the authorized verification purpose and confirm this is a permitted masked copy.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _number,
                    enabled: !_busy,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Document number (optional)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _authority,
                    enabled: !_busy,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Issuing authority (optional)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _issued,
                    enabled: !_busy,
                    readOnly: true,
                    onTap: _busy ? null : () => _selectDate(_issued),
                    decoration: InputDecoration(
                      labelText: 'Issue date (YYYY-MM-DD, optional)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: _busy ? null : () => _selectDate(_issued),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _expiry,
                    enabled: !_busy,
                    readOnly: true,
                    onTap: _busy ? null : () => _selectDate(_expiry),
                    decoration: InputDecoration(
                      labelText:
                          'Expiry date (YYYY-MM-DD${widget.rule.requiresExpiry ? ', required' : ', optional'})',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: _busy ? null : () => _selectDate(_expiry),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Uploading…' : 'Upload'),
                  ),
                ),
              ],
            ),
          ],
        );
}
