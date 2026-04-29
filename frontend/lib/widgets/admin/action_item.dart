// lib/widgets/admin/action_item.dart
import 'package:flutter/material.dart';

class ActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  ActionItem(this.icon, this.title, this.subtitle, this.onTap);
}