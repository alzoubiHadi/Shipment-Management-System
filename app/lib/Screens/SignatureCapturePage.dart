import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../API/config.dart';

/// DEAD CODE (2026-08-25): superseded by PodAttachmentPage.dart, which
/// replaces the hand-drawn signature with a photographed/uploaded POD
/// document. No longer referenced from ShipmentTrackingPage.dart or
/// anywhere else. Left in place rather than deleted per this codebase's
/// convention — safe to remove entirely in a future cleanup pass.
///
/// Lets the driver capture a hand-drawn signature (finger/mouse) plus the
/// recipient's name as proof of delivery. Returns
/// {'signature': base64Png, 'recipientName': String} via Navigator.pop, or
/// null if the driver backs out.
class SignatureCapturePage extends StatefulWidget {
  const SignatureCapturePage({super.key});

  @override
  State<SignatureCapturePage> createState() => _SignatureCapturePageState();
}

class _SignatureCapturePageState extends State<SignatureCapturePage> {
  final _boundaryKey = GlobalKey();
  final _nameController = TextEditingController();
  final List<Offset?> _points = [];
  bool _isSaving = false;

  void _clear() => setState(() => _points.clear());

  Offset _localPoint(Offset globalPosition) {
    final box = _boundaryKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(globalPosition);
  }

  Future<void> _confirm() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the recipient name first')),
      );
      return;
    }
    if (_points.where((p) => p != null).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign before confirming')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final base64Str = base64Encode(bytes);

      if (!mounted) return;
      Navigator.pop(context, {
        'signature': base64Str,
        'recipientName': _nameController.text.trim(),
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: const Text('Proof of Delivery',
            style: TextStyle(color: LightColors.cream)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: LightColors.cream),
              decoration: InputDecoration(
                labelText: 'Recipient name',
                labelStyle: const TextStyle(color: LightColors.muted),
                filled: true,
                fillColor: LightColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LightColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LightColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LightColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign below with your finger or mouse',
              style: TextStyle(color: LightColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LightColors.border),
                  ),
                  child: GestureDetector(
                    onPanStart: (details) => setState(
                        () => _points.add(_localPoint(details.globalPosition))),
                    onPanUpdate: (details) => setState(
                        () => _points.add(_localPoint(details.globalPosition))),
                    onPanEnd: (_) => setState(() => _points.add(null)),
                    child: CustomPaint(
                      painter: _SignaturePainter(_points),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: LightColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Clear',
                        style: TextStyle(color: LightColors.muted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LightColors.deepNavy,
                            ),
                          )
                        : const Text(
                            'Confirm delivery',
                            style: TextStyle(
                              color: LightColors.deepNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
