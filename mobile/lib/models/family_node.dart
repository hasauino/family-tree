import 'package:flutter/material.dart';

/// Number of colors in the tree palette. Mirrors `N_COLORS` in
/// `familytree/main/models.py` so node grouping/coloring matches the web app.
const int kColorCount = 11;

/// Palette indexed by the numeric part of the backend `group` code (g0..g10).
/// The backend assigns `group = "g{(parent_id or 0) % 11}"`, so siblings share
/// a color and the hue changes per branch — same idea as the vis.js view.
const List<Color> kGroupColors = [
  Color(0xFF5B8FF9),
  Color(0xFF61DDAA),
  Color(0xFF65789B),
  Color(0xFFF6BD16),
  Color(0xFF7262FD),
  Color(0xFF78D3F8),
  Color(0xFF9661BC),
  Color(0xFFF6903D),
  Color(0xFF008685),
  Color(0xFFF08BB4),
  Color(0xFFEE6666),
];

/// A single person rendered as a node in the tree.
///
/// This is the display model shared by both the initial bootstrap query
/// (built from `PersonType`) and the interactive `connectedNodes` query.
class FamilyNode {
  FamilyNode({
    required this.id,
    required this.label,
    required this.group,
    this.title,
    this.opacity = 1.0,
  });

  /// Person primary key.
  final int id;

  /// Display name (person's `name`).
  final String label;

  /// Backend group code, e.g. "g3". Drives the node color.
  final String group;

  /// Optional details (designation / history) — shown on tap-and-hold.
  final String? title;

  /// 0.0..1.0. Staff see private (unpublished) persons dimmed, like the web.
  final double opacity;

  Color get color {
    final n = int.tryParse(group.replaceFirst('g', '')) ?? 0;
    return kGroupColors[n % kColorCount];
  }

  /// First letter of the name, for the avatar. Falls back to '?'.
  String get initial {
    final t = label.trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  /// Short one-line subtitle for the card (the designation / first detail
  /// line), or null when there's nothing useful to show.
  String? get subtitle {
    final t = title?.trim();
    if (t == null || t.isEmpty) return null;
    final firstLine = t.split('\n').first.trim();
    return firstLine.isEmpty ? null : firstLine;
  }

  FamilyNode copyWith({double? opacity}) => FamilyNode(
        id: id,
        label: label,
        group: group,
        title: title,
        opacity: opacity ?? this.opacity,
      );

  /// Build from a `connectedNodes` node payload (parent / child).
  factory FamilyNode.fromConnectedJson(Map<String, dynamic> json) {
    return FamilyNode(
      id: json['id'] as int,
      label: (json['label'] as String?) ?? '',
      group: (json['group'] as String?) ?? 'g0',
      title: _cleanTitle(json['title'] as String?),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Build from a `PersonType` payload (used by the initial bootstrap query),
  /// computing the group color from the parent id the same way the backend does.
  factory FamilyNode.fromPersonJson(
    Map<String, dynamic> json, {
    int? parentId,
  }) {
    final designation = (json['designation'] as String?) ?? '';
    final history = (json['history'] as String?) ?? '';
    final title = '$designation\n$history';
    return FamilyNode(
      id: int.parse(json['id'].toString()),
      label: (json['name'] as String?) ?? '',
      group: 'g${(parentId ?? 0) % kColorCount}',
      title: _cleanTitle(title),
    );
  }

  static String? _cleanTitle(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
