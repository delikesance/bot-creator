import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import '../utils/component_workflow_bindings.dart';
import 'send_component_v2.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> editMessageAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
  required String content,
  String Function(String)? resolve,
  String? botId,
  String? guildId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    final messageId = _toSnowflake(payload['messageId']);
    if (channelId == null || messageId == null) {
      return {'error': 'Missing channelId/messageId', 'messageId': ''};
    }

    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    final message = await channel.messages.fetch(messageId);
    List<ComponentBuilder>? components;
    ComponentV2Definition? definition;
    if (payload.containsKey('componentV2') && payload['componentV2'] is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(payload['componentV2']),
        );
        definition = def;
        components = buildComponentNodes(
          definition: def,
          resolve: resolve ?? (s) => s,
        );
      } catch (_) {}
    }

    await message.edit(
      MessageUpdateBuilder(
        content: content.isNotEmpty ? content : null,
        components: components,
      ),
    );
    if (definition != null && botId != null && botId.trim().isNotEmpty) {
      registerComponentWorkflowBindings(
        definition: definition,
        resolve: resolve ?? (s) => s,
        botId: botId,
        guildId: guildId,
        channelId: channelId.toString(),
        messageId: message.id.toString(),
      );
    }
    return {'messageId': message.id.toString()};
  } catch (error) {
    return {'error': 'Failed to edit message: $error', 'messageId': ''};
  }
}
