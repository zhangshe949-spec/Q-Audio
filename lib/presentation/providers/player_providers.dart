import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/playback/player_controller.dart';

export '../../services/playback/player_controller.dart'
    show audioEngineProvider, PlaybackState, PlaybackStatus;

/// UI-facing playback state; the controller resolves the engine via ref.
final playerProvider = NotifierProvider<PlayerController, PlaybackState>(
  PlayerController.new,
);
