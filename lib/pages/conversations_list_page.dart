import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myenglishtool/pages/conversation_screen.dart';
import '../db_helper.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> conversations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _dbHelper.getAllConversations();
    setState(() {
      conversations = data;
    });
  }

  Color _getScoreColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.6)
      return Color.lerp(Colors.orange, Colors.green, (score - 0.6) / 0.25)!;
    return Color.lerp(Colors.red, Colors.orange, score / 0.6)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Conversations')),
      body: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          final convoId = convo['id'] as int;
          final maxScore = convo['conversation_max_score'] as double? ?? 0;
          return ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text('conversation #$convoId : ${convo["title"]}'),
                ),
                if (maxScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getScoreColor(maxScore),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(maxScore * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text("${convo['text'].toString().substring(0, 50)}..."),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationScreen(
                    conversation: jsonDecode(convo['text']),
                    conversationId: convoId,
                  ),
                ),
              ).then((_) => _loadData());
            },
          );
        },
      ),
    );
  }
}
