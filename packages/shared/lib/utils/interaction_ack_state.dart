import 'package:nyxx/nyxx.dart';

/// Returns true when the interaction was already acknowledged or responded.
bool isInteractionAcknowledged(Interaction interaction) {
  final dynInteraction = interaction as dynamic;

  try {
    if (dynInteraction.isAcknowledged == true) {
      return true;
    }
  } catch (_) {}

  try {
    if (dynInteraction.acknowledged == true) {
      return true;
    }
  } catch (_) {}

  try {
    if (dynInteraction.hasResponded == true) {
      return true;
    }
  } catch (_) {}

  return false;
}
