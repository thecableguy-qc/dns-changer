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

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadAutoStartSetting();
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
    for (final node in _presetFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0+1';
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
    try {
      await platform.invokeMethod('startVpn', {
        'dns1': _dns1Controller.text.trim(),
        'dns2': _dns2Controller.text.trim(),
      });
      setState(() {
        _isVpnActive = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToStartVpn(e.toString()))),
        );
      }
    }
  }

  Future<void> _stopVpn() async {
    try {
      await platform.invokeMethod('stopVpn');
      setState(() {
        _isVpnActive = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToStopVpn(e.toString()))),
        );
      }
    }
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
        }
      }

      // Handle directional navigation
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (focusNode == _startStopFocus) {
          _dns1Focus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _dns1Focus || focusNode == _dns2Focus) {
          _autoStartFocus.requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (focusNode == _autoStartFocus) {
          _dns2Focus.requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _dns1Focus || focusNode == _dns2Focus) {
          _startStopFocus.requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (focusNode == _startStopFocus && !_isVpnActive) {
          _presetFocusNodes[0].requestFocus();
          return KeyEventResult.handled;
        } else if (focusNode == _dns1Focus) {
          _dns2Focus.requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (focusNode == _dns2Focus) {
          _dns1Focus.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isTV = mediaQuery.size.width > 1000 || mediaQuery.size.aspectRatio > 1.5;
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenHeight < 800;

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
        toolbarHeight: isCompact ? 40 : 48,
      ),
      backgroundColor: isTV ? Colors.black : null,
      body: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Container(
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
                    // Main Control Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Start/Stop Button with Focus
                        Expanded(
                          flex: 1,
                          child: Focus(
                            focusNode: _startStopFocus,
                            onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                            child: GestureDetector(
                              onTap: _isVpnActive ? _stopVpn : _startVpn,
                              child: Container(
                                height: isTV ? 160 : (isCompact ? 120 : 140),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTV ? 16 : (isCompact ? 8 : 12),
                                  vertical: isTV ? 12 : (isCompact ? 6 : 8),
                                ),
                                decoration: BoxDecoration(
                                  color: _isVpnActive ? Colors.green.shade100 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(isTV ? 8 : 6),
                                  border: Border.all(
                                    color: _startStopFocus.hasFocus ? Colors.blue :
                                           (_isVpnActive ? Colors.green : Colors.red),
                                    width: _startStopFocus.hasFocus ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isVpnActive ? Colors.green : Colors.red).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
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

                        SizedBox(width: isTV ? 12 : (isCompact ? 6 : 8)),

                        // DNS Input Fields with Focus
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: isTV ? 160 : (isCompact ? 120 : 140),
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
                                Text(
                                  AppLocalizations.of(context)!.primary,
                                  style: TextStyle(
                                    fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                    color: isTV ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: isTV ? 4 : (isCompact ? 2 : 3)),
                                Focus(
                                  focusNode: _dns1Focus,
                                  onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                                  child: TextField(
                                    controller: _dns1Controller,
                                    enabled: !_isVpnActive,
                                    style: TextStyle(
                                      fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                                      color: isTV ? Colors.white : null,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "8.8.8.8",
                                      hintStyle: TextStyle(
                                        fontSize: isTV ? 11 : (isCompact ? 9 : 10),
                                        color: isTV ? Colors.white54 : Colors.grey.shade500,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isTV ? 6 : 4),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isTV ? 6 : 4),
                                        borderSide: const BorderSide(
                                          color: Colors.blue,
                                          width: 2,
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
                                  ),
                                ),
                                SizedBox(height: isTV ? 8 : (isCompact ? 4 : 6)),
                                Text(
                                  AppLocalizations.of(context)!.secondary,
                                  style: TextStyle(
                                    fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                    color: isTV ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: isTV ? 4 : (isCompact ? 2 : 3)),
                                Focus(
                                  focusNode: _dns2Focus,
                                  onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                                  child: TextField(
                                    controller: _dns2Controller,
                                    enabled: !_isVpnActive,
                                    style: TextStyle(
                                      fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                                      color: isTV ? Colors.white : null,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "8.8.4.4",
                                      hintStyle: TextStyle(
                                        fontSize: isTV ? 11 : (isCompact ? 9 : 10),
                                        color: isTV ? Colors.white54 : Colors.grey.shade500,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isTV ? 6 : 4),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isTV ? 6 : 4),
                                        borderSide: const BorderSide(
                                          color: Colors.blue,
                                          width: 2,
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: isTV ? 12 : (isCompact ? 6 : 8)),

                        // Settings Section with Focus
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: isTV ? 160 : (isCompact ? 120 : 140),
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
                                    Focus(
                                      focusNode: _autoStartFocus,
                                      onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _autoStartFocus.hasFocus ? Colors.blue : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Transform.scale(
                                          scale: isTV ? 0.8 : (isCompact ? 0.7 : 0.8),
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

                    // DNS Presets (simplified for now)
                    if (!_isVpnActive) ...[
                      SizedBox(height: isTV ? 12 : (isCompact ? 4 : 6)),
                      Text(
                        AppLocalizations.of(context)!.presets,
                        style: TextStyle(
                          fontSize: isTV ? 14 : (isCompact ? 10 : 12),
                          fontWeight: FontWeight.bold,
                          color: isTV ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: isTV ? 6 : (isCompact ? 3 : 4)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Focus(
                              focusNode: _presetFocusNodes[0],
                              onKeyEvent: (node, event) => _handleKeyEvent(node, event),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _dns1Controller.text = "8.8.8.8";
                                    _dns2Controller.text = "8.8.4.4";
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _presetFocusNodes[0].hasFocus ? Colors.blue.shade100 : Colors.white,
                                  side: BorderSide(
                                    color: _presetFocusNodes[0].hasFocus ? Colors.blue : Colors.grey,
                                    width: _presetFocusNodes[0].hasFocus ? 2 : 1,
                                  ),
                                ),
                                child: Text('Google DNS'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Version info
                    SizedBox(height: isTV ? 16 : (isCompact ? 8 : 12)),
                    Text(
                      'Version $_appVersion',
                      style: TextStyle(
                        fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                        color: isTV ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
