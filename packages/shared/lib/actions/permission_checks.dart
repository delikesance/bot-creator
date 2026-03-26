import 'package:nyxx/nyxx.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Computes the combined permissions of the bot in [guild] by merging the
/// permissions of each of its roles (+ the @everyone role).
Future<Permissions> _computeBotPermissions(
  Guild guild,
  Snowflake guildId,
) async {
  final botMember = await guild.fetchCurrentMember();
  return _permissionsFromRoles(guild, botMember.roleIds, guildId);
}

Permissions _permissionsFromRoles(
  Guild guild,
  List<Snowflake> roleIds,
  Snowflake guildId,
) {
  return Permissions(
    guild.roleList
        .where((r) => roleIds.contains(r.id) || r.id == guildId)
        .fold<int>(0, (acc, r) => acc | r.permissions.value),
  );
}

// ── Simple permission check (no role hierarchy) ─────────────────────────────

/// Checks that the bot has **all** of the given [requiredPermissions] in
/// the guild identified by [guildId].
///
/// Returns an error string if any permission is missing, or `null` if the
/// bot is authorised.
Future<String?> checkBotGuildPermission(
  NyxxGateway client, {
  required Snowflake guildId,
  required List<Flag<Permissions>> requiredPermissions,
  required String actionLabel,
}) async {
  final guild = await client.guilds.fetch(guildId);
  final perms = await _computeBotPermissions(guild, guildId);

  if (perms.isAdministrator) return null;

  final missing = <String>[];
  for (final perm in requiredPermissions) {
    if (!perms.has(perm)) {
      missing.add(_permissionName(perm));
    }
  }

  if (missing.isEmpty) return null;
  return 'I do not have permission to $actionLabel. '
      'Missing: ${missing.join(', ')}.';
}

// ── Moderation check (permissions + role hierarchy) ─────────────────────────

/// Checks whether the bot can moderate [targetUserId] in the given guild.
///
/// Returns an error string if the action should be blocked, or `null` if
/// the bot is authorised to proceed.
///
/// Checks performed:
/// 1. Bot has the required [requiredPermission] (e.g. ban/kick/moderate).
/// 2. Target is not the guild owner.
/// 3. Bot's highest role is above the target's highest role.
Future<String?> checkBotCanModerate(
  NyxxGateway client, {
  required Snowflake guildId,
  required Snowflake targetUserId,
  required Flag<Permissions> requiredPermission,
  required String actionLabel,
}) async {
  final guild = await client.guilds.fetch(guildId);

  // ── 1. Check bot permissions ──
  final botMember = await guild.fetchCurrentMember();
  final botRoleIds = botMember.roleIds;
  final botPermissions = _permissionsFromRoles(guild, botRoleIds, guildId);

  if (!botPermissions.isAdministrator &&
      !botPermissions.has(requiredPermission)) {
    return 'I do not have permission to $actionLabel.';
  }

  // ── 2. Cannot target the guild owner ──
  if (targetUserId == guild.ownerId) {
    return 'I cannot $actionLabel the server owner.';
  }

  // ── 3. Role hierarchy: bot's highest role must be above target's ──
  final targetMember = await guild.members.fetch(targetUserId);
  final targetRoleIds = targetMember.roleIds;

  int highestPosition(List<Snowflake> roleIds) {
    var max = 0;
    for (final role in guild.roleList) {
      if (roleIds.contains(role.id) && role.position > max) {
        max = role.position;
      }
    }
    return max;
  }

  final botHighest = highestPosition(botRoleIds);
  final targetHighest = highestPosition(targetRoleIds);

  if (botHighest <= targetHighest) {
    return 'I cannot $actionLabel this user: their highest role is equal to or above mine.';
  }

  return null;
}

// ── Human-readable permission names ─────────────────────────────────────────

String _permissionName(Flag<Permissions> flag) {
  final map = <int, String>{
    Permissions.addReactions.value: 'Add Reactions',
    Permissions.administrator.value: 'Administrator',
    Permissions.banMembers.value: 'Ban Members',
    Permissions.createInstantInvite.value: 'Create Instant Invite',
    Permissions.createPublicThreads.value: 'Create Public Threads',
    Permissions.createPrivateThreads.value: 'Create Private Threads',
    Permissions.kickMembers.value: 'Kick Members',
    Permissions.manageChannels.value: 'Manage Channels',
    Permissions.manageGuild.value: 'Manage Server',
    Permissions.manageMessages.value: 'Manage Messages',
    Permissions.manageRoles.value: 'Manage Roles',
    Permissions.manageWebhooks.value: 'Manage Webhooks',
    Permissions.moderateMembers.value: 'Moderate Members',
    Permissions.moveMembers.value: 'Move Members',
    Permissions.muteMembers.value: 'Mute Members',
    Permissions.deafenMembers.value: 'Deafen Members',
    Permissions.readMessageHistory.value: 'Read Message History',
    Permissions.sendMessages.value: 'Send Messages',
    Permissions.manageGuildExpressions.value: 'Manage Expressions',
  };
  return map[flag.value] ?? 'Permission(${flag.value})';
}
