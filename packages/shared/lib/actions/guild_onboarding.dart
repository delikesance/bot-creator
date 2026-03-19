import 'dart:convert';
import 'package:nyxx/nyxx.dart';

/// Fetches current guild onboarding configuration.
///
/// Returns `{'onboardingJson': '{...}', 'enabled': 'true|false'}` or `{'error': '...'}`.
Future<Map<String, String>> getGuildOnboardingAction(
  NyxxGateway client, {
  required Snowflake? guildId,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'getGuildOnboarding requires a guild context'};
    }

    final guild = await client.guilds.get(guildId);
    final onboarding = await guild.fetchOnboarding();

    final json = jsonEncode({
      'guildId': onboarding.guildId.toString(),
      'enabled': onboarding.isEnabled,
      'defaultChannelIds':
          onboarding.defaultChannelIds.map((id) => id.toString()).toList(),
      'mode': onboarding.mode.value,
      'prompts': onboarding.prompts
          .map(
            (p) => {
              'id': p.id.toString(),
              'title': p.title,
              'type': p.type.value,
              'required': p.isRequired,
              'singleSelect': p.isSingleSelect,
              'inOnboarding': p.isInOnboarding,
              'options': p.options
                  .map(
                    (o) => {
                      'id': o.id.toString(),
                      'title': o.title,
                      'description': o.description ?? '',
                      'channelIds':
                          o.channelIds.map((id) => id.toString()).toList(),
                      'roleIds':
                          o.roleIds.map((id) => id.toString()).toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    });

    return {
      'onboardingJson': json,
      'enabled': onboarding.isEnabled.toString(),
    };
  } catch (e) {
    return {'error': 'Failed to get guild onboarding: $e'};
  }
}
