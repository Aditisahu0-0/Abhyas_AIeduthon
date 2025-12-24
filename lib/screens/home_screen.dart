import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../services/model_downloader.dart';
import '../services/sync_service.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'course_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule initialization for after the first frame to avoid setState errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final provider = Provider.of<CourseProvider>(context, listen: false);
    final downloader = Provider.of<ModelDownloader>(context, listen: false);

    // Set context for provider
    provider.setContext(context);

    // Load all courses
    await provider.loadCourses();

    // Initialize AI if model exists
    final modelExists = await downloader.checkModelExists();
    if (modelExists) {
      print('Model found, initializing AI...');
      await provider.initAI();
      print('AI initialized!');
    } else {
      print('Model not found, using fallback features');
    }
  }

  List<Color> _getGradientColors(int index) {
    final gradients = [
      AppTheme.scienceGradient,
      AppTheme.mathGradient,
      AppTheme.historyGradient,
      AppTheme.geographyGradient,
      AppTheme.englishGradient,
      AppTheme.computersGradient,
    ];
    return gradients[index % gradients.length];
  }

  IconData _getSubjectIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('science') ||
        lowerTitle.contains('physics') ||
        lowerTitle.contains('chemistry')) {
      return Icons.science_rounded;
    } else if (lowerTitle.contains('math')) {
      return Icons.calculate_rounded;
    } else if (lowerTitle.contains('history')) {
      return Icons.history_edu_rounded;
    } else if (lowerTitle.contains('geography')) {
      return Icons.public_rounded;
    } else if (lowerTitle.contains('english') ||
        lowerTitle.contains('language')) {
      return Icons.menu_book_rounded;
    } else if (lowerTitle.contains('computer')) {
      return Icons.computer_rounded;
    }
    return Icons.book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: SafeArea(
        child: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.courses.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ABHYAS Logo
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppTheme.cyanAccent,
                              AppTheme.cyanSecondary,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            languageService.translate('ABHYAS'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // User Greeting
                        Text(
                          '${languageService.translate('Hi')}, ${authService.userName ?? languageService.translate('Student')}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),

                // Your Subjects Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      languageService.translate('Your Subjects'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),

                // Subject Cards Grid
                if (provider.courses.isEmpty)
                  SliverFillRemaining(
                    child: Center(child: Text(languageService.translate('No courses available offline.'))),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final course = provider.courses[index];
                        final gradientColors = _getGradientColors(index);
                        final icon = _getSubjectIcon(course.title);

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CourseDetailsScreen(course: course),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: gradientColors.first.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    icon,
                                    size: 48,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const Spacer(),
                                  Text(
                                    course.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }, childCount: provider.courses.length),
                    ),
                  ),

                // Sync Status at Bottom
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Consumer<SyncService>(
                      builder: (context, syncService, child) {
                        String statusText;
                        Color statusColor;
                        IconData statusIcon;

                        switch (syncService.status) {
                          case SyncStatus.syncing:
                            statusText = languageService.translate('Syncing...');
                            statusColor = Colors.blue;
                            statusIcon = Icons.sync;
                            break;
                          case SyncStatus.success:
                            statusText = languageService.translate('Synced');
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle;
                            break;
                          case SyncStatus.error:
                            statusText = languageService.translate('Sync Error');
                            statusColor = Colors.red;
                            statusIcon = Icons.error_outline;
                            break;
                          case SyncStatus.idle:
                          default:
                            statusText = languageService.translate('Up to date');
                            statusColor = Colors.grey;
                            statusIcon = Icons.cloud_done;
                            break;
                        }

                        String timeText = '';
                        if (syncService.lastSyncTime != null) {
                          final diff = DateTime.now().difference(
                            syncService.lastSyncTime!,
                          );
                          if (diff.inMinutes < 1) {
                            timeText = languageService.translate('Just now');
                          } else if (diff.inMinutes < 60) {
                            timeText = '${diff.inMinutes} ${languageService.translate("mins ago")}';
                          } else if (diff.inHours < 24) {
                            timeText = '${diff.inHours} ${languageService.translate("hours ago")}';
                          } else {
                            timeText = '${diff.inDays} ${languageService.translate("days ago")}';
                          }
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (syncService.status == SyncStatus.syncing)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 8),
                            Text(
                              '$statusText ${timeText.isNotEmpty ? "• $timeText" : ""}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
