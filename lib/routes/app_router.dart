import 'package:go_router/go_router.dart';
import 'package:q_audio/presentation/widgets/app_shell.dart';
import 'package:q_audio/presentation/pages/home_page.dart';
import 'package:q_audio/presentation/pages/search_page.dart';
import 'package:q_audio/presentation/pages/radio_page.dart';
import 'package:q_audio/presentation/pages/audiobook_page.dart';
import 'package:q_audio/presentation/pages/podcast_page.dart';
import 'package:q_audio/presentation/pages/local_page.dart';
import 'package:q_audio/presentation/pages/playlist_page.dart';
import 'package:q_audio/presentation/pages/download_page.dart';
import 'package:q_audio/presentation/pages/settings_page.dart';
import 'package:q_audio/presentation/pages/player_page.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchPage(),
            ),
            GoRoute(
                path: '/radio', builder: (context, state) => const RadioPage()),
            GoRoute(
              path: '/audiobook',
              builder: (context, state) => const AudiobookPage(),
            ),
            GoRoute(
              path: '/podcast',
              builder: (context, state) => const PodcastPage(),
            ),
            GoRoute(
                path: '/local', builder: (context, state) => const LocalPage()),
            GoRoute(
              path: '/playlist',
              builder: (context, state) => const PlaylistPage(),
            ),
            GoRoute(
              path: '/downloads',
              builder: (context, state) => const DownloadPage(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
        // Full-screen player page (outside shell for full-screen experience)
        GoRoute(
          path: '/player',
          builder: (context, state) => const PlayerPage(),
        ),
      ],
    );
