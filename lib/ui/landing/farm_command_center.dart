import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../app_theme.dart';
import '../../core/services/detection_storage_service.dart';
import '../../core/services/farm_intelligence_service.dart';
import '../../core/models/detection_record.dart';
import '../camera/ar_camera_detection_page.dart';
import '../history/equipment_timeline_page.dart';
import '../analytics/farm_intelligence_dashboard.dart';
import '../../core/services/firebase_service.dart';
import '../detection/smart_scanner_page.dart';

class FarmEquipmentDetector extends StatefulWidget {
  const FarmEquipmentDetector({super.key});

  @override
  State<FarmEquipmentDetector> createState() => _FarmEquipmentDetectorState();
}

class _FarmEquipmentDetectorState extends State<FarmEquipmentDetector>
    with TickerProviderStateMixin {
  final _storageService = DetectionStorageService.instance;
  final _intelligenceService = FarmIntelligenceService.instance;
  late Animation<double> _fadeAnimation;
  
  String _greeting = '';
  Map<String, dynamic> _quickStats = {};
  List<dynamic> _recentInsights = [];
  
  late AnimationController _fadeController;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    
    _updateGreeting();
    _loadData();
    
    // Listen for data changes
    _storageService.dataChanges.listen((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void didUpdateWidget(FarmEquipmentDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshData();
  }

  Future<void> _refreshData() async {
    // Reload records from storage to get latest data
    await _storageService.loadRecords();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  void _loadData() {
    try {
      final records = _storageService.records;
      _intelligenceService.addRecords(records);
      
      setState(() {
        _quickStats = {
          'totalDetections': records.length,
          'todayDetections': records.where((r) => _isToday(r.timestamp)).length,
          'avgConfidence': records.isEmpty ? 0.0 : 
              records.map((r) => r.confidence).reduce((a, b) => a + b) / records.length,
          'equipmentTypes': records.map((r) => r.predictedClass).toSet().length,
        };
      });
      
      _intelligenceService.insights.listen((insight) {
        if (mounted) {
          setState(() {
            _recentInsights.insert(0, insight);
            if (_recentInsights.length > 50) {
              _recentInsights.removeRange(50, _recentInsights.length);
            }
          });
        }
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _quickStats = {
          'totalDetections': 0,
          'todayDetections': 0,
          'avgConfidence': 0.0,
          'equipmentTypes': 0,
        };
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primaryBlue,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Farm Equipment Detector',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryBlue.withOpacity(0.8),
                        AppColors.primaryBlue.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Icon(
                          Icons.agriculture,
                          color: Colors.white.withOpacity(0.2),
                          size: 60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildGreetingSection(),
                  const SizedBox(height: 20),
                  _buildEquipmentClassesSection(),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      _buildQuickStats(),
                      const SizedBox(height: 16),
                      _buildRecentActivity(),
                      const SizedBox(height: 16),
                      _buildWeatherWidget(),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.1),
            AppColors.primaryBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting,
            style: TextStyle(
              color: AppColors.primaryBlue.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMMM dd').format(DateTime.now()),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentClassesSection() {
    final equipmentClasses = [
      {
        'name': 'Farm Cultivator',
        'image': 'assets/images/Cultivator.png',
        'description': 'Used for soil preparation and weed control',
        'color': Colors.green,
      },
      {
        'name': 'Farm Harrow',
        'image': 'assets/images/Harrow.png',
        'description': 'Breaks up and smooths soil surface',
        'color': Colors.brown,
      },
      {
        'name': 'Farm Plough',
        'image': 'assets/images/Plough.png',
        'description': 'Primary tillage equipment for soil turning',
        'color': Colors.orange,
      },
      {
        'name': 'Farm Rake',
        'image': 'assets/images/Rake.png',
        'description': 'Collects and gathers hay or straw',
        'color': Colors.amber,
      },
      {
        'name': 'Farm Rotivator',
        'image': 'assets/images/Rotivator.png',
        'description': 'Rotates soil for better aeration',
        'color': Colors.red,
      },
      {
        'name': 'Farm Seeder',
        'image': 'assets/images/Seeder.png',
        'description': 'Plants seeds at precise depths and spacing',
        'color': Colors.blue,
      },
      {
        'name': 'Farm Truck',
        'image': 'assets/images/Truck.png',
        'description': 'Transports crops and equipment',
        'color': Colors.purple,
      },
      {
        'name': 'Farm Sprinkler',
        'image': 'assets/images/Sprinkler.png',
        'description': 'Provides automated irrigation for crops',
        'color': Colors.lightBlue,
      },
      {
        'name': 'Farm Harvester',
        'image': 'assets/images/Harvester.png',
        'description': 'Mechanized crop harvesting equipment',
        'color': Colors.deepOrange,
      },
      {
        'name': 'Farm Tractor',
        'image': 'assets/images/Tractor.jpg',
        'description': 'Multipurpose farm power unit',
        'color': Colors.indigo,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.1),
            AppColors.primaryBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Equipment Classes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: equipmentClasses.length,
            itemBuilder: (context, index) {
              final equipment = equipmentClasses[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: equipment['color'] as Color,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: (equipment['color'] as Color).withOpacity(0.1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            equipment['image'] as String,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              print('Image load error for ${equipment['image']}: $error');
                              return Container(
                                decoration: BoxDecoration(
                                  color: (equipment['color'] as Color).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.agriculture,
                                  color: equipment['color'] as Color,
                                  size: 32,
                                ),
                              );
                            },
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) {
                                return child;
                              }
                              return AnimatedOpacity(
                                child: child,
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(seconds: 1),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            equipment['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            equipment['description'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.1),
            AppColors.primaryBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Detections',
                  '${_quickStats['totalDetections'] ?? 0}',
                  Icons.camera_alt,
                  AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Today',
                  '${_quickStats['todayDetections'] ?? 0}',
                  Icons.today,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Confidence',
                  '${((_quickStats['avgConfidence'] ?? 0.0) * 100).round()}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Equipment Types',
                  '${_quickStats['equipmentTypes'] ?? 0}',
                  Icons.category,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final records = _storageService.records;
    final recentRecords = records
        .where((r) => _isToday(r.timestamp))
        .take(5)
        .toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (recentRecords.isEmpty)
            const Text(
              'No activity today yet',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Column(
              children: recentRecords.map((record) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.camera_alt,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.predictedClass,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(record.timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(record.confidence * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.cyan.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wb_sunny,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather Conditions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sunny, 24°C - Good conditions for equipment operation',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optimal for: All equipment types',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
