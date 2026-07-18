import 'package:flutter/material.dart' show Color;

/// Pure data class representing a personnel movement record in history.
/// Extracted from movement_history_widget.dart for the models layer.
class MovementRecord {
  final String dateRange;
  final String movement;
  final String duration;
  final Color dotColor;

  MovementRecord({
    required this.dateRange,
    required this.movement,
    required this.duration,
    required this.dotColor,
  });
}
