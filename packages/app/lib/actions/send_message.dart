import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import '../utils/component_workflow_bindings.dart';
import 'send_component_v2.dart';

Future<Map<String, String>> sendMessageToChannel(
  NyxxGateway client,
  Snowflake channelId, {
  required String content,
  Map<String, dynamic>? payload,
  String Function(String)? resolve,
  String? botId,
  String? guildId,
}) async {
  try {
    final channel = await client.channels.get(channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    List<ComponentBuilder>? components;
    bool isRichV2 = false;
    ComponentV2Definition? definition;
    if (payload != null &&
        payload.containsKey('componentV2') &&
        payload['componentV2'] is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(payload['componentV2']),
        );
        definition = def;
        isRichV2 = def.isRichV2;
        components = buildComponentNodes(
          definition: def,
          resolve: resolve ?? (s) => s,
        );
      } catch (_) {}
    }

    final message = await channel.sendMessage(
      MessageBuilder(
        content: isRichV2 ? null : (content.isNotEmpty ? content : null),
        components: components,
        flags: isRichV2 ? MessageFlags(32768) : null,
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
  } catch (e) {
    return {'error': 'Failed to send message: $e', 'messageId': ''};
  }
}
