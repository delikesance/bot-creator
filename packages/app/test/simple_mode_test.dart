import 'package:bot_creator/utils/simple_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxx/nyxx.dart';

String _translate(String key) => key;

SimpleModeConfig _config({
  bool deleteMessages = false,
  bool kickUser = false,
  bool banUser = false,
  bool unbanUser = false,
  bool muteUser = false,
  bool unmuteUser = false,
  bool addRole = false,
  bool removeRole = false,
  bool sendMessage = false,
  bool pinMessage = false,
  bool unpinMessage = false,
  bool createInvite = false,
  bool createPoll = false,
  String sendMessageText = '',
  String actionReason = '',
  String muteDuration = '10m',
  String banDeleteMessageDays = '0',
  String deleteMessagesDefaultCount = '1',
  String inviteMaxAge = '86400',
  String inviteMaxUses = '0',
  bool inviteTemporary = false,
  bool inviteUnique = false,
  String pollAnswersText = 'Yes\nNo',
  String pollDurationHours = '24',
  bool pollAllowMultiselect = false,
}) {
  return SimpleModeConfig(
    deleteMessages: deleteMessages,
    kickUser: kickUser,
    banUser: banUser,
    unbanUser: unbanUser,
    muteUser: muteUser,
    unmuteUser: unmuteUser,
    addRole: addRole,
    removeRole: removeRole,
    sendMessage: sendMessage,
    pinMessage: pinMessage,
    unpinMessage: unpinMessage,
    createInvite: createInvite,
    createPoll: createPoll,
    sendMessageText: sendMessageText,
    actionReason: actionReason,
    muteDuration: muteDuration,
    banDeleteMessageDays: banDeleteMessageDays,
    deleteMessagesDefaultCount: deleteMessagesDefaultCount,
    inviteMaxAge: inviteMaxAge,
    inviteMaxUses: inviteMaxUses,
    inviteTemporary: inviteTemporary,
    inviteUnique: inviteUnique,
    pollAnswersText: pollAnswersText,
    pollDurationHours: pollDurationHours,
    pollAllowMultiselect: pollAllowMultiselect,
  );
}

void main() {
  group('buildSimpleModeOptions', () {
    test('reuses shared generated options and keeps deterministic order', () {
      final options = buildSimpleModeOptions(
        _config(
          deleteMessages: true,
          kickUser: true,
          banUser: true,
          unmuteUser: true,
          addRole: true,
          removeRole: true,
          unbanUser: true,
          pinMessage: true,
          createInvite: true,
          createPoll: true,
        ),
        translate: _translate,
      );

      expect(options.map((option) => option.name).toList(), <String>[
        'user',
        'role',
        'count',
        'user_id',
        'message_id',
        'channel',
        'question',
      ]);

      expect(options.where((option) => option.name == 'user'), hasLength(1));
      expect(options.where((option) => option.name == 'role'), hasLength(1));
      expect(
        options.where((option) => option.name == 'message_id'),
        hasLength(1),
      );
      expect(options[0].type, CommandOptionType.user);
      expect(options[1].type, CommandOptionType.role);
      expect(options[2].type, CommandOptionType.integer);
      expect(options[2].isRequired, isFalse);
      expect(options[2].minValue, 1);
      expect(options[2].maxValue, 100);
      expect(options[5].type, CommandOptionType.channel);
      expect(options[5].isRequired, isFalse);
      expect(options[6].type, CommandOptionType.string);
      expect(options[6].isRequired, isTrue);
    });
  });

  group('buildSimpleModeActions', () {
    test('maps new guided actions to advanced payloads', () {
      final actions = buildSimpleModeActions(
        _config(
          unbanUser: true,
          pinMessage: true,
          createInvite: true,
          createPoll: true,
          actionReason: 'Simple mode',
          inviteMaxAge: '3600',
          inviteMaxUses: '5',
          inviteTemporary: true,
          inviteUnique: true,
          pollAnswersText: 'Red\nBlue\nGreen',
          pollDurationHours: '12',
          pollAllowMultiselect: true,
        ),
      );

      expect(actions.map((action) => action['type']).toList(), <String>[
        'unbanUser',
        'pinMessage',
        'createInvite',
        'createPoll',
      ]);

      final unbanPayload = Map<String, dynamic>.from(
        actions[0]['payload'] as Map,
      );
      expect(unbanPayload['userId'], '((opts.user_id))');
      expect(unbanPayload['reason'], 'Simple mode');

      final pinPayload = Map<String, dynamic>.from(
        actions[1]['payload'] as Map,
      );
      expect(pinPayload['channelId'], '');
      expect(pinPayload['messageId'], '((opts.message_id))');
      expect(pinPayload['reason'], 'Simple mode');

      final invitePayload = Map<String, dynamic>.from(
        actions[2]['payload'] as Map,
      );
      expect(invitePayload['channelId'], '((opts.channel.id|channelId))');
      expect(invitePayload['maxAge'], 3600);
      expect(invitePayload['maxUses'], 5);
      expect(invitePayload['temporary'], isTrue);
      expect(invitePayload['unique'], isTrue);
      expect(invitePayload['reason'], 'Simple mode');

      final pollPayload = Map<String, dynamic>.from(
        actions[3]['payload'] as Map,
      );
      expect(pollPayload['channelId'], '');
      expect(pollPayload['question'], '((opts.question))');
      expect(pollPayload['answers'], <String>['Red', 'Blue', 'Green']);
      expect(pollPayload['durationHours'], 12);
      expect(pollPayload['allowMultiselect'], isTrue);
    });
  });

  group('validateSimpleModeConfig', () {
    test('requires send message text when send message is enabled', () {
      final error = validateSimpleModeConfig(
        _config(sendMessage: true),
        translate: _translate,
      );

      expect(error, 'cmd_simple_send_message_required');
    });

    test('rejects contradictory action pairs', () {
      final error = validateSimpleModeConfig(
        _config(banUser: true, unbanUser: true),
        translate: _translate,
      );

      expect(error, 'cmd_simple_conflict_ban_unban');
    });

    test('validates invite numeric ranges', () {
      final error = validateSimpleModeConfig(
        _config(createInvite: true, inviteMaxAge: '9999999'),
        translate: _translate,
      );

      expect(error, 'cmd_simple_invite_max_age_invalid');
    });

    test('validates poll answer count and duration', () {
      final answersError = validateSimpleModeConfig(
        _config(createPoll: true, pollAnswersText: 'Only one'),
        translate: _translate,
      );
      final durationError = validateSimpleModeConfig(
        _config(
          createPoll: true,
          pollAnswersText: 'Yes\nNo',
          pollDurationHours: '0',
        ),
        translate: _translate,
      );

      expect(answersError, 'cmd_simple_poll_answers_invalid');
      expect(durationError, 'cmd_simple_poll_duration_invalid');
    });
  });
}
