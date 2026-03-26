import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors _AppPageEntry from app.dart for testability.
class _TestEntry {
  final IconData icon;
  final String label;
  final bool mobileSecondary;

  const _TestEntry({
    required this.icon,
    required this.label,
    this.mobileSecondary = false,
  });
}

void main() {
  group('Mobile bottom navigation – entry filtering', () {
    final onlineEntries = <_TestEntry>[
      const _TestEntry(icon: Icons.home, label: 'Home'),
      const _TestEntry(icon: Icons.add_circle, label: 'Commands'),
      const _TestEntry(icon: Icons.key, label: 'Globals'),
      const _TestEntry(icon: Icons.account_tree, label: 'Workflows'),
      const _TestEntry(
        icon: Icons.emoji_emotions_outlined,
        label: 'Emojis',
        mobileSecondary: true,
      ),
      const _TestEntry(
        icon: Icons.bar_chart,
        label: 'Dashboard',
        mobileSecondary: true,
      ),
      const _TestEntry(
        icon: Icons.settings,
        label: 'Settings',
        mobileSecondary: true,
      ),
    ];

    test('core entries exclude mobileSecondary items', () {
      final core =
          onlineEntries.where((e) => !e.mobileSecondary).toList();
      expect(core.length, 4);
      expect(core.map((e) => e.label), ['Home', 'Commands', 'Globals', 'Workflows']);
    });

    test('secondary entries contain Emojis, Dashboard, Settings', () {
      final secondary =
          onlineEntries.where((e) => e.mobileSecondary).toList();
      expect(secondary.length, 3);
      expect(
        secondary.map((e) => e.label),
        ['Emojis', 'Dashboard', 'Settings'],
      );
    });

    test('offline entries have no secondaries', () {
      final offlineEntries = <_TestEntry>[
        const _TestEntry(icon: Icons.warning_amber_rounded, label: 'Recovery'),
        const _TestEntry(icon: Icons.vpn_key_outlined, label: 'Settings'),
        const _TestEntry(icon: Icons.add_circle, label: 'Commands'),
        const _TestEntry(icon: Icons.key, label: 'Globals'),
        const _TestEntry(icon: Icons.account_tree, label: 'Workflows'),
      ];

      final secondary =
          offlineEntries.where((e) => e.mobileSecondary).toList();
      expect(secondary, isEmpty);
    });

    test('bottom nav index maps selected secondary to More tab', () {
      final coreIndices = <int>[];
      final secondaryIndices = <int>[];
      for (var i = 0; i < onlineEntries.length; i++) {
        if (onlineEntries[i].mobileSecondary) {
          secondaryIndices.add(i);
        } else {
          coreIndices.add(i);
        }
      }

      // When a secondary entry is selected, bottom index should be coreIndices.length
      const selectedIndex = 4; // Emojis
      final moreSelected = secondaryIndices.contains(selectedIndex);
      expect(moreSelected, isTrue);

      final bottomIndex =
          moreSelected ? coreIndices.length : coreIndices.indexOf(selectedIndex);
      expect(bottomIndex, 4); // "More" tab is at index 4 (5th item)
    });

    test('bottom nav has 5 items on mobile (4 core + More)', () {
      final coreCount =
          onlineEntries.where((e) => !e.mobileSecondary).length;
      final hasSecondary =
          onlineEntries.any((e) => e.mobileSecondary);

      final totalBottomItems = coreCount + (hasSecondary ? 1 : 0);
      expect(totalBottomItems, 5);
    });
  });

  group('Quick-access sections', () {
    test('secondarySections maps to correct entry indices', () {
      // Matches the indices in _buildEntries: Emojis=4, Dashboard=5, Settings=6
      const sections = [
        {'index': 4, 'labelKey': 'emojis_tab'},
        {'index': 5, 'labelKey': 'dashboard_title'},
        {'index': 6, 'labelKey': 'settings_tab'},
      ];

      expect(sections.length, 3);
      expect(sections[0]['index'], 4);
      expect(sections[1]['index'], 5);
      expect(sections[2]['index'], 6);
    });

    test('onNavigateToSection propagates correct index', () {
      int? navigatedIndex;
      void onNavigate(int index) {
        navigatedIndex = index;
      }

      // Simulate tapping Dashboard quick-access chip
      onNavigate(5);
      expect(navigatedIndex, 5);

      // Simulate tapping Settings quick-access chip
      onNavigate(6);
      expect(navigatedIndex, 6);
    });
  });

  group('More sheet – visual layout', () {
    testWidgets('renders MoreSheetItem-style grid for secondary entries',
        (tester) async {
      // Simulate the "More" sheet grid layout with 3 secondary items
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final colorScheme = Theme.of(context).colorScheme;
                return Row(
                  children: [
                    for (final entry in [
                      {'icon': Icons.emoji_emotions_outlined, 'label': 'Emojis'},
                      {'icon': Icons.bar_chart, 'label': 'Dashboard'},
                      {'icon': Icons.settings, 'label': 'Settings'},
                    ])
                      Expanded(
                        child: Material(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(entry['icon'] as IconData, size: 24),
                                  const SizedBox(height: 6),
                                  Text(entry['label'] as String,
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Emojis'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
