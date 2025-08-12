// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'TheCableGuy DNS';

  @override
  String get vpnActive => 'VPN Actif';

  @override
  String get vpnInactive => 'VPN Inactif';

  @override
  String get primary => 'Primaire';

  @override
  String get secondary => 'Secondaire';

  @override
  String get presets => 'Prédéfinis';

  @override
  String get start => 'Démarrer';

  @override
  String get stop => 'Arrêter';

  @override
  String get google => 'Google';

  @override
  String get cloudflare => 'Cloudflare';

  @override
  String get quad9 => 'Quad9';

  @override
  String failedToStartVpn(String error) {
    return 'Échec du démarrage du VPN: $error';
  }

  @override
  String failedToStopVpn(String error) {
    return 'Échec de l\'arrêt du VPN: $error';
  }
}
