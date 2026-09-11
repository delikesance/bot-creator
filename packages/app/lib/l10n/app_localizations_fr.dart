// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get homeOverline => 'MES PROJETS';

  @override
  String get homeRefreshTooltip => 'Actualiser';

  @override
  String get homeDocsTooltip => 'Documentation';

  @override
  String get homeSettingsTooltip => 'Paramètres';

  @override
  String get homeTurnkeyTitle => 'Bots Clé en main';

  @override
  String get homeTurnkeySubtitle => 'Déployez des bots prêts à l\'emploi';

  @override
  String get homeHostingAdd => 'Ajouter du temps';

  @override
  String get homeHostingUnlimited => 'Illimité';

  @override
  String get homeHostingUnitMonth => 'mois';

  @override
  String get homeHostingUnitDay => 'j';

  @override
  String get homeHostingUnitHour => 'h';

  @override
  String get homeHostingUnitMinute => 'm';

  @override
  String get homeStartAction => 'Démarrer';

  @override
  String get homeCreateApp => 'Créer une application';

  @override
  String homeServersNoun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'serveurs',
      one: 'serveur',
    );
    return '$_temp0';
  }
}
