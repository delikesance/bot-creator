import 'package:bot_creator_shared/utils/global.dart';
import 'package:test/test.dart';

class _FakeChannel {
  _FakeChannel({
    this.topic,
    this.parentId,
    this.position,
    this.isNsfw,
    this.rateLimitPerUser,
    this.bitrate,
    this.userLimit,
    this.isArchived,
    this.isLocked,
    this.ownerId,
    this.autoArchiveDuration,
  });

  final String? topic;
  final String? parentId;
  final int? position;
  final bool? isNsfw;
  final int? rateLimitPerUser;
  final int? bitrate;
  final int? userLimit;
  final bool? isArchived;
  final bool? isLocked;
  final String? ownerId;
  final int? autoArchiveDuration;
}

class _FakeGuild {
  _FakeGuild({
    this.ownerId,
    this.description,
    this.vanityUrlCode,
    this.preferredLocale,
    this.verificationLevel,
    this.mfaLevel,
    this.nsfwLevel,
    this.premiumTier,
    this.premiumSubscriptionCount,
    this.features,
    this.memberCount,
  });

  final String? ownerId;
  final String? description;
  final String? vanityUrlCode;
  final String? preferredLocale;
  final String? verificationLevel;
  final String? mfaLevel;
  final String? nsfwLevel;
  final int? premiumTier;
  final int? premiumSubscriptionCount;
  final List<String>? features;
  final int? memberCount;
}

void main() {
  group('extractChannelRuntimeDetails', () {
    test('extracts advanced channel fields', () {
      final details = extractChannelRuntimeDetails(
        _FakeChannel(
          topic: 'alerts',
          parentId: '123',
          position: 4,
          isNsfw: true,
          rateLimitPerUser: 10,
          bitrate: 64000,
          userLimit: 25,
          isArchived: true,
          isLocked: false,
          ownerId: '777',
          autoArchiveDuration: 1440,
        ),
      );

      expect(details['channel.topic'], 'alerts');
      expect(details['channel.parentId'], '123');
      expect(details['channel.position'], '4');
      expect(details['channel.nsfw'], 'true');
      expect(details['channel.slowmode'], '10');
      expect(details['channel.bitrate'], '64000');
      expect(details['channel.userLimit'], '25');
      expect(details['channel.thread.archived'], 'true');
      expect(details['channel.thread.locked'], 'false');
      expect(details['channel.thread.ownerId'], '777');
      expect(details['channel.thread.autoArchiveDuration'], '1440');
    });
  });

  group('extractGuildRuntimeDetails', () {
    test('extracts advanced guild fields', () {
      final details = extractGuildRuntimeDetails(
        _FakeGuild(
          ownerId: '42',
          description: 'Main guild',
          vanityUrlCode: 'myguild',
          preferredLocale: 'fr',
          verificationLevel: 'high',
          mfaLevel: 'elevated',
          nsfwLevel: 'default',
          premiumTier: 2,
          premiumSubscriptionCount: 14,
          features: const <String>['COMMUNITY', 'INVITES_DISABLED'],
          memberCount: 1200,
        ),
      );

      expect(details['guild.ownerId'], '42');
      expect(details['guild.description'], 'Main guild');
      expect(details['guild.vanityUrlCode'], 'myguild');
      expect(details['guild.preferredLocale'], 'fr');
      expect(details['guild.verificationLevel'], 'high');
      expect(details['guild.mfaLevel'], 'elevated');
      expect(details['guild.nsfwLevel'], 'default');
      expect(details['guild.premiumTier'], '2');
      expect(details['guild.premiumSubscriptionCount'], '14');
      expect(details['guild.features'], 'COMMUNITY,INVITES_DISABLED');
      expect(details['guild.features.count'], '2');
      expect(details['guild.memberCount'], '1200');
    });
  });
}
