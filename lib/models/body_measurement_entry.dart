// Одна запись замеров тела на определённую дату.
// Все поля кроме даты — необязательные (nullable), потому что пользователь
// сам решает какие замеры делать в этот раз, а какие пропустить.
class BodyMeasurementEntry {
  String date; // 'YYYY-MM-DD'

  double? neck;       // шея
  double? shoulders;  // плечи
  double? chest;       // грудь
  double? waist;        // талия
  double? hips;          // бёдра/таз
  double? bicep;         // бицепс
  double? forearm;      // предплечье
  double? thigh;          // бедро (нога)
  double? calf;            // икра

  BodyMeasurementEntry({
    required this.date,
    this.neck,
    this.shoulders,
    this.chest,
    this.waist,
    this.hips,
    this.bicep,
    this.forearm,
    this.thigh,
    this.calf,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'neck': neck,
    'shoulders': shoulders,
    'chest': chest,
    'waist': waist,
    'hips': hips,
    'bicep': bicep,
    'forearm': forearm,
    'thigh': thigh,
    'calf': calf,
  };

  factory BodyMeasurementEntry.fromJson(Map<String, dynamic> json) => BodyMeasurementEntry(
    date: json['date'],
    neck: (json['neck'] as num?)?.toDouble(),
    shoulders: (json['shoulders'] as num?)?.toDouble(),
    chest: (json['chest'] as num?)?.toDouble(),
    waist: (json['waist'] as num?)?.toDouble(),
    hips: (json['hips'] as num?)?.toDouble(),
    bicep: (json['bicep'] as num?)?.toDouble(),
    forearm: (json['forearm'] as num?)?.toDouble(),
    thigh: (json['thigh'] as num?)?.toDouble(),
    calf: (json['calf'] as num?)?.toDouble(),
  );

  // Вспомогательный метод — вернуть значение замера по его ключу (строке).
  // Пригодится когда будем строить график с чипсами: чипсы работают
  // с "ключом" замера, а не напрямую с полями объекта.
  double? getByKey(String key) {
    switch (key) {
      case 'neck': return neck;
      case 'shoulders': return shoulders;
      case 'chest': return chest;
      case 'waist': return waist;
      case 'hips': return hips;
      case 'bicep': return bicep;
      case 'forearm': return forearm;
      case 'thigh': return thigh;
      case 'calf': return calf;
      default: return null;
    }
  }
}