// lib/models/mock_student.dart

class MockStudent {
  String id;
  String name;
  String className; // الفصل (رابع 5 / رابع 6)
  List<double?> exams;

  MockStudent({
    required this.id,
    required this.name,
    required this.className,
    required this.exams,
  });

  // --- دوال التحويل (JSON) ---
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'className': className, 'exams': exams};
  }

  factory MockStudent.fromJson(Map<String, dynamic> map) {
    return MockStudent(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      className: map['className']?.toString() ?? '',
      exams:
          (map['exams'] as List?)
              ?.map((e) => double.tryParse(e.toString()))
              .toList() ??
          [],
    );
  }
}

// ==========================================
// الإضافات (Extensions)
// ==========================================
extension MockStudentExtV2 on MockStudent {
  static final Map<MockStudent, double> _tempScores = {};

  double? get tempScore => _tempScores[this];

  set tempScore(double? value) {
    if (value == null) {
      _tempScores.remove(this);
    } else {
      _tempScores[this] = value;
    }
  }
}

// ==========================================
//  منطق الترتيب (الجديد)
// ==========================================

// 1. تعريف أنواع الترتيب
enum StudentSortMode {
  byScore, // حسب الدرجة (تنازلي)
  byClass, // حسب الفصل (تصاعدي)
  byName, // حسب الاسم (أبجدي)
}

// 2. دالة لترتيب القائمة بناءً على الوضع المختار
List<MockStudent> sortStudentsList(
  List<MockStudent> students,
  StudentSortMode mode,
) {
  // ننشئ نسخة جديدة حتى لا نعدل القائمة الأصلية
  List<MockStudent> sortedList = List.from(students);

  switch (mode) {
    case StudentSortMode.byScore:
      // من الأعلى للأقل (تنازلي)
      // نعتبر الـ null كأنه 0 ليظهر في الأسفل
      sortedList.sort((a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0));
      break;

    case StudentSortMode.byClass:
      // حسب الفصل (تصاعدي)
      // إذا تساوى الفصل، نرتبهم أبجدياً بالاسم
      sortedList.sort((a, b) {
        int cmp = a.className.compareTo(b.className);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
      break;

    case StudentSortMode.byName:
      // حسب الاسم (أبجدي)
      sortedList.sort((a, b) => a.name.compareTo(b.name));
      break;
  }

  return sortedList;
}
