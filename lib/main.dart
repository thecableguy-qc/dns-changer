import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _appVersion = '';
  bool _autoStartEnabled = false;

  // Focus nodes for D-pad navigation
  final FocusNode _startStopFocus = FocusNode();
  final FocusNode _dns1Focus = FocusNode();
  final FocusNode _dns2Focus = FocusNode();
  final FocusNode _autoStartFocus = FocusNode();
  final List<FocusNode> _presetFocusNodes = List.generate(5, (_) => FocusNode());
  final FocusNode _facebookFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadAutoStartSetting();

    // Add listeners to all focus nodes to trigger rebuilds when focus changes
    _startStopFocus.addListener(() => setState(() {}));
    _autoStartFocus.addListener(() => setState(() {}));
    _facebookFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    for (final node in _presetFocusNodes) {
      node.addListener(() => setState(() {}));
    }

    // Set initial focus to start/stop button for TV usage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStopFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _dns1Controller.dispose();
    _dns2Controller.dispose();
    _startStopFocus.dispose();
    _dns1Focus.dispose();
    _dns2Focus.dispose();
    _autoStartFocus.dispose();
    _facebookFocus.dispose();
    _emailFocus.dispose();
    for (final node in _presetFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Handle key events for D-pad navigation
  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select) {
        if (focusNode == _startStopFocus) {
          if (_isVpnActive) {
            _stopVpn();
          } else {
            _startVpn();
          }
          return KeyEventResult.handled;
        } else if (focusNode == _autoStartFocus) {
          _setAutoStart(!_autoStartEnabled);
          return KeyEventResult.handled;
        } else if (focusNode == _facebookFocus) {
          _launchUrl('https://www.facebook.com/share/169oPW4Sxq/');
          return KeyEventResult.handled;
        } else if (focusNode == _emailFocus) {
          _launchUrl('mailto:alex.parent.qc@gmail.com');
          return KeyEventResult.handled;
        }

        // Handle preset button activations
        for (int i = 0; i < _presetFocusNodes.length; i++) {
          if (focusNode == _presetFocusNodes[i]) {
            switch (i) {
              case 0: // Google
                setState(() {
                  _dns1Controller.text = "8.8.8.8";
                  _dns2Controller.text = "8.8.4.4";
                });
                break;
              case 1: // Cloudflare
                setState(() {
                  _dns1Controller.text = "1.1.1.1";
                  _dns2Controller.text = "1.0.0.1";
                });
                break;
              case 2: // Quad9
                setState(() {
                  _dns1Controller.text = "9.9.9.10";
                  _dns2Controller.text = "149.112.112.10";
                });
                break;
              case 3: // Cloudflare Blocking
                setState(() {
                  _dns1Controller.text = "1.1.1.2";
                  _dns2Controller.text = "1.0.0.2";
                });
                break;
              case 4: // Quad9 Blocking
                setState(() {
                  _dns1Controller.text = "9.9.9.9";
                  _dns2Controller.text = "149.112.112.112";
                });
                break;
            }
            return KeyEventResult.handled;
          }
        }
      }

      // Handle directional navigation with circular/wrap-around support
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (focusNode == _startStopFocus) {
          _autoStartFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _autoStartFocus) {
          // When VPN is active, wrap back to start, otherwise go to presets
          if (_isVpnActive) {
            _startStopFocus.requestFocus();
          } else {
            _presetFocusNodes[0].requestFocus();
          }
          return KeyEventResult.handled;
        } else if (focusNode == _facebookFocus) {
          _emailFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _emailFocus) {
          // Wrap around to Facebook
          _facebookFocus.requestFocus();
          return KeyEventResult.handled;
        } 
        // Preset buttons navigation (top row)
        else if (focusNode == _presetFocusNodes[0]) {
          _presetFocusNodes[1].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[1]) {
          _presetFocusNodes[2].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[2]) {
          // Wrap to first preset or go to auto-start if more logical
          _autoStartFocus.requestFocus();
          return KeyEventResult.handled;
        }
        // Preset buttons navigation (bottom row)
        else if (focusNode == _presetFocusNodes[3]) {
          _presetFocusNodes[4].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[4]) {
          // Wrap to first preset in bottom row
          _presetFocusNodes[3].requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (focusNode == _autoStartFocus) {
          _startStopFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _startStopFocus) {
          // Wrap around to auto-start
          _autoStartFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _emailFocus) {
          _facebookFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _facebookFocus) {
          // Wrap around to email
          _emailFocus.requestFocus();
          return KeyEventResult.handled;
        }
        // Preset buttons navigation (top row)
        else if (focusNode == _presetFocusNodes[1]) {
          _presetFocusNodes[0].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[2]) {
          _presetFocusNodes[1].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[0]) {
          // Wrap to last preset in top row
          _presetFocusNodes[2].requestFocus();
          return KeyEventResult.handled;
        }
        // Preset buttons navigation (bottom row)
        else if (focusNode == _presetFocusNodes[4]) {
          _presetFocusNodes[3].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[3]) {
          // Wrap to last preset in bottom row
          _presetFocusNodes[4].requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (focusNode == _startStopFocus) {
          if (!_isVpnActive) {
            _presetFocusNodes[0].requestFocus();
          } else {
            // When VPN is active, go to contacts since presets are hidden
            _facebookFocus.requestFocus();
          }
          return KeyEventResult.handled;
        } else if (focusNode == _autoStartFocus) {
          if (!_isVpnActive) {
            _presetFocusNodes[2].requestFocus();
          } else {
            // When VPN is active, go to contacts
            _emailFocus.requestFocus();
          }
          return KeyEventResult.handled;
        } 
        // Top row presets to bottom row presets
        else if (focusNode == _presetFocusNodes[0]) {
          // Google has no direct match below, go to first available bottom preset
          _presetFocusNodes[3].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[1]) {
          // Cloudflare to Cloudflare Blocking (center alignment)
          _presetFocusNodes[3].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[2]) {
          // Quad9 to Quad9 Blocking (right alignment)
          _presetFocusNodes[4].requestFocus();
          return KeyEventResult.handled;
        }
        // Bottom row presets to contacts
        else if (focusNode == _presetFocusNodes[3]) {
          _facebookFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[4]) {
          _emailFocus.requestFocus();
          return KeyEventResult.handled;
        }
        // Contacts wrap to top
        else if (focusNode == _facebookFocus || focusNode == _emailFocus) {
          _startStopFocus.requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Top controls
        if (focusNode == _presetFocusNodes[0] || focusNode == _presetFocusNodes[1]) {
          _startStopFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[2]) {
          _autoStartFocus.requestFocus();
          return KeyEventResult.handled;
        }
        // Bottom row presets to top row presets
        else if (focusNode == _presetFocusNodes[3]) {
          // Cloudflare Blocking to Cloudflare (center alignment)
          _presetFocusNodes[1].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _presetFocusNodes[4]) {
          // Quad9 Blocking to Quad9 (right alignment)
          _presetFocusNodes[2].requestFocus();
          return KeyEventResult.handled;
        }
        // Contacts to bottom presets (or top controls if VPN active)
        else if (focusNode == _facebookFocus) {
          if (!_isVpnActive) {
            _presetFocusNodes[3].requestFocus();
          } else {
            _startStopFocus.requestFocus();
          }
          return KeyEventResult.handled;
        } else if (focusNode == _emailFocus) {
          if (!_isVpnActive) {
            _presetFocusNodes[4].requestFocus();
          } else {
            _autoStartFocus.requestFocus();
          }
          return KeyEventResult.handled;
        }
        // Wrap from top controls to bottom
        else if (focusNode == _startStopFocus || focusNode == _autoStartFocus) {
          _facebookFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }

      // Handle back button (for Android TV remotes)
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        // Smart back navigation - go to most logical previous element
        if (focusNode == _emailFocus || focusNode == _facebookFocus) {
          if (!_isVpnActive) {
            _presetFocusNodes[3].requestFocus(); // Go back to presets
          } else {
            _autoStartFocus.requestFocus(); // Go back to settings
          }
          return KeyEventResult.handled;
        } else if (_presetFocusNodes.contains(focusNode)) {
          _startStopFocus.requestFocus(); // Go back to main control
          return KeyEventResult.handled;
        } else if (focusNode == _autoStartFocus) {
          _startStopFocus.requestFocus(); // Go back to main control
          return KeyEventResult.handled;
        }
      }

      // Handle menu button (for quick access to settings)
      if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
          event.logicalKey == LogicalKeyboardKey.f1) {
        _autoStartFocus.requestFocus(); // Jump to settings
        return KeyEventResult.handled;
      }

      // Handle home button (go to start)
      if (event.logicalKey == LogicalKeyboardKey.home ||
          event.logicalKey == LogicalKeyboardKey.f2) {
        _startStopFocus.requestFocus(); // Jump to start button
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0+1'; // Fallback version
      });
    }
  }

  Future<void> _loadAutoStartSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoStartEnabled = prefs.getBool('autoStart') ?? false;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _setAutoStart(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoStart', enabled);

      // Call platform method to enable/disable auto-start
      await platform.invokeMethod('setAutoStart', {'enabled': enabled});

      setState(() {
        _autoStartEnabled = enabled;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update auto-start setting: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/TheCableGuy-Logo-DNS.png',
            fit: BoxFit.contain,
          ),
        ),
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
                  // Main Control, DNS, and Settings Section - Three column layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Start/Stop Button
                      Expanded(
                        flex: 1,
                        child: Focus(
                          focusNode: _startStopFocus,
                          onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                          child: Container(
                            height: isTV ? 160 : (isCompact ? 120 : 140), // Fixed height for all sections
                            child: GestureDetector(
                              onTap: _isVpnActive ? _stopVpn : _startVpn,
                              child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: isTV ? 16 : (isCompact ? 8 : 12),
                                vertical: isTV ? 12 : (isCompact ? 6 : 8),
                              ),
                              decoration: BoxDecoration(
                                color: _isVpnActive ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(isTV ? 8 : 6),
                                border: Border.all(
                                    color: _startStopFocus.hasFocus ? Colors.yellow.shade400 :
                                           (_isVpnActive ? Colors.green : Colors.red),
                                    width: _startStopFocus.hasFocus ? 6 : 2,
                                  ),
                                boxShadow: [
                                  if (_startStopFocus.hasFocus) 
                                    BoxShadow(
                                      color: Colors.yellow.shade400.withOpacity(0.6),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                      offset: Offset(0, 0),
                                    ),
                                  BoxShadow(
                                    color: (_isVpnActive ? Colors.green : Colors.red).withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isVpnActive ? Icons.stop : Icons.play_arrow,
                                    color: _isVpnActive ? Colors.green.shade700 : Colors.red.shade700,
                                    size: isTV ? 32 : (isCompact ? 22 : 28),
                                  ),
                                  SizedBox(height: isTV ? 12 : (isCompact ? 6 : 8)),
                                  Text(
                                    _isVpnActive ? AppLocalizations.of(context)!.vpnActive : AppLocalizations.of(context)!.vpnInactive,
                                    style: TextStyle(
                                      fontSize: isTV ? 14 : (isCompact ? 10 : 12),
                                      fontWeight: FontWeight.bold,
                                      color: _isVpnActive ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: isTV ? 4 : (isCompact ? 2 : 3)),
                                  Text(
                                    _isVpnActive ? AppLocalizations.of(context)!.stop : AppLocalizations.of(context)!.start,
                                    style: TextStyle(
                                      fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                      color: _isVpnActive ? Colors.green.shade600 : Colors.red.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      ),

                      SizedBox(width: isTV ? 12 : (isCompact ? 6 : 8)),

                      // Middle - DNS Input Fields
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: isTV ? 160 : (isCompact ? 120 : 140), // Fixed height for all sections
                          padding: EdgeInsets.all(isTV ? 12 : (isCompact ? 6 : 8)),
                          decoration: BoxDecoration(
                            color: isTV ? Colors.grey.shade900 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(isTV ? 8 : 6),
                            border: Border.all(
                              color: isTV ? Colors.grey.shade700 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DNS Servers',
                                style: TextStyle(
                                  fontSize: isTV ? 12 : (isCompact ? 9 : 10),
                                  fontWeight: FontWeight.w600,
                                  color: isTV ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              SizedBox(height: isTV ? 8 : (isCompact ? 4 : 6)),

                              // Primary DNS
                              Text(
                                AppLocalizations.of(context)!.primary,
                                style: TextStyle(
                                  fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                  color: isTV ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              SizedBox(height: isTV ? 4 : (isCompact ? 2 : 3)),
                              _buildCompactDnsInputField(
                                controller: _dns1Controller,
                                hint: "8.8.8.8",
                                enabled: !_isVpnActive,
                                isTV: isTV,
                                isCompact: isCompact,
                              ),

                              SizedBox(height: isTV ? 12 : (isCompact ? 6 : 8)),

                              // Secondary DNS
                              Text(
                                AppLocalizations.of(context)!.secondary,
                                style: TextStyle(
                                  fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                  color: isTV ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              SizedBox(height: isTV ? 4 : (isCompact ? 2 : 3)),
                              _buildCompactDnsInputField(
                                controller: _dns2Controller,
                                hint: "8.8.4.4",
                                enabled: !_isVpnActive,
                                isTV: isTV,
                                isCompact: isCompact,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: isTV ? 12 : (isCompact ? 6 : 8)),

                      // Right side - Settings Section
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: isTV ? 160 : (isCompact ? 120 : 140), // Fixed height for all sections
                          padding: EdgeInsets.all(isTV ? 12 : (isCompact ? 6 : 8)),
                          decoration: BoxDecoration(
                            color: isTV ? Colors.grey.shade900 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(isTV ? 8 : 6),
                            border: Border.all(
                              color: isTV ? Colors.grey.shade700 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.settings,
                                style: TextStyle(
                                  fontSize: isTV ? 12 : (isCompact ? 9 : 10),
                                  fontWeight: FontWeight.w600,
                                  color: isTV ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              SizedBox(height: isTV ? 16 : (isCompact ? 8 : 12)),

                              // Auto-start toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)!.autoStart,
                                      style: TextStyle(
                                        fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                        color: isTV ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: isTV ? 0.8 : (isCompact ? 0.7 : 0.8),
                                    child: Focus(
                                      focusNode: _autoStartFocus,
                                      onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: _autoStartFocus.hasFocus ? Border.all(
                                            color: Colors.yellow.shade400,
                                            width: 4,
                                          ) : null,
                                          boxShadow: _autoStartFocus.hasFocus ? [
                                            BoxShadow(
                                              color: Colors.yellow.shade400.withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                              offset: Offset(0, 0),
                                            ),
                                          ] : null,
                                        ),
                                        child: Switch(
                                          value: _autoStartEnabled,
                                          onChanged: _setAutoStart,
                                          activeColor: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Only show presets when VPN is not connected
                  if (!_isVpnActive) ...[
                    SizedBox(height: isTV ? 12 : (isCompact ? 4 : 6)),

                    // DNS Presets - more compact
                    Text(
                      AppLocalizations.of(context)!.presets,
                      style: TextStyle(
                        fontSize: isTV ? 14 : (isCompact ? 10 : 12),
                        fontWeight: FontWeight.bold,
                        color: isTV ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    SizedBox(height: isTV ? 6 : (isCompact ? 3 : 4)),

                    // Preset buttons in a 2x3 grid (2 rows, 3 columns)
                    Column(
                      children: [
                        // First row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.google, "8.8.8.8", "8.8.4.4", _buildGoogleLogo, isTV, isCompact, _presetFocusNodes[0]),
                            ),
                            SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                            Expanded(
                              child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.cloudflare, "1.1.1.1", "1.0.0.1", _buildCloudflareLogo, isTV, isCompact, _presetFocusNodes[1]),
                            ),
                            SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                            Expanded(
                              child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.quad9, "9.9.9.10", "149.112.112.10", _buildQuad9Logo, isTV, isCompact, _presetFocusNodes[2]),
                            ),
                          ],
                        ),
                        SizedBox(height: isTV ? 6 : (isCompact ? 3 : 4)),
                        // Second row with ad-blocking presets
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Container(), // Empty space for alignment
                            ),
                            SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                            Expanded(
                              child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.cloudflareBlocking, "1.1.1.2", "1.0.0.2", _buildCloudflareBlockingLogo, isTV, isCompact, _presetFocusNodes[3]),
                            ),
                            SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                            Expanded(
                              child: _buildPresetButtonWithLogo(AppLocalizations.of(context)!.quad9Blocking, "9.9.9.9", "149.112.112.112", _buildQuad9BlockingLogo, isTV, isCompact, _presetFocusNodes[4]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],

                  // Contact Information and Version
                  SizedBox(height: isTV ? 12 : (isCompact ? 6 : 8)),

                  Container(
                    padding: EdgeInsets.all(isTV ? 16 : (isCompact ? 8 : 12)),
                    decoration: BoxDecoration(
                      color: isTV ? Colors.grey.shade900 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(isTV ? 12 : 8),
                      border: Border.all(
                        color: isTV ? Colors.grey.shade700 : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // App Version
                        Text(
                          'Version $_appVersion',
                          style: TextStyle(
                            fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                            color: isTV ? Colors.white70 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isTV ? 12 : (isCompact ? 6 : 8)),

                        // Contact Information
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Left Logo
                            Container(
                              width: isTV ? 32 : (isCompact ? 20 : 24),
                              height: isTV ? 32 : (isCompact ? 20 : 24),
                              child: Image.asset(
                                'assets/images/TheCableGuy-Logo-DNS.png',
                                fit: BoxFit.contain,
                              ),
                            ),

                            SizedBox(width: isTV ? 12 : (isCompact ? 6 : 8)),

                            // Facebook Link
                            Focus(
                              focusNode: _facebookFocus,
                              onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                              child: GestureDetector(
                                onTap: () => _launchUrl('https://www.facebook.com/share/169oPW4Sxq/'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTV ? 12 : (isCompact ? 8 : 10),
                                    vertical: isTV ? 8 : (isCompact ? 4 : 6),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF1877F2), // Facebook blue
                                    borderRadius: BorderRadius.circular(isTV ? 8 : 6),
                                    border: _facebookFocus.hasFocus ? Border.all(
                                      color: Colors.yellow.shade400,
                                      width: 4,
                                    ) : null,
                                    boxShadow: _facebookFocus.hasFocus ? [
                                      BoxShadow(
                                        color: Colors.yellow.shade400.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                        offset: Offset(0, 0),
                                      ),
                                    ] : null,
                                  ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.facebook,
                                      color: Colors.white,
                                      size: isTV ? 18 : (isCompact ? 14 : 16),
                                    ),
                                    SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                                    Text(
                                      'Facebook',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),

                            SizedBox(width: isTV ? 16 : (isCompact ? 8 : 12)),

                            // Email Link
                            Focus(
                              focusNode: _emailFocus,
                              onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                              child: GestureDetector(
                                onTap: () => _launchUrl('mailto:alex.parent.qc@gmail.com'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTV ? 12 : (isCompact ? 8 : 10),
                                    vertical: isTV ? 8 : (isCompact ? 4 : 6),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF34495E), // Dark gray for email
                                    borderRadius: BorderRadius.circular(isTV ? 8 : 6),
                                    border: _emailFocus.hasFocus ? Border.all(
                                      color: Colors.yellow.shade400,
                                      width: 4,
                                    ) : null,
                                    boxShadow: _emailFocus.hasFocus ? [
                                      BoxShadow(
                                        color: Colors.yellow.shade400.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                        offset: Offset(0, 0),
                                      ),
                                    ] : null,
                                  ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.email,
                                      color: Colors.white,
                                      size: isTV ? 18 : (isCompact ? 14 : 16),
                                    ),
                                    SizedBox(width: isTV ? 8 : (isCompact ? 4 : 6)),
                                    Text(
                                      'Contact',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),

                            SizedBox(width: isTV ? 12 : (isCompact ? 6 : 8)),

                            // Right Logo
                            Container(
                              width: isTV ? 32 : (isCompact ? 20 : 24),
                              height: isTV ? 32 : (isCompact ? 20 : 24),
                              child: Image.asset(
                                'assets/images/TheCableGuy-Logo-DNS.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Widget _buildCompactDnsInputField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    required bool isTV,
    bool isCompact = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
        fontSize: isTV ? 12 : (isCompact ? 10 : 11),
        color: isTV ? Colors.white : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: isTV ? 11 : (isCompact ? 9 : 10),
          color: isTV ? Colors.white54 : Colors.grey.shade500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 6 : 4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 6 : 4),
          borderSide: BorderSide(
            color: isTV ? Colors.white30 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 6 : 4),
          borderSide: BorderSide(
            color: isTV ? Colors.blue.shade300 : Colors.blue,
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTV ? 8 : (isCompact ? 6 : 7),
          vertical: isTV ? 6 : (isCompact ? 4 : 5),
        ),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
    );
  }

  Widget _buildPresetButtonWithLogo(String name, String dns1, String dns2, Widget Function(bool isTV, bool isCompact) logoBuilder, bool isTV, [bool isCompact = false, FocusNode? focusNode]) {
    Widget button = ElevatedButton(
      onPressed: () {
        setState(() {
          _dns1Controller.text = dns1;
          _dns2Controller.text = dns2;
        });
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isTV ? 8 : (isCompact ? 2 : 4),
          vertical: isTV ? 6 : (isCompact ? 2 : 4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTV ? 6 : (isCompact ? 3 : 4)),
        ),
        side: focusNode?.hasFocus == true ? BorderSide(
          color: Colors.yellow.shade400,
          width: 4,
        ) : null,
        backgroundColor: isTV ? Colors.grey.shade800 : Colors.white,
        foregroundColor: isTV ? Colors.white : Colors.black87,
        minimumSize: Size(0, isCompact ? 24 : 32), // Even smaller minimum height
        elevation: isTV ? 2 : 1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoBuilder(isTV, isCompact),
          SizedBox(height: isTV ? 3 : (isCompact ? 1 : 2)),
          Text(
            name,
            style: TextStyle(
              fontSize: isTV ? 10 : (isCompact ? 7 : 8),
              fontWeight: isTV ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (focusNode != null) {
      return AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: focusNode.hasFocus ? BoxDecoration(
          borderRadius: BorderRadius.circular(isTV ? 8 : 6),
          boxShadow: [
            BoxShadow(
              color: Colors.yellow.shade400.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
              offset: Offset(0, 0),
            ),
          ],
        ) : null,
        child: Focus(
          focusNode: focusNode,
          onKeyEvent: (node, event) => _handleKeyEvent(node, event),
          child: button,
        ),
      );
    }

    return button;
  }

  Widget _buildGoogleLogo(bool isTV, bool isCompact) {
    double size = isTV ? 20 : (isCompact ? 12 : 14);
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
                value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCloudflareLogo(bool isTV, bool isCompact) {
    double size = isTV ? 20 : (isCompact ? 12 : 14);
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
                value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuad9Logo(bool isTV, bool isCompact) {
    double size = isTV ? 20 : (isCompact ? 12 : 14);
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
                value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCloudflareBlockingLogo(bool isTV, bool isCompact) {
    double size = isTV ? 20 : (isCompact ? 12 : 14);
    return Container(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Base Cloudflare logo container
          Container(
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
                      color: Color(0xFFF38020), // Cloudflare orange
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
                      value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                    ),
                  );
                },
              ),
            ),
          ),
          // Red shield overlay in bottom right to indicate blocking
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: Color(0xFFE74C3C), // Red for blocking
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.block,
                  size: size * 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuad9BlockingLogo(bool isTV, bool isCompact) {
    double size = isTV ? 20 : (isCompact ? 12 : 14);
    return Container(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Base Quad9 logo (using similar style but different colors)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3730A3)], // Blue gradient for Quad9
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
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
                      value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                    ),
                  );
                },
              ),
            ),
          ),
          // Red shield overlay in bottom right to indicate blocking
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: Color(0xFFE74C3C), // Red for blocking
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.block,
                  size: size * 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
