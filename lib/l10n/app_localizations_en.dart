// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TheCableGuy DNS';

  @override
  String get vpnActive => 'VPN Active';

  @override
  String get vpnInactive => 'VPN Inactive';

  @override
  String get primary => 'Primary';

  @override
  String get secondary => 'Secondary';

  @override
  String get presets => 'Presets';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get google => 'Google';

  @override
  String get cloudflare => 'Cloudflare';

  @override
  String get cloudflareBlocking => 'Cloudflare + Blocker';

  @override
  String get quad9 => 'Quad9';

  @override
  String get quad9Blocking => 'Quad9 + Blocker';

  @override
  String failedToStartVpn(String error) {
    return 'Failed to start VPN: $error';
  }

  @override
  String failedToStopVpn(String error) {
    return 'Failed to stop VPN: $error';
  }
}
