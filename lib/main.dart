import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('vpn_channel');

  final TextEditingController _dns1Controller = TextEditingController(text: '8.8.8.8');
  final TextEditingController _dns2Controller = TextEditingController(text: '8.8.4.4');
  bool _isVpnActive = false;
  String _appVersion = '';

  // Focus nodes for D-pad navigation
  final FocusNode _startStopFocus = FocusNode();
  final FocusNode _dns1Focus = FocusNode();
  final FocusNode _dns2Focus = FocusNode();
  final List<FocusNode> _presetFocusNodes = List.generate(5, (_) => FocusNode());
  final FocusNode _facebookFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  bool _isLoadingState = false; // Flag to prevent saves during state loading
  String _lastSavedDns1 = '';
  String _lastSavedDns2 = '';
  DateTime? _lastSaveTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    
    _loadAppVersion();
    _loadPersistentState(); // Load all persistent application state

    // Add listeners to DNS controllers to auto-save when changed manually
    _dns1Controller.addListener(() {
      if (!_isLoadingState && _dns1Controller.text.trim() != _lastSavedDns1) {
        debugPrint("DNS1 changed to: ${_dns1Controller.text}");
        _savePersistentState();
      }
    });
    _dns2Controller.addListener(() {
      if (!_isLoadingState && _dns2Controller.text.trim() != _lastSavedDns2) {
        debugPrint("DNS2 changed to: ${_dns2Controller.text}");
        _savePersistentState();
      }
    });

    // Add listeners to all focus nodes to trigger rebuilds when focus changes
    _startStopFocus.addListener(() => setState(() {}));
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
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    
    _dns1Controller.dispose();
    _dns2Controller.dispose();
    _startStopFocus.dispose();
    _dns1Focus.dispose();
    _dns2Focus.dispose();
    _facebookFocus.dispose();
    _emailFocus.dispose();
    for (final node in _presetFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Save state when app goes to background or is paused
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _savePersistentState();
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
                _applyDnsPreset('Google');
                break;
              case 1: // Cloudflare
                _applyDnsPreset('Cloudflare');
                break;
              case 2: // Quad9
                _applyDnsPreset('Quad9');
                break;
              case 3: // Cloudflare Blocking
                _applyDnsPreset('Cloudflare Blocking');
                break;
              case 4: // Quad9 Blocking
                _applyDnsPreset('Quad9 Blocking');
                break;
            }
            return KeyEventResult.handled;
          }
        }
      }

      // Handle directional navigation with circular/wrap-around support
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (focusNode == _startStopFocus) {
          // Go directly to presets when VPN is inactive
          if (!_isVpnActive) {
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
          // Wrap to first preset in the row
          _presetFocusNodes[0].requestFocus();
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
        if (focusNode == _emailFocus) {
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
        if (focusNode == _presetFocusNodes[0] || focusNode == _presetFocusNodes[1] || focusNode == _presetFocusNodes[2]) {
          _startStopFocus.requestFocus();
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
            _startStopFocus.requestFocus();
          }
          return KeyEventResult.handled;
        }
        // Wrap from top controls to bottom
        else if (focusNode == _startStopFocus) {
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
            _startStopFocus.requestFocus(); // Go back to main control
          }
          return KeyEventResult.handled;
        } else if (_presetFocusNodes.contains(focusNode)) {
          _startStopFocus.requestFocus(); // Go back to main control
          return KeyEventResult.handled;
        }
      }

      // Handle menu button (for quick access to main control)
      if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
          event.logicalKey == LogicalKeyboardKey.f1) {
        _startStopFocus.requestFocus(); // Jump to main control
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

  // Load all persistent application state
  Future<void> _loadPersistentState() async {
    debugPrint("=== Starting to load persistent state ===");
    try {
      _isLoadingState = true; // Prevent saves during loading
      final prefs = await SharedPreferences.getInstance();
      
      // Load DNS settings first
      final savedDns1 = prefs.getString('dns1') ?? '8.8.8.8';
      final savedDns2 = prefs.getString('dns2') ?? '8.8.4.4';
      final lastPreset = prefs.getString('lastPreset');
      
      debugPrint("Raw stored values - DNS1: $savedDns1, DNS2: $savedDns2");
      debugPrint("Last preset: ${lastPreset ?? 'none'}");
      
      setState(() {
        // Apply saved DNS values
        _dns1Controller.text = savedDns1;
        _dns2Controller.text = savedDns2;
      });
      
      debugPrint("Applied to controllers - DNS1: ${_dns1Controller.text}, DNS2: ${_dns2Controller.text}");

      // Update tracking variables
      _lastSavedDns1 = savedDns1;
      _lastSavedDns2 = savedDns2;

      // Clean up any legacy duplicate DNS storage
      await prefs.remove('activeVpnDns1');
      await prefs.remove('activeVpnDns2');
      debugPrint("Cleaned up duplicate DNS storage");

      // Check if VPN was previously active and restore it automatically
      final wasVpnActive = prefs.getBool('wasVpnActive') ?? false;
      if (wasVpnActive && mounted) {
        // DNS settings are already loaded above - no need for duplicate values
        // The current DNS settings are the ones that were used for VPN
        
        // Automatically restore VPN connection after a short delay
        // Delay ensures UI is fully initialized
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && !_isVpnActive) {
            debugPrint("Auto-restoring VPN connection at startup");
            _startVpn();
            
            // Show a brief notification about auto-reconnection
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('VPN automatically restored'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
      
    } catch (e) {
      // If loading fails, use default values
      debugPrint("Failed to load persistent state: $e");
    } finally {
      _isLoadingState = false; // Re-enable saving
      debugPrint("=== Completed loading persistent state ===");
    }
  }

  // Save all persistent application state
  Future<void> _savePersistentState() async {
    if (_isLoadingState) return; // Don't save while loading
    
    // Debounce saves - don't save more than once per second
    final now = DateTime.now();
    if (_lastSaveTime != null && now.difference(_lastSaveTime!).inMilliseconds < 1000) {
      debugPrint("Save debounced - too frequent");
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save DNS settings (only one set needed)
      final dns1 = _dns1Controller.text.trim();
      final dns2 = _dns2Controller.text.trim();
      
      bool dnsChanged = (dns1 != _lastSavedDns1 || dns2 != _lastSavedDns2);
      
      await prefs.setString('dns1', dns1);
      await prefs.setString('dns2', dns2);
      
      if (dnsChanged) {
        debugPrint("Saved DNS values: DNS1=$dns1, DNS2=$dns2");
        // Update tracking variables
        _lastSavedDns1 = dns1;
        _lastSavedDns2 = dns2;
      }
      
      _lastSaveTime = now;
      
      // Save VPN connection state
      await prefs.setBool('isVpnActive', _isVpnActive);
      await prefs.setBool('wasVpnActive', _isVpnActive);
      
      // Save VPN session details when active
      if (_isVpnActive) {
        // Only set start timestamp if it doesn't already exist (first connection in this session)
        if (!prefs.containsKey('vpnStartTimestamp')) {
          await prefs.setInt('vpnStartTimestamp', DateTime.now().millisecondsSinceEpoch);
        }
        await prefs.setInt('vpnSessionId', DateTime.now().millisecondsSinceEpoch); // Unique session ID
      } else {
        // Clear VPN session data when disconnected
        await prefs.remove('vpnStartTimestamp'); // Clear start timestamp when stopping
        await prefs.setInt('vpnStopTimestamp', DateTime.now().millisecondsSinceEpoch);
      }
      
      // Save timestamp of last state save
      await prefs.setInt('lastSaveTimestamp', DateTime.now().millisecondsSinceEpoch);
      
    } catch (e) {
      debugPrint("Failed to save persistent state: $e");
    }
  }

  // Save the last used DNS preset
  Future<void> _saveLastPreset(String presetName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastPreset', presetName);
    } catch (e) {
      debugPrint("Failed to save last preset: $e");
    }
  }

  // Clear all persistent state (useful for reset/debugging)
  Future<void> _clearPersistentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint("All persistent state cleared");
    } catch (e) {
      debugPrint("Failed to clear persistent state: $e");
    }
  }

  // Get persistent state info for debugging
  Future<Map<String, dynamic>> _getPersistentStateInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'dns1': prefs.getString('dns1') ?? 'not set',
        'dns2': prefs.getString('dns2') ?? 'not set',
        'lastPreset': prefs.getString('lastPreset') ?? 'not set',
        'isVpnActive': prefs.getBool('isVpnActive') ?? false,
        'wasVpnActive': prefs.getBool('wasVpnActive') ?? false,
        'vpnStartTimestamp': prefs.getInt('vpnStartTimestamp') ?? 0,
        'vpnStopTimestamp': prefs.getInt('vpnStopTimestamp') ?? 0,
        'vpnSessionId': prefs.getInt('vpnSessionId') ?? 0,
        'vpnConnectionCount': prefs.getInt('vpnConnectionCount') ?? 0,
        'lastSaveTimestamp': prefs.getInt('lastSaveTimestamp') ?? 0,
      };
    } catch (e) {
      debugPrint("Failed to get persistent state info: $e");
      return {};
    }
  }

  // Show debug information about persistent state (for development)
  void _showPersistentStateDebugInfo() async {
    final stateInfo = await _getPersistentStateInfo();
    final timestamp = stateInfo['lastSaveTimestamp'] as int;
    final lastSaveTime = timestamp > 0 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
        : 'Never';

    // Format VPN session timestamps
    final vpnStartTimestamp = stateInfo['vpnStartTimestamp'] as int;
    final vpnStopTimestamp = stateInfo['vpnStopTimestamp'] as int;
    final vpnStartTime = vpnStartTimestamp > 0 
        ? DateTime.fromMillisecondsSinceEpoch(vpnStartTimestamp).toString()
        : 'Never';
    final vpnStopTime = vpnStopTimestamp > 0 
        ? DateTime.fromMillisecondsSinceEpoch(vpnStopTimestamp).toString()
        : 'Never';

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Persistent State Debug Info'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DNS Settings:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('DNS1: ${stateInfo['dns1']}'),
                  Text('DNS2: ${stateInfo['dns2']}'),
                  Text('Last Preset: ${stateInfo['lastPreset']}'),
                  const SizedBox(height: 10),
                  const Text('VPN State:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Currently Active: ${stateInfo['isVpnActive']}'),
                  Text('Was Active: ${stateInfo['wasVpnActive']}'),
                  const SizedBox(height: 10),
                  const Text('VPN Sessions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Connection Count: ${stateInfo['vpnConnectionCount']}'),
                  Text('Session ID: ${stateInfo['vpnSessionId']}'),
                  Text('Last Start: $vpnStartTime'),
                  Text('Last Stop: $vpnStopTime'),
                  const SizedBox(height: 10),
                  const Text('System:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Last Save: $lastSaveTime'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearPersistentState();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Persistent state cleared!')),
                  );
                },
                child: const Text('Clear State'),
              ),
            ],
          );
        },
      );
    }
  }

  // Apply DNS preset and remember selection
  void _applyDnsPreset(String preset, {bool saveState = true}) {
    final oldLoadingState = _isLoadingState;
    if (!saveState) {
      _isLoadingState = true; // Temporarily disable saving if requested
    }
    
    setState(() {
      switch (preset) {
        case 'Google':
          _dns1Controller.text = '8.8.8.8';
          _dns2Controller.text = '8.8.4.4';
          break;
        case 'Cloudflare':
          _dns1Controller.text = '1.1.1.1';
          _dns2Controller.text = '1.0.0.1';
          break;
        case 'Quad9':
          _dns1Controller.text = '9.9.9.10';
          _dns2Controller.text = '149.112.112.10';
          break;
        case 'Cloudflare Blocking':
          _dns1Controller.text = '1.1.1.2';
          _dns2Controller.text = '1.0.0.2';
          break;
        case 'Quad9 Blocking':
          _dns1Controller.text = '9.9.9.9';
          _dns2Controller.text = '149.112.112.112';
          break;
      }
    });
    
    _isLoadingState = oldLoadingState; // Restore original loading state
    
    if (saveState) {
      // Save the preset choice and DNS values immediately
      _saveLastPreset(preset);
      _savePersistentState();
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
      
      // Increment connection count for this new connection
      try {
        final prefs = await SharedPreferences.getInstance();
        final connectionCount = prefs.getInt('vpnConnectionCount') ?? 0;
        await prefs.setInt('vpnConnectionCount', connectionCount + 1);
      } catch (e) {
        debugPrint("Failed to increment connection count: $e");
      }
      
      // Save the current state after successful VPN start
      _savePersistentState();
      
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
      
      // Save the current state after successful VPN stop
      _savePersistentState();
      
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
                              
                              // Settings section is now empty but preserved for future use
                              Center(
                                child: Text(
                                  'No additional settings available',
                                  style: TextStyle(
                                    fontSize: isTV ? 10 : (isCompact ? 8 : 9),
                                    color: isTV ? Colors.white54 : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
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
                        // App Version (with long press for debug info)
                        GestureDetector(
                          onLongPress: _showPersistentStateDebugInfo,
                          child: Text(
                            'Version $_appVersion',
                            style: TextStyle(
                              fontSize: isTV ? 12 : (isCompact ? 10 : 11),
                              color: isTV ? Colors.white70 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
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
      // Removed onEditingComplete - controller listeners already handle saving
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
