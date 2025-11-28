import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../services/model_downloader.dart';
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
    if (lowerTitle.contains('science') || lowerTitle.contains('physics') || lowerTitle.contains('chemistry')) {
      return Icons.science_rounded;
    } else if (lowerTitle.contains('math')) {
      return Icons.calculate_rounded;
    } else if (lowerTitle.contains('history')) {
      return Icons.history_edu_rounded;
    } else if (lowerTitle.contains('geography')) {
      return Icons.public_rounded;
    } else if (lowerTitle.contains('english') || lowerTitle.contains('language')) {
      return Icons.menu_book_rounded;
    } else if (lowerTitle.contains('computer')) {
      return Icons.computer_rounded;
    }
    return Icons.book_rounded;
  }

  @override
  Widget build(BuildContext context) {
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
                            colors: [AppTheme.cyanAccent, AppTheme.cyanSecondary],
                          ).createShader(bounds),
                          child: const Text(
                            'Abhyas',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // User Greeting
                        Text(
                          'Hi, Priya',
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
                      'Your Subjects',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),

                // Subject Cards Grid
                if (provider.courses.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No courses available offline.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final course = provider.courses[index];
                          final gradientColors = _getGradientColors(index);
                          final icon = _getSubjectIcon(course.title);
                          
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CourseDetailsScreen(course: course),
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
                        },
                        childCount: provider.courses.length,
                      ),
                    ),
                  ),
                
                // Sync Status at Bottom
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.correctGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Synced just now',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
