import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/catalog_providers.dart'
    show musicSearchProvider;
import '../../presentation/providers/player_providers.dart'
    show playerProvider;
import '../../domain/entities/track.dart';

/// Real search page: searches all music sources in parallel.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Track> _results = const <Track>[];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = _controller.text.trim();
      if (query.isEmpty) {
        setState(() {
          _results = const <Track>[];
          _isSearching = false;
        });
        return;
      }
      _doSearch(query);
    });
  }

  Future<void> _doSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final service = ref.read(musicSearchProvider);
      final results = await service.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(musicSearchProvider);
    final sources = service.sources;

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜索歌曲 / 歌手 / 专辑',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          // Source chips
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const SizedBox(width: 4),
                ...sources.map((source) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text(
                        source.displayName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          // Results
          Expanded(
            child: _results.isEmpty && !_isSearching
                ? const Center(child: Text('输入关键词开始搜索'))
                : _isSearching
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : ListView.builder(
                        // 虚拟化优化
                        cacheExtent: 500.0, itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final track = _results[index];
                          return ListTile(
                            key: Key(
                                'search-${track.sourceId}-${track.id}'),
                            leading: Icon(Icons.music_note,
                                color: _getSourceColor(track.sourceId)),
                            title: Text(track.title),
                            subtitle: Text(
                              [
                                if (track.artist.isNotEmpty) track.artist,
                                if (track.album.isNotEmpty) track.album,
                              ].join(' · '),
                            ),
                            onTap: () async {
                              final service = ref.read(musicSearchProvider);
                              final player = ref.read(playerProvider.notifier);
                              final url = await service.resolveUrl(track);
                              if (!context.mounted) return;
                              if (url != null) {
                                await player.play(track, url);
                                if (!context.mounted) return;
                                context.go('/player');
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('无法获取播放地址')),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getSourceColor(String sourceId) {
    switch (sourceId) {
      case 'netease':
        return const Color(0xFFE60026);
      case 'qq':
        return const Color(0xFF0099E8);
      case 'kuwo':
        return const Color(0xFFC40000);
      default:
        return Colors.grey;
    }
  }
}