import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const VpnApp());
}

// ==========================================
// 1. MODELS
// ==========================================
class ServerModel {
  final String id;
  final String country;
  final String flagEmoji;
  final bool isPremium;
  final String wgConfig; // إعدادات WireGuard الكاملة

  ServerModel({
    required this.id,
    required this.country,
    required this.flagEmoji,
    required this.isPremium,
    required this.wgConfig,
  });
}

// ==========================================
// 2. STATE MANAGEMENT (Provider)
// ==========================================
enum VpnStatus { disconnected, connecting, connected, error }

class VpnProvider extends ChangeNotifier {
  // قناة التواصل مع كود الكوتلن (Native Android)
  static const platform = MethodChannel('com.turbo.vpn/native');

  VpnStatus _status = VpnStatus.disconnected;
  String _downloadSpeed = "0.0 Mbps";
  String _uploadSpeed = "0.0 Mbps";
  ServerModel? _selectedServer;
  bool _isPremium = false; // يجب ربطها بالـ Backend لاحقاً

  VpnStatus get status => _status;
  String get downloadSpeed => _downloadSpeed;
  String get uploadSpeed => _uploadSpeed;
  ServerModel? get selectedServer => _selectedServer;
  bool get isPremium => _isPremium;

  void selectServer(ServerModel server) {
    _selectedServer = server;
    notifyListeners();
  }

  Future<void> toggleConnection() async {
    if (_selectedServer == null) return;

    if (_status == VpnStatus.connected || _status == VpnStatus.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    _status = VpnStatus.connecting;
    notifyListeners();

    try {
      // 1. طلب صلاحية الـ VPN من أندرويد عبر الكوتلن
      final bool hasPermission = await platform.invokeMethod('requestVpnPermission');
      
      if (!hasPermission) {
        _status = VpnStatus.disconnected;
        notifyListeners();
        return;
      }

      // 2. بدء خدمة الـ VPN وتمرير إعدادات WireGuard
      await platform.invokeMethod('startVpn', {
        'config': _selectedServer!.wgConfig,
        'serverId': _selectedServer!.id
      });

      _status = VpnStatus.connected;
      // محاكاة لقياس السرعة (يتم استبدالها بقياس حقيقي لاحقاً)
      _downloadSpeed = "45.2 Mbps";
      _uploadSpeed = "12.8 Mbps";
    } on PlatformException catch (e) {
      print("Failed to connect: ${e.message}");
      _status = VpnStatus.error;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _status = VpnStatus.connecting;
    notifyListeners();
    try {
      await platform.invokeMethod('stopVpn');
      _status = VpnStatus.disconnected;
      _downloadSpeed = "0.0 Mbps";
      _uploadSpeed = "0.0 Mbps";
    } on PlatformException catch (e) {
      print("Failed to disconnect: ${e.message}");
      _status = VpnStatus.error;
    }
    notifyListeners();
  }
}

// ==========================================
// 3. UI SCREENS
// ==========================================
class VpnApp extends StatelessWidget {
  const VpnApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VpnProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Turbo VPN',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: const Color(0xFF1E1E1E),
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);

    Color buttonColor;
    String buttonText;
    IconData buttonIcon;

    switch (vpn.status) {
      case VpnStatus.connected:
        buttonColor = const Color(0xFF00E676);
        buttonText = "Connected";
        buttonIcon = Icons.shield;
        break;
      case VpnStatus.connecting:
        buttonColor = const Color(0xFFFFC107);
        buttonText = "Connecting...";
        buttonIcon = Icons.sync;
        break;
      case VpnStatus.error:
        buttonColor = Colors.red;
        buttonText = "Error";
        buttonIcon = Icons.error;
        break;
      default:
        buttonColor = const Color(0xFF2196F3);
        buttonText = "Connect";
        buttonIcon = Icons.shield_moon;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Turbo VPN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.workspace_premium, color: Colors.amber),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen()));
                    },
                  )
                ],
              ),
            ),
            
            // Connection Button
            Expanded(
              flex: 3,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (vpn.selectedServer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a server first")),
                      );
                      return;
                    }
                    vpn.toggleConnection();
                  },
                  child: Container(
                    height: 220,
                    width: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: buttonColor.withOpacity(0.1),
                      border: Border.all(color: buttonColor, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: buttonColor.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(buttonIcon, size: 80, color: buttonColor),
                        const SizedBox(height: 10),
                        Text(buttonText, style: TextStyle(color: buttonColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Speed Indicators
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSpeedCard("Download", vpn.downloadSpeed, Icons.arrow_downward, Colors.green),
                  _buildSpeedCard("Upload", vpn.uploadSpeed, Icons.arrow_upward, Colors.blue),
                ],
              ),
            ),
            
            // Server Selection Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ServersScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(vpn.selectedServer?.flagEmoji ?? "🌍", style: const TextStyle(fontSize: 30)),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vpn.selectedServer?.country ?? "Select Server", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                              Text(vpn.selectedServer?.isPremium == true ? "Premium Server" : "Free Server", style: TextStyle(color: Colors.grey.shade400)),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedCard(String title, String speed, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 5),
          Text(speed, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}

class ServersScreen extends StatelessWidget {
  const ServersScreen({Key? key}) : super(key: key);

  // بيانات وهمية للتجربة (يجب استبدالها بالبيانات القادمة من الـ Backend)
  final List<ServerModel> servers = const [
    ServerModel(id: '1', country: 'United States', flagEmoji: '🇺🇸', isPremium: false, wgConfig: 'dummy_config'),
    ServerModel(id: '2', country: 'Germany', flagEmoji: '🇩🇪', isPremium: false, wgConfig: 'dummy_config'),
    ServerModel(id: '3', country: 'United Kingdom', flagEmoji: '🇬🇧', isPremium: true, wgConfig: 'dummy_config'),
    ServerModel(id: '4', country: 'Japan', flagEmoji: '🇯🇵', isPremium: true, wgConfig: 'dummy_config'),
  ];

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context, listen: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Select Server'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Free'),
              Tab(text: 'VIP 🔒'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildServerList(context, servers.where((s) => !s.isPremium).toList(), vpn),
            _buildServerList(context, servers.where((s) => s.isPremium).toList(), vpn),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context, List<ServerModel> list, VpnProvider vpn) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final server = list[index];
        return ListTile(
          leading: Text(server.flagEmoji, style: const TextStyle(fontSize: 30)),
          title: Text(server.country),
          subtitle: Text(server.isPremium ? "Premium Server" : "Free Server", style: TextStyle(color: Colors.grey.shade400)),
          trailing: vpn.selectedServer?.id == server.id
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {
            if (server.isPremium && !vpn.isPremium) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen()));
            } else {
              vpn.selectServer(server);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Go Premium'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 10),
            const Text('Unlock All VIP Servers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Enjoy high-speed connection with no ads', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            _buildPlanCard(context, '1 Month', '\$4.99', '/month', false),
            const SizedBox(height: 15),
            _buildPlanCard(context, '1 Year', '\$29.99', '/year', true),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, String title, String price, String duration, bool isPopular) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isPopular ? Colors.amber : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (isPopular)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(5)),
                        child: const Text('Best Value', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
                const SizedBox(height: 5),
                const Text('Access all servers', style: TextStyle(color: Colors.grey)),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? Colors.amber : Colors.blue,
              ),
              onPressed: () {
                // TODO: استدعاء Google Play Billing لاحقاً
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Initiating purchase for $title...")),
                );
              },
              child: Text('$price\n$duration', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
