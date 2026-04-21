import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../db_helper.dart';
import '../services/minimax_service.dart';

class AIPracticeScreen extends StatefulWidget {
  const AIPracticeScreen({super.key});

  @override
  State<AIPracticeScreen> createState() => _AIPracticeScreenState();
}

class _AIPracticeScreenState extends State<AIPracticeScreen> {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final MiniMaxService _miniMaxService = MiniMaxService();
  final DBHelper _dbHelper = DBHelper();

  String recognizedText = '';
  bool isListening = false;
  bool isSpeaking = false;
  bool isLoading = false;
  bool isAITurn = false;
  String currentTopic = '';
  String aiMessage = '';
  String lastFeedback = '';
  String? lastSuggestion;
  double lastScore = 0;
  int exchangeCount = 0;
  List<String> conversationHistory = [];
  List<double> scores = [];

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  Future<void> _initTTS() async {
    await tts.setLanguage('en-US');
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.4);
    tts.setCompletionHandler(() {
      if (mounted) setState(() => isSpeaking = false);
    });
    tts.setErrorHandler((msg) {
      if (mounted) setState(() => isSpeaking = false);
    });
  }

  Future<void> startPractice(String topic) async {
    setState(() {
      currentTopic = topic;
      isLoading = true;
      conversationHistory = [];
      scores = [];
      exchangeCount = 0;
      lastFeedback = '';
      lastSuggestion = null;
    });

    final response = await _miniMaxService.startConversation(topic);
    final data = _miniMaxService.parseResponse(response);

    if (data != null) {
      setState(() {
        aiMessage = data['ai_message'] ?? '';
        conversationHistory.add('AI: $aiMessage');
        isAITurn = true;
      });
      await _speak(aiMessage);
      setState(() => isAITurn = false);
    } else {
      setState(() {
        aiMessage = response;
        isAITurn = true;
      });
      await _speak(response);
      setState(() => isAITurn = false);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> startListening() async {
    if (isSpeaking) {
      await stopSpeaking();
    }

    bool available = await speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => isListening = false);
        }
      },
    );

    if (!available) return;

    setState(() {
      isListening = true;
      recognizedText = '';
    });

    speech.listen(
      localeId: 'en_US',
      onResult: (result) {
        setState(() {
          recognizedText = result.recognizedWords;
        });
        if (result.finalResult) {
          setState(() => isListening = false);
          _processUserResponse(recognizedText);
        }
      },
    );
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  Future<void> _processUserResponse(String userText) async {
    if (userText.isEmpty) return;

    setState(() {
      isLoading = true;
      conversationHistory.add('User: $userText');
    });

    final response = await _miniMaxService.evaluateAndContinue(
      currentTopic,
      userText,
      conversationHistory,
    );

    final data = _miniMaxService.parseResponse(response);

    if (data != null) {
      setState(() {
        lastScore = (data['score'] as num?)?.toDouble() ?? 0;
        lastFeedback = data['feedback'] ?? '';
        lastSuggestion = data['suggestion'];
        aiMessage = data['ai_message'] ?? '';
        exchangeCount++;
        scores.add(lastScore);
        isAITurn = true;

        if (data['session_complete'] == true || exchangeCount >= 5) {
          _showSessionSummary();
        }
      });

      conversationHistory.add('AI: $aiMessage');
      await _speak(aiMessage);
      setState(() => isAITurn = false);
    } else {
      setState(() {
        aiMessage = response;
        isAITurn = true;
      });
      await _speak(response);
      setState(() => isAITurn = false);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _speak(String text) async {
    await tts.stop();
    setState(() => isSpeaking = true);
    await tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await tts.stop();
    setState(() => isSpeaking = false);
  }

  Future<void> _showSessionSummary() async {
    final avgScore = scores.isNotEmpty
        ? scores.reduce((a, b) => a + b) / scores.length
        : 0.0;

    await _dbHelper.saveAIPracticeSession(
      currentTopic,
      avgScore,
      exchangeCount,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Topic: $currentTopic'),
            Text('Exchanges: $exchangeCount'),
            Text('Average Score: ${(avgScore * 100).toStringAsFixed(0)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showTopicSelector();
            },
            child: const Text('New Topic'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTopicSelector() {
    setState(() {
      aiMessage = '';
      recognizedText = '';
      lastFeedback = '';
      lastSuggestion = null;
      exchangeCount = 0;
      scores = [];
      conversationHistory = [];
    });
  }

  Color _getScoreColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.6)
      return Color.lerp(Colors.orange, Colors.green, (score - 0.6) / 0.25)!;
    return Color.lerp(Colors.red, Colors.orange, score / 0.6)!;
  }

  @override
  void dispose() {
    tts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          currentTopic.isEmpty ? 'AI Practice' : 'Topic: $currentTopic',
        ),
      ),
      body: currentTopic.isEmpty
          ? _buildTopicSelector()
          : _buildPracticeScreen(),
    );
  }

  Widget _buildTopicSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a topic to practice:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: MiniMaxService.topics.length,
              itemBuilder: (context, index) {
                final topic = MiniMaxService.topics[index];
                return ElevatedButton(
                  onPressed: () => startPractice(topic),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                  ),
                  child: Text(topic),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeScreen() {
    return Column(
      children: [
        if (lastFeedback.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(lastScore),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Score: ${(lastScore * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('${exchangeCount}/5'),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Feedback: $lastFeedback'),
                if (lastSuggestion != null)
                  Text(
                    'Suggestion: $lastSuggestion',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (aiMessage.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(aiMessage)),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            onPressed: () => _speak(aiMessage),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[200],
          child: Column(
            children: [
              if (recognizedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'You said: $recognizedText',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isLoading)
                    ElevatedButton.icon(
                      onPressed: isAITurn
                          ? null
                          : (isListening
                                ? stopListening
                                : (isSpeaking ? stopSpeaking : startListening)),
                      icon: Icon(
                        isListening
                            ? Icons.stop
                            : (isSpeaking ? Icons.volume_off : Icons.mic),
                      ),
                      label: Text(
                        isAITurn
                            ? 'AI speaking...'
                            : (isListening
                                  ? 'Stop'
                                  : (isSpeaking ? 'Stop TTS' : 'Speak')),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isListening || isSpeaking
                            ? Colors.red
                            : (isAITurn ? Colors.grey : Colors.green),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  if (isLoading) const CircularProgressIndicator(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
