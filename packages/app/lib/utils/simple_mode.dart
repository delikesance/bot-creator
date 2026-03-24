import 'package:nyxx/nyxx.dart';

class SimpleModeConfig {
  const SimpleModeConfig({
    required this.deleteMessages,
    required this.kickUser,
    required this.banUser,
    required this.unbanUser,
    required this.muteUser,
    required this.unmuteUser,
    required this.addRole,
    required this.removeRole,
    required this.sendMessage,
    required this.pinMessage,
    required this.unpinMessage,
    required this.createInvite,
    required this.createPoll,
    required this.sendMessageText,
    required this.actionReason,
    required this.muteDuration,
    required this.banDeleteMessageDays,
    required this.deleteMessagesDefaultCount,
    required this.inviteMaxAge,
    required this.inviteMaxUses,
    required this.inviteTemporary,
    required this.inviteUnique,
    required this.pollAnswersText,
    required this.pollDurationHours,
    required this.pollAllowMultiselect,
  });

  final bool deleteMessages;
  final bool kickUser;
  final bool banUser;
  final bool unbanUser;
  final bool muteUser;
  final bool unmuteUser;
  final bool addRole;
  final bool removeRole;
  final bool sendMessage;
  final bool pinMessage;
  final bool unpinMessage;
  final bool createInvite;
  final bool createPoll;
  final String sendMessageText;
  final String actionReason;
  final String muteDuration;
  final String banDeleteMessageDays;
  final String deleteMessagesDefaultCount;
  final String inviteMaxAge;
  final String inviteMaxUses;
  final bool inviteTemporary;
  final bool inviteUnique;
  final String pollAnswersText;
  final String pollDurationHours;
  final bool pollAllowMultiselect;

  factory SimpleModeConfig.fromJson(Map<String, dynamic> input) {
    return SimpleModeConfig(
      deleteMessages: input['deleteMessages'] == true,
      kickUser: input['kickUser'] == true,
      banUser: input['banUser'] == true,
      unbanUser: input['unbanUser'] == true,
      muteUser: input['muteUser'] == true,
      unmuteUser: input['unmuteUser'] == true,
      addRole: input['addRole'] == true,
      removeRole: input['removeRole'] == true,
      sendMessage: input['sendMessage'] == true,
      pinMessage: input['pinMessage'] == true,
      unpinMessage: input['unpinMessage'] == true,
      createInvite: input['createInvite'] == true,
      createPoll: input['createPoll'] == true,
      sendMessageText: (input['sendMessageText'] ?? '').toString(),
      actionReason: (input['actionReason'] ?? '').toString(),
      muteDuration: (input['muteDuration'] ?? '10m').toString(),
      banDeleteMessageDays: (input['banDeleteMessageDays'] ?? '0').toString(),
      deleteMessagesDefaultCount:
          (input['deleteMessagesDefaultCount'] ?? '1').toString(),
      inviteMaxAge: (input['inviteMaxAge'] ?? '86400').toString(),
      inviteMaxUses: (input['inviteMaxUses'] ?? '0').toString(),
      inviteTemporary: input['inviteTemporary'] == true,
      inviteUnique: input['inviteUnique'] == true,
      pollAnswersText: (input['pollAnswersText'] ?? 'Yes\nNo').toString(),
      pollDurationHours: (input['pollDurationHours'] ?? '24').toString(),
      pollAllowMultiselect: input['pollAllowMultiselect'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deleteMessages': deleteMessages,
      'kickUser': kickUser,
      'banUser': banUser,
      'unbanUser': unbanUser,
      'muteUser': muteUser,
      'unmuteUser': unmuteUser,
      'addRole': addRole,
      'removeRole': removeRole,
      'sendMessage': sendMessage,
      'pinMessage': pinMessage,
      'unpinMessage': unpinMessage,
      'createInvite': createInvite,
      'createPoll': createPoll,
      'sendMessageText': sendMessageText,
      'actionReason': actionReason,
      'muteDuration': muteDuration,
      'banDeleteMessageDays': banDeleteMessageDays,
      'deleteMessagesDefaultCount': deleteMessagesDefaultCount,
      'inviteMaxAge': inviteMaxAge,
      'inviteMaxUses': inviteMaxUses,
      'inviteTemporary': inviteTemporary,
      'inviteUnique': inviteUnique,
      'pollAnswersText': pollAnswersText,
      'pollDurationHours': pollDurationHours,
      'pollAllowMultiselect': pollAllowMultiselect,
    };
  }

  bool get requiresUserOption =>
      kickUser || banUser || muteUser || unmuteUser || addRole || removeRole;

  bool get requiresRoleOption => addRole || removeRole;

  bool get requiresCountOption => deleteMessages;

  bool get requiresUserIdOption => unbanUser;

  bool get requiresMessageIdOption => pinMessage || unpinMessage;

  bool get requiresChannelOption => createInvite;

  bool get requiresQuestionOption => createPoll;

  bool get hasAuditReasonAction =>
      deleteMessages ||
      kickUser ||
      banUser ||
      unbanUser ||
      muteUser ||
      unmuteUser ||
      addRole ||
      removeRole ||
      pinMessage ||
      unpinMessage ||
      createInvite;
}

Map<String, dynamic> normalizeSimpleModeConfigMap(Map<String, dynamic> input) {
  return SimpleModeConfig.fromJson(input).toJson();
}

List<String> parseSimpleModePollAnswers(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }

