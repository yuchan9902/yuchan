# 핏로그 (FitLog)

Flutter로 만든 **운동 기록 및 통계** 네이티브 앱. iOS · Android · Web에서 같은 코드로 동작합니다.

기록은 기기 안에만 저장되고 서버로 나가지 않습니다.

## 웹에서 미리 보기

두 가지 방법이 있습니다.

**1. 라이브 프리뷰 페이지 (설치 없이 바로)**

`web_preview/index.html` 을 브라우저에서 열면 앱의 화면 구성과 계산 로직을 그대로 옮긴
인터랙티브 프리뷰가 뜹니다. 세트를 추가하거나 무게를 고치면 볼륨·통계·차트가 그 자리에서
다시 계산됩니다. 외부 요청 없이 파일 하나로 동작합니다.

**2. 실제 Flutter 앱을 웹으로 실행**

```bash
cd app
flutter pub get
flutter run -d chrome        # 브라우저에서 실제 앱 실행
```

## 실행 · 검증

```bash
flutter pub get
flutter run                  # 연결된 iOS / Android 기기
flutter test                 # 단위 · 위젯 테스트 25개
flutter analyze              # 정적 분석
flutter build web --release  # 웹 배포 번들 (build/web)
flutter build apk            # Android
flutter build ios            # iOS
```

## 기능

| 화면 | 내용 |
|------|------|
| **홈** | 오늘 인사, 연속 기록 배지, 주간 목표 링, 요일별 달성 막대, 최근 14일 볼륨 차트, 최근 기록 |
| **기록** | 월간 캘린더 히트맵(볼륨에 비례한 농도), 날짜별 세션 목록, 밀어서 삭제 |
| **통계** | 기간별(주/월/3개월/1년) 요약, 볼륨 추이, 부위별 분포 도넛, 종목별 1RM 추이, 요일별 패턴, 개인 최고 기록 |
| **설정** | 주간 목표 횟수, 다크 모드, 예시 데이터 복구, 전체 삭제 |
| **기록 편집** | 종목·세트 추가/삭제, 무게·횟수 입력, 세트 완료 체크, 실시간 볼륨 합계, 컨디션·메모 |

- 기본 종목 28개(가슴·등·하체·어깨·팔·코어·유산소)를 내장하고, 종목을 직접 추가할 수도 있습니다.
- 종목은 **무게×횟수 / 맨몸 / 유산소(시간·거리)** 세 가지 기록 방식을 지원합니다.
- 이전에 같은 종목을 했다면 그때의 세트 구성을 기본값으로 불러옵니다.
- 첫 실행 시 10주치 예시 기록을 넣어 통계 화면이 비어 보이지 않게 합니다.

## 통계 계산 규칙

모든 지표는 화면과 분리된 순수 함수(`lib/utils/stats.dart`)에서 계산합니다.

| 지표 | 정의 |
|------|------|
| 총 볼륨 | `무게 × 횟수`의 합. 완료 체크하지 않은 세트는 제외 |
| 추정 1RM | Epley 공식 `w × (1 + r ÷ 30)`. 1회 세트는 무게 그대로 |
| 연속 기록 | 오늘부터 거꾸로 계산. 오늘 쉬었어도 어제까지 이어졌다면 유지 |
| 부위별 분포 | 부위별 볼륨 비율. 유산소는 `1분 = 100kg`으로 환산해 함께 표시 |
| 증감률 | 직전 동일 길이 구간과 비교. 비교 대상이 없으면 표시하지 않음 |
| 개인 기록 | 종목별 최고 추정 1RM. 유산소는 제외 |

## 구조

```
lib/
├── main.dart                    앱 진입점 · 테마 연결
├── models/models.dart           세션 · 종목 · 세트 + JSON 직렬화
├── data/
│   ├── exercise_catalog.dart    기본 종목 28개 + 사용자 종목 조회
│   ├── sample_data.dart         10주치 예시 기록 생성(시드 고정)
│   └── workout_repository.dart  shared_preferences 저장소
├── state/workout_store.dart     ChangeNotifier 단일 상태 소유자
├── utils/
│   ├── stats.dart               통계 엔진(순수 함수)
│   └── date_x.dart              한국어 날짜 · 숫자 포맷
├── theme/app_theme.dart         라이트/다크 팔레트 + Material 3 테마
├── widgets/                     CustomPainter 차트, 캘린더, 공용 컴포넌트
└── screens/                     홈 · 기록 · 통계 · 설정 · 편집 · 종목 선택
```

차트(막대·라인·도넛·링)는 외부 차트 패키지 없이 `CustomPainter`로 직접 그립니다.
런타임 의존성은 `provider`와 `shared_preferences` 둘뿐입니다.

## 테스트

```bash
flutter test
```

- `test/stats_test.dart` — 볼륨, 1RM, 연속 기록, 기간 집계, 부위 분포, 개인 기록, 직렬화 (21개)
- `test/widget_test.dart` — 첫 실행 시드, 탭 이동, 기간 변경, 전체 삭제 (4개)
