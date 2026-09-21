import 'dart:async';

import '../../domain/entities/track.dart';
import 'music_source.dart';

/// Orchestrates multiple [MusicSource]s into a single search experience.
///
/// Caches the last search results so the UI can display them
/// without re-fetching when switching tabs.
class MusicSearchService {
  MusicSearchService(this._sources) {
    _aggregator = SourceAggregator(_sources);
  }

  final List<MusicSource> _sources;
  late SourceAggregator _aggregator;
  List<Track> _lastResults = const <Track>[];
  String _lastQuery = '';
  bool _isSearching = false;
  final List<StreamController<List<Track>>> _searchControllers = [];

  Stream<List<Track>> watchResults() {
    final controller = StreamController<List<Track>>.broadcast();
    _searchControllers.add(controller);
    controller.add(_lastResults);
    return controller.stream;
  }

  List<MusicSource> get sources => List.unmodifiable(_sources);

  bool get isSearching => _isSearching;

  List<Track> get lastResults => List.unmodifiable(_lastResults);

  String get lastQuery => _lastQuery;

  Future<List<Track>> search(String query, {int limitPerSource = 20}) async {
    _lastQuery = query;
    _isSearching = true;
    _notifyListeners();
    try {
      final results =
          await _aggregator.searchAll(query, limitPerSource: limitPerSource);
      _lastResults = results;
    } finally {
      _isSearching = false;
      _notifyListeners();
    }
    return List.unmodifiable(_lastResults);
  }

  Future<String?> resolveUrl(Track track) async {
    final source = _sources.firstWhere(
      (s) => s.sourceId == track.sourceId,
      orElse: () => _sources.first,
    );
    return source.resolveUrl(track);
  }

  void _notifyListeners() {
    for (final controller in _searchControllers) {
      if (!controller.isClosed) {
        controller.add(_lastResults);
      }
    }
  }

  Future<void> dispose() async {
    for (final controller in _searchControllers) {
      await controller.close();
    }
  }
}