  final source =
      normalized.contains('\n')
          ? normalized.split('\n')
          : normalized.split(',');

  return source
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

List<CommandOptionBuilder> buildSimpleModeOptions(
  SimpleModeConfig config, {
  required String Function(String key) translate,
}) {
  final options = <CommandOptionBuilder>[];

  if (config.requiresUserOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.user,
        name: 'user',
        description: translate('cmd_simple_option_user_desc'),
        isRequired: true,
      ),
    );
  }

  if (config.requiresRoleOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.role,
        name: 'role',
        description: translate('cmd_simple_option_role_desc'),
        isRequired: true,
      ),
    );
  }

  if (config.requiresCountOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.integer,
        name: 'count',
        description: translate('cmd_simple_option_count_desc'),
        isRequired: false,
        minValue: 1,
        maxValue: 100,
      ),
    );
  }

  if (config.requiresUserIdOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.string,
        name: 'user_id',
        description: translate('cmd_simple_option_user_id_desc'),
        isRequired: true,
      ),
    );
  }

  if (config.requiresMessageIdOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.string,
        name: 'message_id',
        description: translate('cmd_simple_option_message_id_desc'),
        isRequired: true,
      ),
    );
  }

  if (config.requiresChannelOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.channel,
        name: 'channel',
        description: translate('cmd_simple_option_channel_desc'),
        isRequired: false,
      ),
    );
  }

  if (config.requiresQuestionOption) {
    options.add(
      CommandOptionBuilder(
        type: CommandOptionType.string,
        name: 'question',
        description: translate('cmd_simple_option_question_desc'),
        isRequired: true,
      ),
    );
  }

  return options;
}

List<String> buildSimpleModeGeneratedOptionLabels(
  SimpleModeConfig config, {
  required String Function(String key) translate,
}) {
  final labels = <String>[];
  if (config.requiresUserOption) {
    labels.add(translate('cmd_simple_option_user'));
  }
  if (config.requiresRoleOption) {
    labels.add(translate('cmd_simple_option_role'));
  }
  if (config.requiresCountOption) {
    labels.add(translate('cmd_simple_option_count'));
  }
  if (config.requiresUserIdOption) {
    labels.add(translate('cmd_simple_option_user_id'));
  }
  if (config.requiresMessageIdOption) {
    labels.add(translate('cmd_simple_option_message_id'));
  }
  if (config.requiresChannelOption) {
    labels.add(translate('cmd_simple_option_channel'));
  }
  if (config.requiresQuestionOption) {
    labels.add(translate('cmd_simple_option_question'));
  }
  return labels;
}

