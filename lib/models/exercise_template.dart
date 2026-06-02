class ExerciseTemplate {
  final String id;
  final String nameRu;
  final String nameLv;
  final String nameEn;
  final String muscleGroup;
  final bool isCustom;

  ExerciseTemplate({
    required this.id,
    required this.nameRu,
    required this.nameLv,
    required this.nameEn,
    this.muscleGroup = '',
    this.isCustom = false,
  });

  // Получить название на текущем языке
  String getName(String languageCode){
    switch (languageCode) {
      case 'ru':
        return nameRu;
      case 'lv':
        return nameLv;
      default:
        return nameEn; // По умолчанию английское название
    }
  }

  Map<String, dynamic> toJson() => {
      'id': id,
      'nameRu': nameRu,
      'nameLv': nameLv,
      'nameEn': nameEn,
      'muscleGroup': muscleGroup,
      'isCustom': isCustom,
  };

  factory ExerciseTemplate.fromJson(Map<String, dynamic> json) {
    return ExerciseTemplate(
      id: json['id'],
      nameRu: json['nameRu'] ?? '',
      nameLv: json['nameLv'] ?? '',
      nameEn: json['nameEn'] ?? '',
      muscleGroup: json['muscleGroup'] ?? '',
      isCustom: json['isCustom'] ?? false,
    );
  }
}