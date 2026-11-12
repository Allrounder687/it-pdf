import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import '../../../library/domain/library_notifier.dart';
import 'pdf_tool_model.dart';

class ProtectPdfTool extends PdfTool {
  const ProtectPdfTool();

  @override
  String get id => 'protect';

  @override
  String get title => 'Protect & Permissions';

  @override
  String get description =>
      'Encrypt PDFs with AES-256 and lock print, copy, modify, or form permissions.';

  @override
  IconData get icon => Icons.lock_outline_rounded;

  @override
  Color get color => AppTheme.toolGold;

  @override
  ToolCategory get category => ToolCategory.security;

  @override
  String get badge => 'AES-256';

  @override
  List<String> get searchKeywords => const [
    'protect',
    'password',
    'encrypt',
    'security',
    'lock',
    'permissions',
    'aes',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final path = await filePicker.pickPdfFile();
    if (path == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProtectPdfStudioScreen(sourcePath: path),
      ),
    );
  }
}

class _ProtectPdfStudioScreen extends ConsumerStatefulWidget {
  final String sourcePath;

  const _ProtectPdfStudioScreen({required this.sourcePath});

  @override
  ConsumerState<_ProtectPdfStudioScreen> createState() =>
      _ProtectPdfStudioScreenState();
}

class _ProtectPdfStudioScreenState
    extends ConsumerState<_ProtectPdfStudioScreen> {
  final _userController = TextEditingController();
  final _ownerController = TextEditingController();
  bool _obscureUser = true;
  bool _obscureOwner = true;
  PdfEncryptionTier _tier = PdfEncryptionTier.aes256;

  bool _allowPrint = true;
  bool _allowCopy = false;
  bool _allowModify = false;
  bool _allowFillForms = true;
  bool _allowAnnotations = true;
  bool _isProtecting = false;

  @override
  void dispose() {
    _userController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  ({String label, double score, Color color}) _passwordStrength(String pass) {
    if (pass.isEmpty) {
      return (label: 'Enter a password', score: 0.0, color: Colors.grey);
    }
    int pts = 0;
    if (pass.length >= 8) pts++;
    if (pass.length >= 12) pts++;
    if (RegExp(r'[A-Z]').hasMatch(pass)) pts++;
    if (RegExp(r'[0-9]').hasMatch(pass)) pts++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pass)) pts++;

    if (pts <= 1) {
      return (label: 'Weak', score: 0.25, color: Colors.redAccent);
    }
    if (pts <= 3) {
      return (label: 'Moderate', score: 0.55, color: Colors.orange);
    }
    if (pts == 4) {
      return (label: 'Strong', score: 0.8, color: Colors.lightGreen);
    }
    return (label: 'Very Strong', score: 1.0, color: Colors.green);
  }

  Future<void> _applyProtection() async {
    final userPass = _userController.text.trim();
    final ownerPass = _ownerController.text.trim();

    if (userPass.isEmpty && ownerPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a User Password or Owner Password.'),
        ),
      );
      return;
    }

    final filePicker = ref.read(filePickerServiceProvider);
    final baseName = p.basenameWithoutExtension(widget.sourcePath);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: '${baseName}_protected.pdf',
      dialogTitle: 'Save Encrypted PDF',
    );
    if (dest == null || !mounted) return;

    setState(() => _isProtecting = true);
    try {
      await ref
          .read(syncfusionPdfServiceProvider)
          .protectPdfWithOptions(
            sourcePath: widget.sourcePath,
            outputPath: dest,
            userPassword: userPass,
            ownerPassword: ownerPass.isNotEmpty ? ownerPass : userPass,
            tier: _tier,
            allowPrint: _allowPrint,
            allowCopy: _allowCopy,
            allowModify: _allowModify,
            allowFillForms: _allowFillForms,
            allowAnnotations: _allowAnnotations,
          );
      await ref.read(libraryNotifierProvider.notifier).importFileFromPath(dest);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Encrypted (${_tier.label}) -> ${p.basename(dest)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProtecting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Encryption failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_userController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Protect & Permissions Studio')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'File: ${p.basename(widget.sourcePath)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _userController,
                  obscureText: _obscureUser,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Open Password (required to view PDF)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureUser ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureUser = !_obscureUser),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strength.score,
                    minHeight: 6,
                    valueColor: AlwaysStoppedAnimation(strength.color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Password Strength: ${strength.label}',
                  style: TextStyle(fontSize: 11, color: strength.color),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _ownerController,
                  obscureText: _obscureOwner,
                  decoration: InputDecoration(
                    labelText:
                        'Owner Password (controls permissions, optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureOwner ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureOwner = !_obscureOwner),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Encryption Algorithm',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<PdfEncryptionTier>(
                  segments: PdfEncryptionTier.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                      .toList(),
                  selected: {_tier},
                  onSelectionChanged: (s) => setState(() => _tier = s.first),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Document Permissions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                CheckboxListTile(
                  value: _allowPrint,
                  onChanged: (v) => setState(() => _allowPrint = v ?? false),
                  title: const Text('Allow Printing'),
                ),
                CheckboxListTile(
                  value: _allowCopy,
                  onChanged: (v) => setState(() => _allowCopy = v ?? false),
                  title: const Text('Allow Copying Text & Graphics'),
                ),
                CheckboxListTile(
                  value: _allowAnnotations,
                  onChanged: (v) =>
                      setState(() => _allowAnnotations = v ?? false),
                  title: const Text('Allow Adding Annotations & Comments'),
                ),
                CheckboxListTile(
                  value: _allowFillForms,
                  onChanged: (v) =>
                      setState(() => _allowFillForms = v ?? false),
                  title: const Text('Allow Filling AcroForm Fields'),
                ),
                CheckboxListTile(
                  value: _allowModify,
                  onChanged: (v) => setState(() => _allowModify = v ?? false),
                  title: const Text('Allow Page Assembly & Modification'),
                ),

                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isProtecting ? null : _applyProtection,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    _isProtecting
                        ? 'Encrypting Document...'
                        : 'Encrypt & Save PDF',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.toolGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
