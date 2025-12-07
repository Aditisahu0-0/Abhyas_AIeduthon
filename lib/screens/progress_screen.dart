import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../utils/app_theme.dart';
import 'subject_history_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    // Load fresh stats whenever the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CourseProvider>(context, listen: false).loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress'), centerTitle: true),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          final stats = provider.stats;
          final dailyActivity =
              stats['daily_activity'] as List<int>? ?? List.filled(7, 0);
          final points = stats['points'] as int? ?? 0;
          final streak = stats['streak'] as int? ?? 0;
          final totalQuestions = stats['total_questions'] as int? ?? 0;

          double overallProgress = 0.0;
          // Daily Goal Logic (e.g. 20 questions a day)
          const int dailyGoal = 20;

          if (totalQuestions > 0) {
            overallProgress = totalQuestions / dailyGoal;
            if (overallProgress > 1.0) overallProgress = 1.0;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Progress Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Progress',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalQuestions / 20 Daily Goal',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        // Circular Progress Indicator
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: overallProgress,
                                strokeWidth: 8,
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppTheme.darkCard
                                    : Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.cyanAccent,
                                ),
                              ),
                              Text(
                                '${(overallProgress * 100).toInt()}%',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.cyanAccent,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Statistics Section
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.star_rounded,
                        value: points.toString(),
                        label: 'Points',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.local_fire_department_rounded,
                        value: streak.toString(),
                        label: 'Day Streak',
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Performance Chart Section
                Text(
                  'Last 7 Days Activity',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(7, (index) {
                              final count = dailyActivity[index];
                              final maxCount = dailyActivity.reduce(
                                (curr, next) => curr > next ? curr : next,
                              );
                              final max = maxCount > 0
                                  ? maxCount
                                  : 10; // Avoid division by zero, set min scale
                              final heightFactor = (count / max).clamp(
                                0.1,
                                1.0,
                              ); // Min height 10%

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    count.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 20,
                                    height: 150 * heightFactor,
                                    decoration: BoxDecoration(
                                      color: AppTheme.cyanAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getDayLabel(index),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Subject Performance Section
                Text(
                  'Subject History',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                if (provider.courses.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No subjects available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: provider.courses.map((course) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SubjectHistoryScreen(course: course),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.cyanAccent.withOpacity(
                              0.2,
                            ),
                            child: const Icon(
                              Icons.book_rounded,
                              color: AppTheme.cyanAccent,
                            ),
                          ),
                          title: Text(course.title),
                          subtitle: const Text('Tap to view history'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getDayLabel(int index) {
    // 0 = 6 days ago, 6 = today
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    const days = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ]; // Simple mapping or use DateFormat
    return days[date.weekday % 7];
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
