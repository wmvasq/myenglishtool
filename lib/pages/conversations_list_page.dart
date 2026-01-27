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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Conversations')),
      body: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          return ListTile(
            title: Text('conversation #' + convo["id"].toString()+" : " +convo["title"].toString()),
            subtitle: Text("${convo['text'].toString().substring(0,50)}..."),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationScreen( conversation:jsonDecode( convo['text']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
