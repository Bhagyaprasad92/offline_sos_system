import 'package:flutter/material.dart';
import 'package:offline_sos_system/offline_sos_system.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline SOS System Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const SOSExampleHomePage(),
    );
  }
}

class SOSExampleHomePage extends StatefulWidget {
  const SOSExampleHomePage({super.key});

  @override
  State<SOSExampleHomePage> createState() => _SOSExampleHomePageState();
}

class _SOSExampleHomePageState extends State<SOSExampleHomePage> {
  // Instantiate the package engine
  final SafePulseEngine _engine = SafePulseEngine();

  bool _isEngineRunning = false;
  String _statusMessage = "Engine Stopped";
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    // Start listening to the package's crash event stream
    _engine.onCrashDetected.listen((CrashEvent event) {
      setState(() {
        final timestamp = event.timestamp;
        _eventLog.insert(
          0,
          "[${timestamp.toIso8601String().substring(11, 19)}] 💥 Crash Detected! Prob: ${(event.probability * 100).toStringAsFixed(1)}%",
        );
      });
    });
  }

  Future<void> _toggleEngine() async {
    try {
      if (_isEngineRunning) {
        await _engine.stop();
        setState(() {
          _isEngineRunning = false;
          _statusMessage = "Engine Stopped";
        });
      } else {
        await _engine.start();
        setState(() {
          _isEngineRunning = true;
          _statusMessage =
              "Engine Monitoring Active... Move device to test simulation.";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        title: const Text('SOS System Test Bench'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isEngineRunning ? Icons.radar : Icons.power_settings_new,
                      size: 48,
                      color: _isEngineRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleEngine,
              icon: Icon(_isEngineRunning ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isEngineRunning ? 'Stop Detection' : 'Start Detection',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isEngineRunning
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Real-time Detection Log:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    _eventLog.isEmpty
                        ? const Center(
                          child: Text('No anomalies recorded yet.'),
                        )
                        : ListView.builder(
                          itemCount: _eventLog.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const Icon(
                                Icons.warning,
                                color: Colors.amber,
                              ),
                              title: Text(_eventLog[index]),
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
