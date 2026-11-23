import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';
import 'vocab_game.dart';

/// Runs the game on its own. Inside a bigger app, use [VocabGame] instead
/// and pass the logged-in child's id.
void main() {
  final player = playerFromLink(Uri.base);
  runApp(
    VocabGame(
      playerId: player,
      playerName: player == defaultPlayer ? null : titleCase(player),
    ),
  );
}

/// The player named in the link, e.g. `localhost:8081/?kid=mia`, to try
/// per-kid scores without a login. Not a login: anyone can type any name.
/// Only letters, digits, `-` and `_`; anything else means [defaultPlayer].
String playerFromLink(Uri link) {
  final kid = (link.queryParameters['kid'] ?? '').trim().toLowerCase();
  return RegExp(r'^[a-z0-9_-]{1,30}$').hasMatch(kid) ? kid : defaultPlayer;
}
