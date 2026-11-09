import 'package:flutter/material.dart';
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';

/// Interactive AcroForm Inspector and Editor modal dialog.
/// Supports TextBoxes, CheckBoxes, RadioButtonLists, Dropdowns, and ListBoxes.
class FormFieldsDialog extends StatefulWidget {
  final String documentPath;
  final SyncfusionPdfService pdfService;

  const FormFieldsDialog({
    super.key,
    required this.documentPath,
    required this.pdfService,
  });

  @override
  State<FormFieldsDialog> createState() => _FormFieldsDialogState();
}

class _FormFieldsDialogState extends State<FormFieldsDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _fields = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checkboxValues = {};
  final Map<String, String> _dropdownValues = {};
  bool _flattenForm = false;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await widget.pdfService.getFormFields(widget.documentPath);
    for (final f in fields) {
      final name = f['name'] as String;
      final type = f['type'] as String;
      final val = f['value'] as String;

      if (type == 'checkbox') {
        _checkboxValues[name] = val.toLowerCase() == 'true';
      } else if (type == 'combobox' || type == 'radio') {
        _dropdownValues[name] = val;
      } else {
        _controllers[name] = TextEditingController(text: val);
      }
    }

    if (mounted) {
      setState(() {
        _fields = fields;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveForm() async {
    final values = <String, String>{};
    for (final entry in _controllers.entries) {
      values[entry.key] = entry.value.text;
    }
    for (final entry in _checkboxValues.entries) {
      values[entry.key] = entry.value.toString();
    }
    for (final entry in _dropdownValues.entries) {
      values[entry.key] = entry.value;
    }

    setState(() => _isLoading = true);

    try {
      await widget.pdfService.updateAndFlattenForm(
        sourcePath: widget.documentPath,
        fieldValues: values,
        flatten: _flattenForm,
        outputPath: widget.documentPath,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update form: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Interactive PDF Forms',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_fields.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No interactive form fields found in this document.'),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _fields.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final f = _fields[index];
                      final name = f['name'] as String;
                      final type = f['type'] as String;
                      final options = (f['options'] as List<dynamic>?)?.cast<String>() ?? [];

                      if (type == 'checkbox') {
                        return CheckboxListTile(
                          title: Text(name),
                          value: _checkboxValues[name] ?? false,
                          onChanged: (val) {
                            setState(() => _checkboxValues[name] = val ?? false);
                          },
                        );
                      }

                      if ((type == 'combobox' || type == 'radio') && options.isNotEmpty) {
                        final currentVal = _dropdownValues[name] ?? (options.isNotEmpty ? options.first : '');
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: name,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          initialValue: options.contains(currentVal) ? currentVal : options.first,
                          items: options.map((opt) {
                            return DropdownMenuItem(value: opt, child: Text(opt));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _dropdownValues[name] = val);
                            }
                          },
                        );
                      }

                      return TextField(
                        controller: _controllers[name],
                        decoration: InputDecoration(
                          labelText: name,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Flatten Form on Save'),
                subtitle: const Text('Permanently embeds field data into the document (ISO 32000)'),
                value: _flattenForm,
                onChanged: (val) => setState(() => _flattenForm = val),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _fields.isNotEmpty ? _saveForm : null,
                    child: const Text('Save Form Data'),
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
