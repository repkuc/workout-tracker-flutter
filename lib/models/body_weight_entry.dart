class BodyWeightEntry {
  final String date; // Дата в формате "2024-03-15"
  final double weight; // Вес в килограммах, например 84.5
  // Конструктор для создания новой записи веса
  BodyWeightEntry({
    required this.date, 
    required this.weight,
  });

  // Превращаем объект в Map чтобы сохранить в SharedPreferences
  // Например: {"date": "2024-03-15", "weight": 84.5}
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'weight': weight,
    };
  }
  // Создаем объект из Map, который мы получили из SharedPreferences
  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) {
    return BodyWeightEntry(
      date: json['date'] as String,
      weight: (json['weight'] as num).toDouble(), // Убедимся, что вес - это double
    );
  }
}