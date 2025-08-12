// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'TheCableGuy DNS';

  @override
  String get vpnActive => 'VPN Activo';

  @override
  String get vpnInactive => 'VPN Inactivo';

  @override
  String get primary => 'Primario';

  @override
  String get secondary => 'Secundario';

  @override
  String get presets => 'Predefinidos';

  @override
  String get start => 'Iniciar';

  @override
  String get stop => 'Detener';

  @override
  String get google => 'Google';

  @override
  String get cloudflare => 'Cloudflare';

  @override
  String get cloudflareBlocking => 'Cloudflare + Bloqueador';

  @override
  String get quad9 => 'Quad9';

  @override
  String get quad9Blocking => 'Quad9 + Bloqueador';

  @override
  String failedToStartVpn(String error) {
    return 'Error al iniciar VPN: $error';
  }

  @override
  String failedToStopVpn(String error) {
    return 'Error al detener VPN: $error';
  }
}
