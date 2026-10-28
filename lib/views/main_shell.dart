import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/novel_model.dart';
import '../models/plugin_model.dart';
import '../models/voice_model.dart';
import '../widgets/empty_state.dart';
import 'browse_view.dart';
import 'home_view.dart';

/// Top-level navigation for the app.
///
/// Library and Browse are implemented; History and More remain honest
/// "coming soon" placeholders until their phases are added.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.novelsBox, this.pluginsBox, this.voicesBox});

  /// Optional box overrides for tests, forwarded to Library and Browse.
  final Box<NovelModel>? novelsBox;
  final Box<PluginModel>? pluginsBox;
  final Box<VoiceModel>? voicesBox;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _UpcomingSection _historySection = _UpcomingSection(
    icon: Icons.history_rounded,
    title: 'History is coming soon',
    message:
        'Recently read chapters and reading sessions will appear here in a '
        'later phase.',
  );

  static const _UpcomingSection _moreSection = _UpcomingSection(
    icon: Icons.tune_rounded,
    title: 'More is coming soon',
    message:
        'Reader settings, downloads, and app preferences will be added in a '
        'later phase.',
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: <Widget>[
            HomeView(
              novelsBox: widget.novelsBox,
              pluginsBox: widget.pluginsBox,
            ),
            _historySection,
            BrowseView(
              pluginsBox: widget.pluginsBox,
              voicesBox: widget.voicesBox,
              novelsBox: widget.novelsBox,
            ),
            _moreSection,
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Browse',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: EmptyState(icon: icon, title: title, message: message),
    );
  }
}
