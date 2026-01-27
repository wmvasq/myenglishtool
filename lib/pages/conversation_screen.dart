import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ConversationScreen extends StatefulWidget {
  final List<dynamic> conversation; // list of (myEnglishTool / learner)

  const ConversationScreen({super.key, required this.conversation});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final FlutterTts tts = FlutterTts();
  late stt.SpeechToText speech;

  String recognizedText = "";
  bool isListening = false;
  @override
  void initState() {
    super.initState();

    speech = stt.SpeechToText();

    // Configure TTS
    tts.setLanguage("en-US");
    tts.setPitch(1.0);
    tts.setSpeechRate(0.4); // slower for learner experience
  }

  Future<void> startListening(String expectedText) async {
    bool available = await speech.initialize();

    if (!available) return;

    setState(() {
      isListening = true;
      recognizedText = "";
    });

    speech.listen(
      localeId: "en_US",
      onResult: (result) {
        setState(() {
          recognizedText = result.recognizedWords;
        });

        if (result.finalResult) {
          compareText(expectedText, recognizedText);
        }
      },
    );
  }

  void stopListening() {
    speech.stop();
    setState(() {
      isListening = false;
    });
  }

  void compareText(String expected, String spoken) {
    final score = similarity(expected.toLowerCase(), spoken.toLowerCase());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          score > 0.85
              ? "💯 Almost perfect!"
              : score > 0.6
              ? "🙂 Good try! Keep practicing."
              : "⚠️ Try again.",
        ),
      ),
    );
  }

  Future<void> speak(String text) async {
    await tts.stop(); // prevent overlapping voices
    await tts.speak(text);
  }

  double similarity(String a, String b) {
    final wordsA = a.split(" ");
    final wordsB = b.split(" ");

    int matches = 0;

    for (var w in wordsA) {
      if (wordsB.contains(w)) matches++;
    }

    return matches / wordsA.length;
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conversation")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.conversation.length,
        itemBuilder: (_, index) {
          final msg = widget.conversation[index];

          // Check who is speaking
          final bool fromTool = msg.containsKey('myEnglishTool');
          final String text = fromTool ? msg['myEnglishTool'] : msg['learner'];

          return Align(
            alignment: fromTool ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: fromTool ? Colors.blue[100] : Colors.green[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: fromTool
                      ? const Radius.circular(0)
                      : const Radius.circular(16),
                  bottomRight: fromTool
                      ? const Radius.circular(16)
                      : const Radius.circular(0),
                ),
              ),

              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // text
                  Flexible(
                    child: Text(text, style: const TextStyle(fontSize: 16)),
                  ),

                  // 🔊 Speaker only for myEnglishTool turns
                  if (fromTool)
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 22),
                      onPressed: () => speak(text),
                    ),

                  if (!fromTool)
                    IconButton(
                      icon: Icon(
                        isListening ? Icons.mic_off : Icons.mic,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        if (isListening) {
                          stopListening();
                        } else {
                          startListening(text);
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
