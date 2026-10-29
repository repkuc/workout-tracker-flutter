import '../models/exercise_template.dart';
import '../models/program_models.dart';
import '../models/workout_models.dart';
import 'exercise_library_service.dart';
import 'program_service.dart';
import 'workout_service.dart';

// Сохранённые данные не удалось надёжно прочитать (битый JSON).
// Тот, кто собирался их менять (объединение упражнений), должен
// остановиться и ничего не трогать.
class DataReadException implements Exception {
  final String what;
  final Object cause;

  const DataReadException(this.what, this.cause);

  @override
  String toString() => 'DataReadException($what): $cause';
}

// Тренировки, программы и свои упражнения — для изменения, все три сразу.
// В отличие от loadAllWorkouts (битые данные → пустой список), здесь
// битые данные → DataReadException: иначе пустая история выглядела бы как
// «упражнение нигде не используется», и его удаление стёрло бы ссылки.
// Используют «Объединить» (CustomExerciseService.merge) и BuiltinExerciseMerge.
Future<
    ({
      List<Workout> workouts,
      List<TrainingProgram> programs,
      List<ExerciseTemplate> custom,
    })> loadDataForChange() async {
  Future<T> read<T>(String what, Future<T> Function() load) async {
    try {
      return await load();
    } catch (e) {
      throw DataReadException(what, e);
    }
  }

  return (
    workouts: await read('workouts', WorkoutService().loadAllWorkoutsStrict),
    programs: await read('programs', ProgramService().loadAllPrograms),
    custom: await read(
        'custom exercises', ExerciseLibraryService().getCustomExercises),
  );
}
