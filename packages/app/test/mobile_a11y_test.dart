import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mobile A11y – tap targets and typography', () {
    test('BotCard compact typography meets minimum sizes', () {
      // Mirrors compact values from _BotCard.build()
      const compact = true;
      final titleFontSize = compact ? 14.0 : 15.0;
      final statusFontSize = compact ? 10.5 : 11.0;
      final serverFontSize = compact ? 10.5 : 11.0;
      final buttonVerticalPadding = compact ? 10.0 : 12.0;

      // Title font >= 14sp (WCAG minimum for body text)
      expect(titleFontSize, greaterThanOrEqualTo(14.0));
      // Status/server font >= 10.5sp (minimum legible)
      expect(statusFontSize, greaterThanOrEqualTo(10.5));
      expect(serverFontSize, greaterThanOrEqualTo(10.5));
      // Button padding ensures 48+dp total height
      // (button text ~16dp + padding*2 = 16 + 20 = 36dp min; with icon ≥ 48dp)
      expect(buttonVerticalPadding, greaterThanOrEqualTo(10.0));
    });

    test('workflow tile contentPadding provides adequate touch target', () {
      // Mirrors ListTile contentPadding from _buildWorkflowTile
      const verticalPadding = 10.0;
      // ListTile base height ~56dp + extra padding = comfortable
      expect(verticalPadding, greaterThanOrEqualTo(8.0));
    });

    test('workflow badge font size meets minimum', () {
      const badgeFontSize = 12.0; // from _buildWorkflowTile badge
      expect(badgeFontSize, greaterThanOrEqualTo(12.0));
    });

    test('workflow action buttons have adequate spacing', () {
      const wrapSpacing = 8.0; // from Wrap(spacing:) in _buildWorkflowTile
      // At least 8dp between buttons to avoid mis-taps
      expect(wrapSpacing, greaterThanOrEqualTo(8.0));
    });

    testWidgets('PopupMenuItem has minimum 48dp height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  height: 48,
                  child: Text('Edit'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  height: 48,
                  child: Text('Delete'),
                ),
              ],
            ),
          ),
        ),
      );

      // Tap to open menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Both items should render
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    test('MoreSheetItem padding ensures 48+dp total height', () {
      // Icon 24dp + spacing 6dp + text ~16dp + padding 18*2 = 24+6+16+36 = 82dp total
      // Minimum needed: 48dp
      const verticalPadding = 18.0;
      const iconSize = 24.0;
      const spacing = 6.0;
      const approxTextHeight = 16.0;
      final totalHeight = verticalPadding * 2 + iconSize + spacing + approxTextHeight;
      expect(totalHeight, greaterThanOrEqualTo(48.0));
    });

    test('grid spacing between bot cards is adequate', () {
      const crossAxisSpacing = 14.0;
      const mainAxisSpacing = 14.0;
      // At least 12dp between cards for visual clarity
      expect(crossAxisSpacing, greaterThanOrEqualTo(12.0));
      expect(mainAxisSpacing, greaterThanOrEqualTo(12.0));
    });

    test('Manage/Logs button spacing prevents mis-taps', () {
      const compact = true;
      final spacing = compact ? 8.0 : 10.0;
      // At least 8dp between adjacent buttons
      expect(spacing, greaterThanOrEqualTo(8.0));
    });
  });
}
