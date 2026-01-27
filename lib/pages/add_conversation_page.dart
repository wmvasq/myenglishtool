import 'dart:convert';
import 'package:flutter/material.dart';
import '../db_helper.dart';

class AddConversationPage extends StatefulWidget {
  const AddConversationPage({super.key});

  @override
  State<AddConversationPage> createState() => _AddConversationPageState();
}

class _AddConversationPageState extends State<AddConversationPage> {
  final TextEditingController _jsonController = TextEditingController();
  final DBHelper _dbHelper = DBHelper();

  void _saveConversation() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a JSON first.')),
      );
      return;
    }

    try {
      // Validate JSON structure
      final Map<String, dynamic> parsed = jsonDecode(text);

      // Save to DB
      final id = await _dbHelper.insertConversation(parsed);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Conversation saved with ID: $id')),
      );

      _jsonController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Invalid JSON format: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Conversation')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Paste a JSON conversation below:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _jsonController,
                decoration: const InputDecoration(
                  hintText: '[{"myEnglishTool":"Hi","order":1}]',
                  border: OutlineInputBorder(),
                ),
                maxLines: null, // allow multiple lines
                expands: true,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveConversation,
              icon: const Icon(Icons.save),
              label: const Text('Save Conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