List<Map<String, dynamic>> buildSimpleModeActions(SimpleModeConfig config) {
  final actions = <Map<String, dynamic>>[];
  final actionReason = config.actionReason.trim();
  final muteDuration =
      config.muteDuration.trim().isEmpty ? '10m' : config.muteDuration.trim();
  final deleteMessagesDefaultCount =
      (int.tryParse(config.deleteMessagesDefaultCount.trim()) ?? 1).clamp(
        1,
        100,
      );
  final banDeleteMessageDays =
      (int.tryParse(config.banDeleteMessageDays.trim()) ?? 0).clamp(0, 7);
  final inviteMaxAge = (int.tryParse(config.inviteMaxAge.trim()) ?? 86400)
      .clamp(0, 604800);
  final inviteMaxUses = (int.tryParse(config.inviteMaxUses.trim()) ?? 0).clamp(
    0,
    1000000,
  );
  final pollDurationHours =
      (int.tryParse(config.pollDurationHours.trim()) ?? 24).clamp(1, 168);
  final pollAnswers = parseSimpleModePollAnswers(config.pollAnswersText);

  Map<String, dynamic> makeAction({
    required String key,
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return {
      'id': key,
      'type': type,
      'enabled': true,
      'key': key,
      'depend_on': <String>[],
      'error': {'mode': 'stop'},
      'payload': payload,
    };
  }

  if (config.deleteMessages) {
    actions.add(
      makeAction(
        key: 'delete_messages',
        type: 'deleteMessages',
        payload: {
          'channelId': '',
          'messageCount': '((opts.count | $deleteMessagesDefaultCount))',
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.kickUser) {
    actions.add(
      makeAction(
        key: 'kick_user',
        type: 'kickUser',
        payload: {'userId': '((opts.user.id))', 'reason': actionReason},
      ),
    );
  }

  if (config.banUser) {
    actions.add(
      makeAction(
        key: 'ban_user',
        type: 'banUser',
        payload: {
          'userId': '((opts.user.id))',
          'reason': actionReason,
          'deleteMessageDays': banDeleteMessageDays,
        },
      ),
    );
  }

  if (config.unbanUser) {
    actions.add(
      makeAction(
        key: 'unban_user',
        type: 'unbanUser',
        payload: {'userId': '((opts.user_id))', 'reason': actionReason},
      ),
    );
  }

  if (config.muteUser) {
    actions.add(
      makeAction(
        key: 'mute_user',
        type: 'muteUser',
        payload: {
          'userId': '((opts.user.id))',
          'duration': muteDuration,
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.unmuteUser) {
    actions.add(
      makeAction(
        key: 'unmute_user',
        type: 'unmuteUser',
        payload: {'userId': '((opts.user.id))', 'reason': actionReason},
      ),
    );
  }

  if (config.addRole) {
    actions.add(
      makeAction(
        key: 'add_role',
        type: 'addRole',
        payload: {
          'userId': '((opts.user.id))',
          'roleId': '((opts.role.id))',
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.removeRole) {
    actions.add(
      makeAction(
        key: 'remove_role',
        type: 'removeRole',
        payload: {
          'userId': '((opts.user.id))',
          'roleId': '((opts.role.id))',
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.sendMessage) {
    actions.add(
      makeAction(
        key: 'send_message',
        type: 'sendMessage',
        payload: {'channelId': '', 'content': config.sendMessageText.trim()},
      ),
    );
  }

  if (config.pinMessage) {
    actions.add(
      makeAction(
        key: 'pin_message',
        type: 'pinMessage',
        payload: {
          'channelId': '',
          'messageId': '((opts.message_id))',
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.unpinMessage) {
    actions.add(
      makeAction(
        key: 'unpin_message',
        type: 'unpinMessage',
        payload: {
          'channelId': '',
          'messageId': '((opts.message_id))',
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.createInvite) {
    actions.add(
      makeAction(
        key: 'create_invite',
        type: 'createInvite',
        payload: {
          'channelId': '((opts.channel.id|channelId))',
          'maxAge': inviteMaxAge,
          'maxUses': inviteMaxUses,
          'temporary': config.inviteTemporary,
          'unique': config.inviteUnique,
          'reason': actionReason,
        },
      ),
    );
  }

  if (config.createPoll) {
    actions.add(
      makeAction(
        key: 'create_poll',
        type: 'createPoll',
        payload: {
          'channelId': '',
          'question': '((opts.question))',
          'answers': pollAnswers,
          'durationHours': pollDurationHours,
          'allowMultiselect': config.pollAllowMultiselect,
        },
      ),
    );
  }

  return actions;
}

String? validateSimpleModeConfig(
  SimpleModeConfig config, {
  required String Function(String key) translate,
}) {
  if (config.sendMessage && config.sendMessageText.trim().isEmpty) {
    return translate('cmd_simple_send_message_required');
  }

  if (config.banUser && config.unbanUser) {
    return translate('cmd_simple_conflict_ban_unban');
  }
  if (config.muteUser && config.unmuteUser) {
    return translate('cmd_simple_conflict_mute_unmute');
  }
  if (config.pinMessage && config.unpinMessage) {
    return translate('cmd_simple_conflict_pin_unpin');
  }

  final inviteMaxAge = int.tryParse(config.inviteMaxAge.trim());
  if (config.createInvite &&
      (inviteMaxAge == null || inviteMaxAge < 0 || inviteMaxAge > 604800)) {
    return translate('cmd_simple_invite_max_age_invalid');
  }

  final inviteMaxUses = int.tryParse(config.inviteMaxUses.trim());
  if (config.createInvite &&
      (inviteMaxUses == null || inviteMaxUses < 0 || inviteMaxUses > 1000000)) {
    return translate('cmd_simple_invite_max_uses_invalid');
  }

  final pollAnswers = parseSimpleModePollAnswers(config.pollAnswersText);
  if (config.createPoll &&
      (pollAnswers.length < 2 || pollAnswers.length > 10)) {
    return translate('cmd_simple_poll_answers_invalid');
  }

  final pollDuration = int.tryParse(config.pollDurationHours.trim());
  if (config.createPoll &&
      (pollDuration == null || pollDuration < 1 || pollDuration > 168)) {
    return translate('cmd_simple_poll_duration_invalid');
  }

  return null;
}
