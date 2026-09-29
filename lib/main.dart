import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnythingsHubApp());
}

class SystemLogger {
  static final List<String> _logs = [];

  static void log(String event) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    final formattedLog = "[$timestamp] $event";
    _logs.insert(0, formattedLog);
  }

  static List<String> getLogs() {
    return _logs;
  }
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anythings Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF38BDF8), // Sky 400
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF34D399), // Emerald 400
          surface: Color(0xFF1E293B), // Slate 800
        ),
        fontFamily: 'monospace',
      ),
      home: const HubDashboardView(),
    );
  }
}

class HubDashboardView extends StatefulWidget {
  const HubDashboardView({super.key});

  @override
  State<HubDashboardView> createState() => _HubDashboardViewState();
}

class _HubDashboardViewState extends State<HubDashboardView> {
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemLogger.log("Iniciando secuencia de arranque del Hub...");
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/config.json');
      final Map<String, dynamic> decodedData = json.decode(jsonString);
      setState(() {
        _config = decodedData;
        _isLoading = false;
      });
      SystemLogger.log("Archivo config.json cargado exitosamente.");
    } catch (e) {
      setState(() {
        _config = {"error": "No se pudo cargar config.json"};
        _isLoading = false;
      });
      SystemLogger.log("Error crítico: Falló la lectura de config.json");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANYTHINGS HUB // CORE'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  _buildStatusCard(
                    title: 'SYSTEM STATUS',
                    subtitle: 'Local Processing: ACTIVE\nTelemetry: BLOCKED (0-Trust)',
                    color: Colors.emerald,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CONFIGURACIÓN ACTIVA (ASSETS):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(_config),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SYSTEM AUDIT LOGS:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.builder(
                      itemCount: SystemLogger.getLogs().length,
                      itemBuilder: (context, index) {
                        return Text(
                          SystemLogger.getLogs()[index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Color(0xFF34D399),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard({required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    );
  }
}
