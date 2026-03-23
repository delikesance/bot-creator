import 'package:bot_creator/routes/app/command_option_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxx/nyxx.dart';

CommandOptionBuilder _opt(
  CommandOptionType type,
  String name, {
  String description = 'desc',
  bool? isRequired,
  List<CommandOptionBuilder>? options,
  List<CommandOptionChoiceBuilder>? choices,
  num? minValue,
  num? maxValue,
}) {
  final b = CommandOptionBuilder(
    type: type,
    name: name,
    description: description,
    isRequired: isRequired ?? false,
    minValue: minValue,
    maxValue: maxValue,
  );
  if (options != null) b.options = options;
  if (choices != null) b.choices = choices;
  return b;
}

void main() {
  group('validateOptionsForLevel', () {
    // ── Valid cases ──────────────────────────────────────────────────────────

    test('valid flat command (only leaf options)', () {
      final options = [
        _opt(CommandOptionType.string, 'msg', isRequired: true),
        _opt(CommandOptionType.user, 'target'),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        isNull,
      );
    });

    test('valid subcommand-only root', () {
      final options = [
        _opt(CommandOptionType.subCommand, 'ping', options: []),
        _opt(CommandOptionType.subCommand, 'pong', options: []),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        isNull,
      );
    });

    test('valid group/subcommand tree', () {
      final options = [
        _opt(
          CommandOptionType.subCommandGroup,
          'admin',
          options: [
            _opt(
              CommandOptionType.subCommand,
              'ban',
              options: [
                _opt(CommandOptionType.user, 'target', isRequired: true),
              ],
            ),
            _opt(CommandOptionType.subCommand, 'kick', options: []),
          ],
        ),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        isNull,
      );
    });

    test('empty option list is valid', () {
      expect(validateOptionsForLevel([], level: 0, parentType: null), isNull);
    });

    // ── Cardinalité ──────────────────────────────────────────────────────────

    test('rejects more than 25 options at the same level', () {
      final options = List.generate(
        26,
        (i) => _opt(CommandOptionType.string, 'opt$i'),
      );
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('25'),
      );
    });

    // ── Mélange root flat + subcommands ──────────────────────────────────────

    test('rejects mix of subcommands and leaf options at root', () {
      final options = [
        _opt(CommandOptionType.subCommand, 'ping', options: []),
        _opt(CommandOptionType.string, 'extra'),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('mix'),
      );
    });

    // ── Contraintes de contenu des groupes ───────────────────────────────────

    test('rejects non-subCommand inside a subCommandGroup', () {
      final options = [_opt(CommandOptionType.string, 'bad')];
      expect(
        validateOptionsForLevel(
          options,
          level: 1,
          parentType: CommandOptionType.subCommandGroup,
        ),
        contains('SubCommandGroup'),
      );
    });

    test('rejects hierarchy type inside a subCommand', () {
      final options = [
        _opt(CommandOptionType.subCommand, 'nested', options: []),
      ];
      expect(
        validateOptionsForLevel(
          options,
          level: 1,
          parentType: CommandOptionType.subCommand,
        ),
        contains('SubCommand cannot contain nested'),
      );
    });

    // ── Profondeur maximale ───────────────────────────────────────────────────

    test('rejects subCommandGroup at level > 0', () {
      final nested = [
        _opt(CommandOptionType.subCommandGroup, 'deep', options: []),
      ];
      expect(
        validateOptionsForLevel(nested, level: 1, parentType: null),
        contains('top level'),
      );
    });

    test('rejects subCommand at level > 1 (detected via recursive call)', () {
      // group -> subCommand -> subCommand  (level 2 subcommand is illegal)
      final options = [
        _opt(
          CommandOptionType.subCommandGroup,
          'g',
          options: [
            _opt(
              CommandOptionType.subCommand,
              'sub',
              options: [
                _opt(CommandOptionType.subCommand, 'deepsub', options: []),
              ],
            ),
          ],
        ),
      ];
      // The recursive call will surface the error.
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        isNotNull,
      );
    });

    // ── Noms dupliqués ───────────────────────────────────────────────────────

    test('rejects duplicate option names at the same level', () {
      final options = [
        _opt(CommandOptionType.string, 'msg'),
        _opt(CommandOptionType.string, 'msg'),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('Duplicate'),
      );
    });

    // ── Nom/description manquants ─────────────────────────────────────────────

    test('rejects option with empty name', () {
      final options = [
        _opt(CommandOptionType.string, '', description: 'some desc'),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('name'),
      );
    });

    test('rejects option with empty description', () {
      final options = [_opt(CommandOptionType.string, 'msg', description: '')];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('description'),
      );
    });

    // ── Contraintes isRequired / choices / minMax sur types hiérarchiques ─────

    test('rejects isRequired=true on a subCommand', () {
      final options = [
        _opt(
          CommandOptionType.subCommand,
          'ping',
          isRequired: true,
          options: [],
        ),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('required'),
      );
    });

    test('rejects choices on a subCommandGroup', () {
      final options = [
        _opt(
          CommandOptionType.subCommandGroup,
          'admin',
          choices: [CommandOptionChoiceBuilder(name: 'x', value: 'x')],
          options: [],
        ),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('choices'),
      );
    });

    test('rejects minValue on a subCommand', () {
      final options = [
        _opt(CommandOptionType.subCommand, 'ping', minValue: 1, options: []),
      ];
      expect(
        validateOptionsForLevel(options, level: 0, parentType: null),
        contains('min/max'),
      );
    });
  });
}
