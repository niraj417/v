import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/templates_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LeadGeneratorApp());
}

class LeadGeneratorApp extends StatelessWidget {
  const LeadGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lead Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/leads': (context) => const LeadsScreen(),
        '/templates': (context) => const TemplatesScreen(),
      },
    );
  }
}
