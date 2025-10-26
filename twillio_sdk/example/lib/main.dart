import 'package:flutter/material.dart';
import 'package:twillio_sdk/twillio_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ExampleScreen(),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    TwillioSdk.events.listen((event) {
      print("Twilio Event: $event");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Twilio SDK Test")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: "Enter Twilio Token"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await TwillioSdk.connect(_tokenController.text.trim());
              },
              child: const Text("Connect"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: TwillioSdk.disconnect,
              child: const Text("Disconnect"),
            ),
          ],
        ),
      ),
    );
  }
}
