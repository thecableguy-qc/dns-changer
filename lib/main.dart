
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DNS VPN Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
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
          SnackBar(content: Text("Failed to start VPN: $e")),
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
          SnackBar(content: Text("Failed to stop VPN: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect if running on TV by checking screen size and orientation
    final mediaQuery = MediaQuery.of(context);
    final isTV = mediaQuery.size.width > 1000 || mediaQuery.size.aspectRatio > 1.5;

    return Scaffold(
      appBar: AppBar(
        title: const Text("DNS VPN Demo"),
        centerTitle: true,
        backgroundColor: isTV ? Colors.black87 : null,
      ),
      backgroundColor: isTV ? Colors.black : null,
      body: Container(
        padding: EdgeInsets.all(isTV ? 32.0 : 16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTV ? 800 : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // VPN Status
                  Container(
                    padding: EdgeInsets.all(isTV ? 24 : 16),
                    decoration: BoxDecoration(
                      color: _isVpnActive ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(isTV ? 16 : 8),
                      border: Border.all(
                        color: _isVpnActive ? Colors.green : Colors.red,
                        width: isTV ? 3 : 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isVpnActive ? Icons.vpn_key : Icons.vpn_key_off,
                          color: _isVpnActive ? Colors.green : Colors.red,
                          size: isTV ? 48 : 32,
                        ),
                        SizedBox(width: isTV ? 24 : 8),
                        Text(
                          _isVpnActive ? "VPN Active" : "VPN Inactive",
                          style: TextStyle(
                            fontSize: isTV ? 24 : 18,
                            fontWeight: FontWeight.bold,
                            color: _isVpnActive ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isTV ? 48 : 30),

                  // DNS Configuration Section
                  Text(
                    "DNS Configuration",
                    style: TextStyle(
                      fontSize: isTV ? 28 : 20,
                      fontWeight: FontWeight.bold,
                      color: isTV ? Colors.white : Colors.black87,
                    ),
                  ),

                  SizedBox(height: isTV ? 32 : 20),

                  // Primary DNS
                  _buildDnsInputField(
                    controller: _dns1Controller,
                    label: "Primary DNS Server",
                    hint: "e.g., 8.8.8.8",
                    enabled: !_isVpnActive,
                    isTV: isTV,
                  ),

                  SizedBox(height: isTV ? 24 : 16),

                  // Secondary DNS
                  _buildDnsInputField(
                    controller: _dns2Controller,
                    label: "Secondary DNS Server",
                    hint: "e.g., 8.8.4.4",
                    enabled: !_isVpnActive,
                    isTV: isTV,
                  ),

                  SizedBox(height: isTV ? 48 : 30),

                  // DNS Presets
                  Text(
                    "Quick Presets",
                    style: TextStyle(
                      fontSize: isTV ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: isTV ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  SizedBox(height: isTV ? 20 : 10),

                  // Preset buttons - arranged for TV navigation
                  isTV ?
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildPresetButton("Google DNS", "8.8.8.8", "8.8.4.4", isTV),
                      _buildPresetButton("Cloudflare", "1.1.1.1", "1.0.0.1", isTV),
                      _buildPresetButton("OpenDNS", "208.67.222.222", "208.67.220.220", isTV),
                      _buildPresetButton("Quad9", "9.9.9.9", "149.112.112.112", isTV),
                    ],
                  ) :
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetButton("Google DNS", "8.8.8.8", "8.8.4.4", isTV),
                        const SizedBox(width: 8),
                        _buildPresetButton("Cloudflare", "1.1.1.1", "1.0.0.1", isTV),
                        const SizedBox(width: 8),
                        _buildPresetButton("OpenDNS", "208.67.222.222", "208.67.220.220", isTV),
                        const SizedBox(width: 8),
                        _buildPresetButton("Quad9", "9.9.9.9", "149.112.112.112", isTV),
                      ],
                    ),
                  ),

                  SizedBox(height: isTV ? 60 : 30),

                  // VPN Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildVpnButton(
                        onPressed: _isVpnActive ? null : _startVpn,
                        icon: Icons.play_arrow,
                        label: "Start VPN",
                        color: Colors.green,
                        isTV: isTV,
                      ),
                      _buildVpnButton(
                        onPressed: _isVpnActive ? _stopVpn : null,
                        icon: Icons.stop,
                        label: "Stop VPN",
                        color: Colors.red,
                        isTV: isTV,
                      ),
                    ],
                  ),
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
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
        fontSize: isTV ? 20 : 16,
        color: isTV ? Colors.white : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: isTV ? 18 : 14,
          color: isTV ? Colors.white70 : null,
        ),
        hintStyle: TextStyle(
          color: isTV ? Colors.white54 : null,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 16 : 8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 16 : 8),
          borderSide: BorderSide(
            color: isTV ? Colors.white30 : Colors.grey,
            width: isTV ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTV ? 16 : 8),
          borderSide: BorderSide(
            color: isTV ? Colors.blue.shade300 : Colors.blue,
            width: 3,
          ),
        ),
        prefixIcon: Icon(
          Icons.dns,
          color: isTV ? Colors.white54 : null,
          size: isTV ? 28 : 24,
        ),
        contentPadding: EdgeInsets.all(isTV ? 20 : 16),
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
  }) {
    return SizedBox(
      width: isTV ? 220 : 140,
      height: isTV ? 70 : 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: isTV ? 32 : 20,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isTV ? 20 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTV ? 20 : 8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTV ? 24 : 20,
            vertical: isTV ? 16 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String name, String dns1, String dns2, bool isTV) {
    return SizedBox(
      width: isTV ? 180 : null,
      height: isTV ? 60 : null,
      child: ElevatedButton(
        onPressed: _isVpnActive ? null : () {
          setState(() {
            _dns1Controller.text = dns1;
            _dns2Controller.text = dns2;
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isTV ? 20 : 12,
            vertical: isTV ? 16 : 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTV ? 16 : 8),
          ),
          backgroundColor: isTV ? Colors.grey.shade800 : null,
          foregroundColor: isTV ? Colors.white : null,
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: isTV ? 18 : 14,
            fontWeight: isTV ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
