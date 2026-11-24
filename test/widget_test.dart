import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/main.dart';

void main() {
  testWidgets('التطبيق يعمل ويعرض شاشة الحضور', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AttendanceApp());

    expect(find.text('نظام الحضور والانصراف'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('تسجيل الحضور'), findsOneWidget);
    expect(find.text('تسجيل الانصراف'), findsOneWidget);
  });
}