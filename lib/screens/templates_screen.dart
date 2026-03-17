import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _templateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final template = prefs.getString('whatsapp_template');
    if (template != null) {
      _templateController.text = template;
    }
  }

  Future<void> _saveTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_template', _templateController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved locally')),
      );
    }
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Templates'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create a message template to use when contacting leads on WhatsApp. '
              'Use [Name] to automatically insert the business name.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _templateController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message Template',
                border: OutlineInputBorder(),
                hintText: 'Hi [Name], we offer...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveTemplate,
              child: const Text('Save Template'),
            ),
          ],
        ),
      ),
    );
  }
}
