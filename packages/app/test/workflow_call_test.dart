import 'package:bot_creator/utils/workflow_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeStoredWorkflowDefinition', () {
    test('promotes legacy event field into event workflow', () {
      final normalized = normalizeStoredWorkflowDefinition(<String, dynamic>{
        'name': 'Legacy Message Create',
        'event': 'messageCreate',
        'actions': <Map<String, dynamic>>[],
      });

      expect(normalized['workflowType'], workflowTypeEvent);
      expect(normalized['eventTrigger'], <String, dynamic>{
        'category': 'messages',
        'event': 'messageCreate',
      });
    });

    test('promotes legacy listenFor field into event workflow', () {
      final normalized = normalizeStoredWorkflowDefinition(<String, dynamic>{
        'name': 'Legacy Member Add',
        'listenFor': 'guildMemberAdd',
        'actions': <Map<String, dynamic>>[],
      });

      expect(normalized['workflowType'], workflowTypeEvent);
      expect(normalized['eventTrigger'], <String, dynamic>{
        'category': 'messages',
        'event': 'guildMemberAdd',
      });
    });
  });
}
