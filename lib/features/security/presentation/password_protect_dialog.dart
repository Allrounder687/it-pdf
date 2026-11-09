import 'package:flutter/material.dart';
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';
import '../../../core/platform/file_picker_service.dart';

/// Modal dialog for applying AES-256 bit encryption and password protection.
class PasswordProtectDialog extends StatefulWidget {
  final String documentPath;
  final SyncfusionPdfService pdfService;
  final FilePickerService filePicker;

  const PasswordProtectDialog({
    super.key,
    required this.documentPath,
    required this.pdfService,
    required this.filePicker,
  });

  @override
  State<PasswordProtectDialog> createState() => _PasswordProtectDialogState();
}

class _PasswordProtectDialogState extends State<PasswordProtectDialog> {
  final TextEditingController _userPasswordController = TextEditingController();
  final TextEditingController _ownerPasswordController = TextEditingController();
  bool _obscureUser = true;
  bool _obscureOwner = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _userPasswordController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _protectDocument() async {
    final userPass = _userPasswordController.text.trim();
    final ownerPass = _ownerPasswordController.text.trim();

    if (userPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a user password.')),
      );
      return;
    }

    final dest = await widget.filePicker.getSaveDestinationPath(
      defaultFileName: 'protected_document.pdf',
    );
    if (dest == null) return;

    setState(() => _isProcessing = true);

    try {
      await widget.pdfService.protectPdfWithPassword(
        sourcePath: widget.documentPath,
        userPassword: userPass,
        ownerPassword: ownerPass.isNotEmpty ? ownerPass : userPass,
        outputPath: dest,
      );

      if (mounted) {
        Navigator.of(context).pop(dest);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to encrypt document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    'Protect PDF with Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Secures document contents with AES-256 bit military-grade encryption.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userPasswordController,
                obscureText: _obscureUser,
                decoration: InputDecoration(
                  labelText: 'User Password (to open document)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureUser ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureUser = !_obscureUser),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ownerPasswordController,
                obscureText: _obscureOwner,
                decoration: InputDecoration(
                  labelText: 'Owner Password (optional permissions lock)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOwner ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureOwner = !_obscureOwner),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isProcessing ? null : _protectDocument,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Encrypt & Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
