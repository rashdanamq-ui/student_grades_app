import '../settings/app_settings.dart';

String formatNumberForDisplay(double value) {
  final isArabic = AppSettings.useArabicNumbers.value;

  // هل الرقم صحيح؟
  final bool isInt = value == value.roundToDouble();

  String text;
  if (isInt) {
    // بدون فاصلة عشرية
    text = value.toStringAsFixed(0);
  } else {
    // بفاصلة عشرية واحدة
    text = value.toStringAsFixed(1);
  }

  if (isArabic) {
    return text.replaceAll('.', ',').toAppNum();
  } else {
    return text;
  }
}

String formatNumberForPdf(double value) {
  final isArabic = AppSettings.useArabicNumbers.value;

  // هل الرقم صحيح؟
  final bool isInt = value == value.roundToDouble();

  String text;
  if (isInt) {
    // بدون فاصلة عشرية
    text = value.toStringAsFixed(0);
  } else {
    // بفاصلة عشرية واحدة
    text = value.toStringAsFixed(1);
  }

  if (isArabic) {
    return text.replaceAll('.', ',').toAppNum();
  } else {
    return text;
  }
}

extension ToAppDigits on String {
  // جعلتها على String لسهولة التعامل
  /// تحويل للعرض (حسب الإعدادات)
  String toAppNum() {
    // نصل للقيمة عبر .value لأننا حولناه لـ ValueNotifier
    if (!AppSettings.useArabicNumbers.value) {
      return this;
    }

    return replaceAll('0', '٠')
        .replaceAll('1', '١')
        .replaceAll('2', '٢')
        .replaceAll('3', '٣')
        .replaceAll('4', '٤')
        .replaceAll('5', '٥')
        .replaceAll('6', '٦')
        .replaceAll('7', '٧')
        .replaceAll('8', '٨')
        .replaceAll('9', '٩')
        .replaceAll('.', '٫');
  }

  /// دالة جديدة ومهمة: تحويل للإنجليزي دائماً (للحسابات والحفظ)
  String toEnglishNum() {
    return replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('٫', '.'); // تحويل الفاصلة العربية لنقطة إنجليزية
  }
}
