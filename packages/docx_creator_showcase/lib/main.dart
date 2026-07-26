import 'package:flutter/material.dart';

import 'screens/builder_screen.dart';
import 'screens/html_screen.dart';
import 'screens/markdown_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/unicode_screen.dart';

void main() {
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'docx_creator Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E74B5),
        useMaterial3: true,
      ),
      home: const _Shell(),
    );
  }
}

class _NavEntry {
  const _NavEntry(this.icon, this.label, this.builder);
  final IconData icon;
  final String label;
  final Widget Function() builder;
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  late final List<_NavEntry> _entries = [
    _NavEntry(Icons.home_outlined, 'Overview',
        () => OverviewScreen(onNavigate: (i) => setState(() => _index = i))),
    _NavEntry(Icons.edit_note, 'Builder API', () => const BuilderScreen()),
    _NavEntry(Icons.language, 'HTML Parser', () => const HtmlScreen()),
    _NavEntry(Icons.article, 'Markdown Parser', () => const MarkdownScreen()),
    _NavEntry(
        Icons.folder_open, 'DOCX / PDF Readers', () => const ReaderScreen()),
    _NavEntry(Icons.translate, 'Unicode Fallback Font',
        () => const UnicodeScreen()),
  ];

  // Built once and reused across rebuilds: since IndexedStack receives the
  // *same* widget instances every time _index changes (identical objects,
  // not just equal), Flutter's element diffing skips rebuilding the
  // currently-hidden screens entirely. Calling entry.builder() inline inside
  // build() instead would reconstruct - and re-run build() for - all six
  // screens (including whichever export tab is active in each, which is
  // real synchronous DOCX/HTML/PDF generation work) on every single nav
  // click, which is what made switching screens feel stuck.
  late final List<Widget> _screens = [
    for (final entry in _entries) entry.builder(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final destinations = _entries
        .map((e) => NavigationRailDestination(
              icon: Icon(e.icon),
              label: Text(e.label),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('docx_creator Showcase'),
        centerTitle: false,
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: ListView(
                children: [
                  for (var i = 0; i < _entries.length; i++)
                    ListTile(
                      leading: Icon(_entries[i].icon),
                      title: Text(_entries[i].label),
                      selected: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: destinations,
            ),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}
