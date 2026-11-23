import 'package:flutter/material.dart';

import '../theme.dart';

/// Demo-mode banner: explains why the app chose the current word. Only shown
/// when a teacher turns on "Show why".
class WhyNote extends StatelessWidget {
  final List<String> lines;

  const WhyNote(this.lines, {super.key});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1B8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC53D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: ink),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in lines)
                Text(line, style: const TextStyle(fontSize: 18, color: ink)),
            ],
          ),
        ],
      ),
    );
  }
}
