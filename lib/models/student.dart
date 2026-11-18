class Student {
  String name;
  bool isSelected;

  Student({required this.name, this.isSelected = false});

  Map<String, dynamic> toJson() => {'name': name, 'isSelected': isSelected};

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(name: json['name'], isSelected: json['isSelected'] ?? false);
  }
}
// أضف هذا في نهاية ملف lib/models/student.dart

// ✅ هذه الإضافة تجعل tempScore وتخزين اسم الفصل متاحاً في كل ملفات المشروع
extension StudentGlobalExt on Student {
  static final Map<Student, double> _scores = {};
  static final Map<Student, String> _classNames = {};

  double? get tempScore => _scores[this];
  set tempScore(double? value) {
    if (value == null) {
      _scores.remove(this);
    } else {
      _scores[this] = value;
    }
  }

  String get className => _classNames[this] ?? '';
  set className(String value) => _classNames[this] = value;
}
