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
}
