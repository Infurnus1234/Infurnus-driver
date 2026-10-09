import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

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
  final _authority = TextEditingController();
  final _issued = TextEditingController();
  final _expiry = TextEditingController();
  final List<DocumentFile> _files = [];
  String _source = 'FILE';
  String _side = 'FRONT';
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _number.dispose();
    _authority.dispose();
    _issued.dispose();
    _expiry.dispose();
    super.dispose();
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
                  lookupMimeType(
                        file.name,
                        headerBytes: file.bytes!
                            .take(min(32, file.bytes!.length))
                            .toList(),
                      ) ??
                      'application/octet-stream',
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
            DocumentFile(
              image.name,
              bytes,
              lookupMimeType(
                    image.name,
                    headerBytes: bytes.take(min(32, bytes.length)).toList(),
                  ) ??
                  'application/octet-stream',
            ),
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Upload ${widget.rule.label}'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.rule.required
                  ? 'Required by your current document policy.'
                  : 'Optional document.',
            ),
            Text(
              'Minimum files/pages: ${widget.rule.minimumPages}. Pages may be ordered for review; front/back is not universally required. A selected PDF counts as one uploaded file.',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final source in ['CAMERA', 'GALLERY', 'FILE'])
                  OutlinedButton(
                    onPressed: _busy ? null : () => _pick(source),
                    child: Text(
                      source == 'CAMERA'
                          ? 'Add camera page'
                          : source == 'GALLERY'
                          ? 'Gallery'
                          : 'Files',
                    ),
                  ),
              ],
            ),
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
                decoration: const InputDecoration(labelText: 'Document side'),
                items: ['FRONT', 'BACK', 'PAGE']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (s) {
                        if (s != null) setState(() => _side = s);
                      },
              ),
            TextField(
              controller: _number,
              enabled: !_busy,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Document number (optional)',
              ),
            ),
            TextField(
              controller: _authority,
              enabled: !_busy,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Issuing authority (optional)',
              ),
            ),
            TextField(
              controller: _issued,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Issue date (YYYY-MM-DD, optional)',
              ),
            ),
            TextField(
              controller: _expiry,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText:
                    'Expiry date (YYYY-MM-DD${widget.rule.requiresExpiry ? ', required' : ', optional'})',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _busy
            ? null
            : () async {
                if (widget.session.busy) {
                  setState(
                    () => _error =
                        'Please wait for the current status refresh to finish.',
                  );
                  return;
                }
                final metadata = <String, String>{
                  'uploadSource': _source,
                  if (_number.text.trim().isNotEmpty)
                    'documentNumber': _number.text.trim(),
                  if (_authority.text.trim().isNotEmpty)
                    'issuingAuthority': _authority.text.trim(),
                  if (_issued.text.trim().isNotEmpty)
                    'issuedAt': _issued.text.trim(),
                  if (_expiry.text.trim().isNotEmpty)
                    'expiresAt': _expiry.text.trim(),
                  if (_files.length == 1) 'side': _side,
                };
                final validation = OnboardingRules.validateFiles(
                  widget.rule,
                  _files,
                  metadata,
                );
                if (validation != null) {
                  setState(() => _error = validation);
                  return;
                }
                setState(() {
                  _busy = true;
                  _error = null;
                });
                final success =
                    await (widget.uploader ?? widget.session.uploadDocument)(
                      widget.rule,
                      List.of(_files),
                      metadata,
                    );
                if (!context.mounted) return;
                if (success) {
                  Navigator.pop(context, true);
                } else {
                  setState(() {
                    _busy = false;
                    _error =
                        widget.errorMessage?.call() ?? widget.session.error;
                  });
                }
              },
        child: const Text('Upload'),
      ),
    ],
  );
}
