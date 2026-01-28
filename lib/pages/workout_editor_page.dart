import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';

class WorkoutEditorPage extends StatefulWidget {
  final String workoutId;
  
  const WorkoutEditorPage({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  final _service = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }
  
  Future<void> _loadWorkout() async {
    final workout = await _service.getWorkout(widget.workoutId);
    setState(() {
      _workout = workout;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      // Градиентный фон
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1F2937),
                    const Color(0xFF374151),
                  ]
                : [
                    const Color(0xFF1F2937),
                    const Color(0xFF374151),
                    const Color(0xFF4B5563),
                  ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF97316),
                  ),
                )
              : _workout == null
                  ? Center(
                      child: Text(
                        'workout.not_found'.tr(),
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        _buildHeader(),
                        
                        // Контент
                        Expanded(
                          child: Text(
                            'workout.in_development'.tr(),
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF97316).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          // Кнопка назад
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          // Название тренировки
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _workout?.name ?? 'workout.title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _workout?.date ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
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