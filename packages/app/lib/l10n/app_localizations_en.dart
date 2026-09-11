// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeOverline => 'MY PROJECTS';

  @override
  String get homeRefreshTooltip => 'Refresh';

  @override
  String get homeDocsTooltip => 'Documentation';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String get homeTurnkeyTitle => 'Turnkey bots';

  @override
  String get homeTurnkeySubtitle => 'Deploy ready-to-use bots';

  @override
  String get homeHostingAdd => 'Add time';

  @override
  String get homeHostingUnlimited => 'Unlimited';

  @override
  String get homeHostingUnitMonth => 'mo';

  @override
  String get homeHostingUnitDay => 'd';

  @override
  String get homeHostingUnitHour => 'h';

  @override
  String get homeHostingUnitMinute => 'm';

  @override
  String get homeStartAction => 'Start';

  @override
  String get homeCreateApp => 'Create application';

  @override
  String homeServersNoun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'servers',
      one: 'server',
    );
    return '$_temp0';
  }
}
