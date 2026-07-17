// Подключаем базовые виджеты Flutter (Scaffold, Container, Text и т.д.).
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов через .tr().
import 'package:easy_localization/easy_localization.dart';

// Подключаем нашу модель программы.
import '../models/program_models.dart';

// Подключаем сервис для загрузки/сохранения программ.
import '../services/program_service.dart';

// Подключаем экран создания программы, чтобы можно было на него перейти.
import 'create_program_page.dart';
// Подключаем экран деталей программы, чтобы можно было на него перейти.
import 'program_details_page.dart';

// StatefulWidget — потому что страница должна загружать данные асинхронно
// и обновлять экран когда данные придут (в отличие от StatelessWidget).
class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  // Экземпляр сервиса для работы с программами.
  final _service = ProgramService();

  // Список программ, который будет показан на экране.
  List<TrainingProgram> _programs = [];

  // Флаг — идёт ли сейчас загрузка данных (для показа спиннера).
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Как только страница создаётся — сразу начинаем загружать программы.
    _loadPrograms();
  }

  // didChangeDependencies вызывается когда страница снова становится видимой
  // (например когда возвращаемся назад после создания программы).
  // Это гарантирует что список всегда актуальный.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrograms();
  }

  // Загружаем список программ через сервис и обновляем состояние экрана.
  Future<void> _loadPrograms() async {
    final programs = await _service.loadAllPrograms();
    // setState говорит Flutter "данные изменились, перерисуй экран".
    setState(() {
      _programs = programs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок страницы — такой же стиль как на других страницах.
            _buildHeader(),

            // Основной контент занимает всё оставшееся место.
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFF97316)),
                    )
                  : _programs.isEmpty
                      ? _buildEmptyState()
                      : _buildProgramsList(),
            ),

            // Кнопка "Создать программу" внизу экрана.
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  // Заголовок с иконкой и названием раздела.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'programs.title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Пустое состояние — когда у пользователя ещё нет ни одной программы.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment,
                size: 56, color: Color(0xFFF97316)),
          ),
          const SizedBox(height: 16),
          Text(
            'programs.no_programs'.tr(),
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'programs.create_first'.tr(),
            style: const TextStyle(color: Color(0xFF374151), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // Список карточек программ.
  Widget _buildProgramsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _programs.length,
      itemBuilder: (context, index) => _buildProgramCard(_programs[index]),
    );
  }

  // Одна карточка программы в списке.
  Widget _buildProgramCard(TrainingProgram program) {
    return GestureDetector(
      // Пока просто заглушка — переход на детали программы добавим следующим шагом.
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProgramDetailsPage(programId: program.id),
          ),
        );
        // Перезагружаем список на случай изменений
        _loadPrograms();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF97316).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Строка с названием программы и, если она своя, бейджем "СВОЯ".
            Row(
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (program.isCustom)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF818CF8).withOpacity(0.15),
                      border: Border.all(color: const Color(0xFF818CF8)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'programs.custom_badge'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            // Показываем расписание только если оно заполнено.
            if (program.schedule.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF64748B), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    program.schedule,
                    style:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Чипсы с названиями дней/тренировок внутри программы.
            // Wrap автоматически переносит чипсы на новую строку если не помещаются.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: program.workouts.map((w) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.12),
                    border: Border.all(
                        color: const Color(0xFFF97316).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    w.name,
                    style: const TextStyle(
                      color: Color(0xFFF97316),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Кнопка создания новой программы внизу экрана.
  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          //
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateProgramPage()),
            );
            // После возврата с экрана создания — перезагружаем список,
            // чтобы новая программа сразу появилась.
            _loadPrograms();
          },
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            'programs.create_program'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
