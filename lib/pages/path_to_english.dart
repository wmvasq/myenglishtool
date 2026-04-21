import 'package:flutter/material.dart';
import '../db_helper.dart';

class PathToEnglish extends StatefulWidget {
  const PathToEnglish({super.key});

  @override
  State<PathToEnglish> createState() => _PathToEnglishState();
}

class _PathToEnglishState extends State<PathToEnglish> {
  final DBHelper _dbHelper = DBHelper();
  double overallScore = 0.0;
  int totalMinutes = 0;
  List<Map<String, dynamic>> convScores = [];
  List<Map<String, dynamic>> aiScores = [];

  static const List<Map<String, dynamic>> levels = [
    {
      'level': 'A1',
      'name': 'Principiante',
      'minHours': 0,
      'maxHours': 100,
      'color': Colors.red,
    },
    {
      'level': 'A2',
      'name': 'Elemental',
      'minHours': 100,
      'maxHours': 350,
      'color': Colors.orange,
    },
    {
      'level': 'B1',
      'name': 'Intermedio',
      'minHours': 350,
      'maxHours': 700,
      'color': Color(0xFFF9A825),
    },
    {
      'level': 'B2',
      'name': 'Intermedio-Alto',
      'minHours': 700,
      'maxHours': 1200,
      'color': Colors.lightGreen,
    },
    {
      'level': 'C1',
      'name': 'Avanzado',
      'minHours': 1200,
      'maxHours': 2000,
      'color': Colors.green,
    },
    {
      'level': 'C2',
      'name': 'Dominio',
      'minHours': 2000,
      'maxHours': 9999,
      'color': Colors.teal,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final score = await _dbHelper.getOverallAverageScore();
    final minutes = await _dbHelper.getTotalPracticeMinutes();
    final conv = await _dbHelper.getDailyPracticeScores();
    final ai = await _dbHelper.getAISessionScores();
    setState(() {
      overallScore = score;
      totalMinutes = minutes;
      convScores = conv;
      aiScores = ai;
    });
  }

  Map<String, dynamic> _getCurrentLevel() {
    final hours = totalMinutes / 60.0;
    for (var level in levels) {
      if (hours < (level['maxHours'] as int)) {
        return level;
      }
    }
    return levels.last;
  }

  Map<String, dynamic> _getNextLevel(Map<String, dynamic> current) {
    final idx = levels.indexOf(current);
    if (idx < levels.length - 1) {
      return levels[idx + 1];
    }
    return current;
  }

  double _getScoreBasedLevelPercent() {
    if (overallScore >= 0.85) return 0.90;
    if (overallScore >= 0.70) return 0.75;
    if (overallScore >= 0.55) return 0.55;
    if (overallScore >= 0.35) return 0.35;
    if (overallScore >= 0.20) return 0.20;
    return overallScore;
  }

  double _getHoursInCurrentLevel() {
    final current = _getCurrentLevel();
    final currentMinHours = (current['minHours'] as int).toDouble();
    final hours = totalMinutes / 60.0;
    return (hours - currentMinHours).clamp(0, double.infinity);
  }

  double _getHoursNeededForNextLevel() {
    final current = _getCurrentLevel();
    final next = _getNextLevel(current);
    final hours = totalMinutes / 60.0;
    return (next['minHours'] as int) - hours;
  }

  int _getLessonsEquivalent() {
    return (_getHoursNeededForNextLevel() * 4).round();
  }

  Color _getScoreColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.60)
      return Color.lerp(Colors.orange, Colors.green, (score - 0.60) / 0.25)!;
    return Color.lerp(Colors.red, Colors.orange, score / 0.60)!;
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _getCurrentLevel();
    final nextLevel = _getNextLevel(currentLevel);
    final hoursNeeded = _getHoursNeededForNextLevel();
    final levelPercent = _getScoreBasedLevelPercent();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PathToEnglish'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentLevelCard(currentLevel, levelPercent),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 16),
              _buildNextLevelCard(nextLevel, hoursNeeded),
              const SizedBox(height: 24),
              _buildLevelProgress(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLevelCard(Map<String, dynamic> level, double percent) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              (level['color'] as Color).withValues(alpha: 0.8),
              (level['color'] as Color),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    level['level'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  level['name'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(percent * 100).toStringAsFixed(0)}% hacia ${_getNextLevel(level)['level']}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final hours = totalMinutes / 60.0;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer,
            value: '${hours.toStringAsFixed(1)}h',
            label: 'Práctica Total',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            value: '${(overallScore * 100).toStringAsFixed(0)}%',
            label: 'Promedio',
            color: _getScoreColor(overallScore),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextLevelCard(
    Map<String, dynamic> nextLevel,
    double hoursNeeded,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Siguiente: ${nextLevel['level']} - ${nextLevel['name']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⏱️ Horas faltantes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '~${hoursNeeded.toStringAsFixed(0)}h',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📝 Lecciones equivalentes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '~${_getLessonsEquivalent()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Niveles MCER',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Marco Común Europeo de Referencia',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...levels.map((level) => _buildLevelRow(level)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(Map<String, dynamic> level) {
    final current = _getCurrentLevel();
    final isCurrent = level['level'] == current['level'];
    final hours = totalMinutes / 60.0;
    final isReached = hours >= (level['minHours'] as int);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isReached ? (level['color'] as Color) : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                level['level'] as String,
                style: TextStyle(
                  color: isReached ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level['name'] as String,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isReached ? Colors.black : Colors.grey,
                  ),
                ),
                Text(
                  '${level['minHours']}-${level['maxHours'] == 9999 ? '∞' : level['maxHours']} horas',
                  style: TextStyle(
                    fontSize: 12,
                    color: isReached ? Colors.grey[600] : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Actual',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final allScores = [...convScores, ...aiScores];
    allScores.sort(
      (a, b) => (b['date'] as String).compareTo(a['date'] as String),
    );
    final last7 = allScores.take(7).toList();

    if (last7.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimos 7 días',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: last7.map((entry) {
                  final score = (entry['avg_score'] as num).toDouble();
                  final date = entry['date'] as String;
                  final parts = date.split('-');
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 30,
                        height: 60 * score,
                        decoration: BoxDecoration(
                          color: _getScoreColor(score),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${parts[1]}/${parts[2]}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
