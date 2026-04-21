import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../db_helper.dart';

class ConversationScreen extends StatefulWidget {
  final List<dynamic> conversation;
  final int conversationId;

  const ConversationScreen({
    super.key,
    required this.conversation,
    required this.conversationId,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final FlutterTts tts = FlutterTts();
  late stt.SpeechToText speech;
  final DBHelper _dbHelper = DBHelper();

  String recognizedText = "";
  bool isListening = false;
  int? activeIndex;
  Map<int, double> phraseScores = {};

  double score = 0;

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
    tts.setLanguage("en-US");
    tts.setPitch(1.0);
    tts.setSpeechRate(0.4);
    _loadPhraseScores();
  }

  Future<void> _loadPhraseScores() async {
    final scores = await _dbHelper.getPhraseScores(widget.conversationId);
    setState(() {
      phraseScores = scores;
    });
  }

  String _cleanText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?]'), '') // Elimina puntos, comas, signos
        .trim(); // Quita espacios extra al inicio/final
  }

  Future<void> startListening(String expectedText, int index) async {
    bool available = await speech.initialize(
      onStatus: (status) {
        // CAMBIO AUTOMÁTICO DE ICONO: Si el sistema deja de escuchar por sí solo
        if (status == 'done' || status == 'notListening') {
          setState(() => isListening = false);
        }
      },
    );

    if (!available) return;

    setState(() {
      isListening = true;
      activeIndex =
          index; // Marcamos qué item de la lista debe mostrar el texto
      recognizedText = "";
    });

    speech.listen(
      localeId: "en_US",
      onResult: (result) {
        setState(() {
          recognizedText = result.recognizedWords;
        });

        if (result.finalResult) {
          setState(() => isListening = false);
          compareText(expectedText, recognizedText, index);
        }
      },
    );
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  // Se mantiene tu lógica de puntaje y snackbar
  void compareText(String expected, String spoken, int phraseIndex) {
    final cleanExpected = _cleanText(expected);
    final cleanSpoken = _cleanText(spoken);

    score = similarity(cleanExpected, cleanSpoken);

    final currentMax = phraseScores[phraseIndex] ?? 0;
    if (score > currentMax) {
      phraseScores[phraseIndex] = score;
      _dbHelper.savePhraseScore(widget.conversationId, phraseIndex, score);
      _dbHelper.updateConversationMaxScore(widget.conversationId);
      setState(() {});
    }
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  double similarity(String a, String b) {
    final wordsA = a.split(" ").where((w) => w.isNotEmpty).toSet();
    final wordsB = b.split(" ").where((w) => w.isNotEmpty).toSet();

    if (wordsA.isEmpty) return 0.0;

    int matches = 0;
    for (var w in wordsA) {
      if (wordsB.contains(w)) {
        matches++;
      }
    }

    return matches / wordsA.length;
  }

  Color _getScoreColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.6)
      return Color.lerp(Colors.orange, Colors.green, (score - 0.6) / 0.25)!;
    return Color.lerp(Colors.red, Colors.orange, score / 0.6)!;
  }

  @override
  void dispose() {
    if (phraseScores.isNotEmpty) {
      final avg =
          phraseScores.values.reduce((a, b) => a + b) / phraseScores.length;
      _dbHelper.saveDailyPractice(widget.conversationId, avg);
    }
    tts.stop();
    speech.stop();
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
          final bool fromTool = msg.containsKey('myEnglishTool');
          final String text = fromTool ? msg['myEnglishTool'] : msg['learner'];

          // ¿Es esta la burbuja que está recibiendo el audio?
          final bool isCurrentActive = activeIndex == index;

          return Align(
            alignment: fromTool ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(14),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              decoration: BoxDecoration(
                color: fromTool ? Colors.blue[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(text, style: const TextStyle(fontSize: 16)),
                      ),
                      if (!fromTool && phraseScores.containsKey(index))
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(phraseScores[index]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(phraseScores[index]! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (fromTool)
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 22),
                          onPressed: () => speak(text),
                        ),
                      if (!fromTool)
                        IconButton(
                          icon: Icon(
                            (isListening && isCurrentActive)
                                ? Icons.stop
                                : Icons.mic,
                            color: (isListening && isCurrentActive)
                                ? Colors.red
                                : Colors.green[700],
                          ),
                          onPressed: () {
                            if (isListening && isCurrentActive) {
                              stopListening();
                            } else {
                              startListening(text, index);
                            }
                          },
                        ),
                    ],
                  ),

                  // TEXTO HABLADO: Solo se muestra en la burbuja activa del learner
                  if (!fromTool && isCurrentActive && recognizedText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Colors.black26),
                          Text(
                            recognizedText +
                                ": (${(score * 100).toStringAsFixed(0)}%)",
                            style: const TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
