enum NativeAdPlacement { homeBots, commandsList, workflowsList }

class AdsPlacementPolicy {
  AdsPlacementPolicy._();

  static const int listInterval = 9;
  static const Duration globalCooldown = Duration(seconds: 55);

  static bool isPlacementEnabled(NativeAdPlacement placement) {
    switch (placement) {
      case NativeAdPlacement.homeBots:
      case NativeAdPlacement.commandsList:
      case NativeAdPlacement.workflowsList:
        return true;
    }
  }

  static String placementKey(NativeAdPlacement placement) {
    switch (placement) {
      case NativeAdPlacement.homeBots:
        return 'home_bots';
      case NativeAdPlacement.commandsList:
        return 'commands_list';
      case NativeAdPlacement.workflowsList:
        return 'workflows_list';
    }
  }

  static bool shouldInsertAfterContentCount(int displayedContentCount) {
    if (displayedContentCount <= 0) {
      return false;
    }
    return displayedContentCount % listInterval == 0;
  }

  static int adCountForContentLength(int contentLength) {
    if (contentLength <= 0) {
      return 0;
    }
    return contentLength ~/ listInterval;
  }

  static bool isAdSlotIndex(int mixedIndex) {
    final slotStep = listInterval + 1;
    return (mixedIndex + 1) % slotStep == 0;
  }

  static int contentIndexForMixedIndex(int mixedIndex) {
    final slotStep = listInterval + 1;
    return mixedIndex - ((mixedIndex + 1) ~/ slotStep);
  }
}
