import 'dart:convert';
import 'package:flutter/material.dart';

/// Representation of a single point in a signature stroke.
class SignaturePoint {
  final double x;
  final double y;
  final double pressure;

  const SignaturePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
  });

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'p': pressure};

  factory SignaturePoint.fromMap(Map<String, dynamic> map) {
    return SignaturePoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      pressure: (map['p'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Offset toOffset() => Offset(x, y);
}

/// A stored user signature profile for fast document signing.
class SignatureProfile {
  final String id;
  final String name; // e.g. "Primary Signature", "Initials"
  final List<List<SignaturePoint>> strokes;
  final DateTime createdAt;
  final int colorValue;

  const SignatureProfile({
    required this.id,
    required this.name,
    required this.strokes,
    required this.createdAt,
    this.colorValue = 0xFF000000,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'strokes': strokes.map((s) => s.map((p) => p.toMap()).toList()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'colorValue': colorValue,
    };
  }

  factory SignatureProfile.fromMap(Map<String, dynamic> map) {
    final rawStrokes = map['strokes'] as List? ?? const [];
    final parsedStrokes = rawStrokes.map((s) {
      final points = s as List? ?? const [];
      return points.map((p) => SignaturePoint.fromMap(p as Map<String, dynamic>)).toList();
    }).toList();

    return SignatureProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      strokes: parsedStrokes,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF000000,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SignatureProfile.fromJson(String source) =>
      SignatureProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
