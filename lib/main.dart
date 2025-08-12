
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TheCableGuy DNS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('fr'), // French
        Locale('es'), // Spanish
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('vpn_channel');

  final TextEditingController _dns1Controller = TextEditingController(text: '8.8.8.8');
  final TextEditingController _dns2Controller = TextEditingController(text: '8.8.4.4');
  bool _isVpnActive = false;

  @override
  void dispose() {
    _dns1Controller.dispose();
    _dns2Controller.dispose();
    super.dispose();
  }

  Future<void> _startVpn() async {
    debugPrint("Flutter: Starting VPN - invoking method channel...");
    debugPrint("Flutter: DNS1: ${_dns1Controller.text}, DNS2: ${_dns2Controller.text}");

    try {
      await platform.invokeMethod('startVpn', {
        'dns1': _dns1Controller.text.trim(),
        'dns2': _dns2Controller.text.trim(),
      });
      debugPrint("Flutter: VPN start method channel call successful");
      setState(() {
        _isVpnActive = true;
      });
    } catch (e) {
      debugPrint("Flutter: Failed to start VPN: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToStartVpn(e.toString()))),
        );
      }
    }
  }

  Future<void> _stopVpn() async {
    debugPrint("Flutter: Stopping VPN - invoking method channel...");
    try {
      await platform.invokeMethod('stopVpn');
      debugPrint("Flutter: VPN stop method channel call successful");
      setState(() {
        _isVpnActive = false;
      });
    } catch (e) {
      debugPrint("Flutter: Failed to stop VPN: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToStopVpn(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect if running on TV by checking screen size and orientation
    final mediaQuery = MediaQuery.of(context);
    final isTV = mediaQuery.size.width > 1000 || mediaQuery.size.aspectRatio > 1.5;
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenHeight < 800; // More aggressive compact detection

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        centerTitle: true,
        backgroundColor: isTV ? Colors.black87 : null,
        toolbarHeight: isCompact ? 40 : 48, // Even smaller app bar
      ),
      backgroundColor: isTV ? Colors.black : null,
      body: Container(
        padding: EdgeInsets.all(isTV ? 20.0 : (isCompact ? 4.0 : 8.0)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTV ? 800 : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // VPN Status - ultra compact
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTV ? 16 : (isCompact ? 8 : 12),
                      vertical: isTV ? 12 : (isCompact ? 4 : 8),
                    ),
                    decoration: BoxDecoration(
                      color: _isVpnActive ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(isTV ? 10 : 4),
                      border: Border.all(
                        color: _isVpnActive ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isVpnActive ? Icons.vpn_key : Icons.vpn_key_off,
                          color: _isVpnActive ? Colors.green : Colors.red,
                          size: isTV ? 28 : (isCompact ? 16 : 20),
                        ),
                        SizedBox(width: isTV ? 12 : (isCompact ? 4 : 6)),
                        Text(
                          _isVpnActive ? AppLocalizations.of(context)!.vpnActive : AppLocalizations.of(context)!.vpnInactive,
                          style: TextStyle(
                            fontSize: isTV ? 18 : (isCompact ? 12 : 14),
                            fontWeight: FontWeight.bold,
                            color: _isVpnActive ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isTV ? 16 : (isCompact ? 6 : 10)),

                  // DNS Input Fields in a Row for better space usage
                  Row(
                    children: [
                      Expanded(
                        child: _buildDnsInputField(
                          controller: _dns1Controller,
                          label: AppLocalizations.of(context)!.primary,
                          hint: "8.8.8.8",
                          enabled: !_isVpnActive,
                          isTV: isTV,
                          isCompact: isCompact,
                        ),
                      ),
                      SizedBox(width: isTV ? 12 : (isCompact ? 4 : 6)),
                      Expanded(
                        child: _buildDnsInputField(
                          controller: _dns2Controller,
                          label: AppLocalizations.of(context)!.secondary,
                          hint: "8.8.4.4",
                          enabled: !_isVpnActive,
                          isTV: isTV,
                          isCompact: isCompact,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isTV ? 16 : (isCompact ? 6 : 10)),

                  // DNS Presets - smaller text and more compact grid
                  Text(
                    AppLocalizations.of(context)!.presets,
                    style: TextStyle(
                      fontSize: isTV ? 16 : (isCompact ? 12 : 14),
                      fontWeight: FontWeight.bold,
                      color: isTV ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  SizedBox(height: isTV ? 8 : (isCompact ? 4 : 6)),

                  // Preset buttons in a single horizontal row - disabled when VPN is active
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.google, "8.8.8.8", "8.8.4.4", _buildGoogleLogo, isTV, isCompact),
                      ),
                      SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                      Expanded(
                        child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.cloudflare, "1.1.1.1", "1.0.0.1", _buildCloudflareLogo, isTV, isCompact),
                      ),
                      SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                      Expanded(
                        child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.quad9, "9.9.9.9", "149.112.112.112", _buildQuad9Logo, isTV, isCompact),
                      ),
                    ],
                  ),

                  SizedBox(height: isTV ? 16 : (isCompact ? 8 : 12)),

                  // VPN Control Buttons - centered below presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildVpnButton(
                        onPressed: _isVpnActive ? null : _startVpn,
                        icon: Icons.play_arrow,
                        label: AppLocalizations.of(context)!.start,
                        color: Colors.green,
                        isTV: isTV,
                        isCompact: isCompact,
                      ),
                      SizedBox(width: isTV ? 20 : (isCompact ? 12 : 16)),
                      _buildVpnButton(
                        onPressed: _isVpnActive ? _stopVpn : null,
                        icon: Icons.stop,
                        label: AppLocalizations.of(context)!.stop,
                        color: Colors.red,
                        isTV: isTV,
                        isCompact: isCompact,
                      ),
                    ],
                  ),

                  // Minimal bottom padding
                  SizedBox(height: isCompact ? 4 : 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDnsInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool enabled,
    required bool isTV,
    bool isCompact = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
        fontSize: isTV ? 16 : (isCompact ? 12 : 14),
        color: isTV ? Colors.white : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: isTV ? 14 : (isCompact ? 10 : 12),
          color: isTV ? Colors.white70 : null,
        ),
        hintStyle: TextStyle(
          color: isTV ? Colors.white54 : null,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 10 : (isCompact ? 4 : 6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 10 : (isCompact ? 4 : 6)),
          borderSide: BorderSide(
            color: isTV ? Colors.white30 : Colors.grey,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 10 : (isCompact ? 4 : 6)),
          borderSide: BorderSide(
            color: isTV ? Colors.blue.shade300 : Colors.blue,
            width: 2,
          ),
        ),
        prefixIcon: Icon(
          Icons.dns,
          color: isTV ? Colors.white54 : null,
          size: isTV ? 20 : (isCompact ? 14 : 16),
        ),
        contentPadding: EdgeInsets.all(isTV ? 12 : (isCompact ? 6 : 8)),
        isDense: true, // Always dense for compact layout
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
    );
  }

  Widget _buildVpnButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isTV,
    bool isCompact = false,
  }) {
    return SizedBox(
      width: isTV ? 160 : (isCompact ? 80 : 100),
      height: isTV ? 50 : (isCompact ? 32 : 40),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: isTV ? 20 : (isCompact ? 14 : 16),
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isTV ? 16 : (isCompact ? 10 : 12),
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTV ? 12 : (isCompact ? 4 : 6)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTV ? 16 : (isCompact ? 4 : 8),
            vertical: isTV ? 10 : (isCompact ? 4 : 6),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButtonWithLogo(String name, String dns1, String dns2, Widget Function(bool isTV, bool isCompact) logoBuilder, bool isTV, [bool isCompact = false]) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _dns1Controller.text = dns1;
          _dns2Controller.text = dns2;
        });
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isTV ? 12 : (isCompact ? 3 : 6),
          vertical: isTV ? 8 : (isCompact ? 3 : 6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTV ? 8 : (isCompact ? 4 : 6)),
        ),
        backgroundColor: isTV ? Colors.grey.shade800 : Colors.white,
        foregroundColor: isTV ? Colors.white : Colors.black87,
        minimumSize: Size(0, isCompact ? 28 : 36), // Minimum height
        elevation: isTV ? 2 : 1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoBuilder(isTV, isCompact),
          SizedBox(height: isTV ? 4 : (isCompact ? 2 : 3)),
          Text(
            name,
            style: TextStyle(
              fontSize: isTV ? 12 : (isCompact ? 8 : 9),
              fontWeight: isTV ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLogo(bool isTV, bool isCompact) {
    double size = isTV ? 24 : (isCompact ? 16 : 18);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Image.network(
          'https://www.google.com/favicon.ico',
          width: size * 0.8,
          height: size * 0.8,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'G',
              style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4285F4),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCloudflareLogo(bool isTV, bool isCompact) {
    double size = isTV ? 24 : (isCompact ? 16 : 18);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Image.network(
          'https://www.cloudflare.com/favicon.ico',
          width: size * 0.8,
          height: size * 0.8,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                color: Color(0xFFF38020),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud,
                size: size * 0.5,
                color: Colors.white,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuad9Logo(bool isTV, bool isCompact) {
    double size = isTV ? 24 : (isCompact ? 16 : 18);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Image.network(
          'https://www.quad9.net/favicon.ico',
          width: size * 0.8,
          height: size * 0.8,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '9',
                  style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}


