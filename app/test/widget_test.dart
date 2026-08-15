import 'package:fitlog/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // 저장된 값이 없는 첫 실행 상태로 시작한다.
    SharedPreferences.setMockInitialValues({});
  });

  /// 기본 테스트 화면(800×600)은 세로로 긴 목록의 아래쪽을 만들지 않는다.
  /// 스크롤 대신 화면을 충분히 키워 한 번에 그리게 한다.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 5000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FitLogApp());
    await tester.pumpAndSettle();
  }

  testWidgets('첫 실행이면 예시 데이터를 채우고 홈을 보여준다', (tester) async {
    await pumpApp(tester);

    expect(find.text('이번 주 목표'), findsOneWidget);
    expect(find.text('최근 14일 볼륨'), findsOneWidget);
    // 예시 데이터가 들어갔으므로 기록 목록이 비어 있지 않다.
    expect(find.text('아직 기록이 없어요'), findsNothing);
  });

  testWidgets('탭을 눌러 통계 화면으로 이동한다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.text('총 볼륨'), findsOneWidget);
    expect(find.text('부위별 분포'), findsOneWidget);
    expect(find.text('개인 최고 기록'), findsOneWidget);
  });

  testWidgets('기간을 바꾸면 통계 화면이 다시 그려진다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();

    expect(find.text('일별 총 볼륨'), findsOneWidget);
  });

  testWidgets('설정에서 모든 기록을 지우면 홈이 빈 상태가 된다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('모든 기록 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(find.text('아직 기록이 없어요'), findsOneWidget);
  });
}
