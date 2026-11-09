import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/signature_model.dart';
import '../domain/signature_notifier.dart';

/// Interactive modal dialog for capturing user handwritten signatures.
class SignaturePadDialog extends ConsumerStatefulWidget {
  const SignaturePadDialog({super.key});

  @override
  ConsumerState<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends ConsumerState<SignaturePadDialog> {
  final List<List<SignaturePoint>> _strokes = [];
  List<SignaturePoint> _currentStroke = [];
  Color _selectedColor = Colors.black;
  final TextEditingController _nameController =
      TextEditingController(text: 'My Signature');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [
        SignaturePoint(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        )
      ];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke.add(
        SignaturePoint(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        ),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke.isNotEmpty) {
      setState(() {
        _strokes.add(List.from(_currentStroke));
        _currentStroke = [];
      });
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
  }

  Future<void> _save() async {
    if (_strokes.isEmpty) return;

    final notifier = ref.read(signatureNotifierProvider.notifier);
    final profile = await notifier.createProfile(
      name: _nameController.text.trim().isEmpty
          ? 'Signature'
          : _nameController.text.trim(),
      strokes: _strokes,
      colorValue: _selectedColor.toARGB32(),
    );

    if (mounted) {
      Navigator.of(context).pop(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Draw Signature',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Profile Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Capture Canvas
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F30) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: _SignatureCanvasPainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                        color: _selectedColor,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Color choices and controls
              Row(
                children: [
                  _ColorDot(
                    color: Colors.black,
                    isSelected: _selectedColor == Colors.black,
                    onTap: () => setState(() => _selectedColor = Colors.black),
                  ),
                  _ColorDot(
                    color: const Color(0xFF0D47A1), // Deep Blue
                    isSelected: _selectedColor == const Color(0xFF0D47A1),
                    onTap: () => setState(() => _selectedColor = const Color(0xFF0D47A1)),
                  ),
                  _ColorDot(
                    color: const Color(0xFFB71C1C), // Deep Red
                    isSelected: _selectedColor == const Color(0xFFB71C1C),
                    onTap: () => setState(() => _selectedColor = const Color(0xFFB71C1C)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              const Text(
                'Note: Inserts a visual handwritten signature mark onto the document. Not a cryptographic certificate.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _strokes.isNotEmpty ? _save : null,
                    child: const Text('Save Signature'),
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

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
            width: isSelected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _SignatureCanvasPainter extends CustomPainter {
  final List<List<SignaturePoint>> strokes;
  final List<SignaturePoint> currentStroke;
  final Color color;

  _SignatureCanvasPainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<SignaturePoint> stroke, Paint paint) {
    if (stroke.isEmpty) return;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first.toOffset(), paint.strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    path.moveTo(stroke[0].x, stroke[0].y);

    for (int i = 1; i < stroke.length; i++) {
      final p1 = stroke[i - 1];
      final p2 = stroke[i];
      final mid = Offset((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
      path.quadraticBezierTo(p1.x, p1.y, mid.dx, mid.dy);
    }
    path.lineTo(stroke.last.x, stroke.last.y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignatureCanvasPainter oldDelegate) => true;
}
