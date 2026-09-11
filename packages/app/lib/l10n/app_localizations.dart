import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @homeOverline.
  ///
  /// In en, this message translates to:
  /// **'MY PROJECTS'**
  String get homeOverline;

  /// No description provided for @homeRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get homeRefreshTooltip;

  /// No description provided for @homeDocsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get homeDocsTooltip;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsTooltip;

  /// No description provided for @homeTurnkeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Turnkey bots'**
  String get homeTurnkeyTitle;

  /// No description provided for @homeTurnkeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deploy ready-to-use bots'**
  String get homeTurnkeySubtitle;

  /// No description provided for @homeHostingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get homeHostingAdd;

  /// No description provided for @homeHostingUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get homeHostingUnlimited;

  /// No description provided for @homeHostingUnitMonth.
  ///
  /// In en, this message translates to:
  /// **'mo'**
  String get homeHostingUnitMonth;

  /// No description provided for @homeHostingUnitDay.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get homeHostingUnitDay;

  /// No description provided for @homeHostingUnitHour.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get homeHostingUnitHour;

  /// No description provided for @homeHostingUnitMinute.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get homeHostingUnitMinute;

  /// No description provided for @homeStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get homeStartAction;

  /// No description provided for @homeCreateApp.
  ///
  /// In en, this message translates to:
  /// **'Create application'**
  String get homeCreateApp;

  /// Server noun, pluralized (the count itself is shown separately).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{server} other{servers}}'**
  String homeServersNoun(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
