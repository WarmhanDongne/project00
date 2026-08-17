# Project00 AI 작업 지침

이 저장소에서 게임, 플랫폼, Firebase 코드를 수정하는 AI는 작업 전에 반드시
[`docs/AI_GAME_DEVELOPMENT_GUIDE.md`](docs/AI_GAME_DEVELOPMENT_GUIDE.md)를 끝까지 읽는다.
새 게임을 추가할 때는 [`lib/games/_game_template/README.md`](lib/games/_game_template/README.md)와
가장 가까운 기존 게임 구현도 함께 확인한다.

## 변경 전 필수 원칙

1. 사용자가 만든 미커밋 변경을 보존한다. 관련 없는 파일을 되돌리거나 정리하지 않는다.
2. 게임 규칙, 턴 검증, 승패, 비공개 정보 이동은 Cloud Functions가 결정한다.
3. Flutter 클라이언트는 `rooms/{roomCode}/game`을 직접 수정하지 않는다.
4. 공개 데이터는 `game/public`, 개인 데이터는 `game/private/{uid}`, 클라이언트에
   노출하면 안 되는 데이터는 `game/server`에 둔다.
5. Realtime Database 구독은 Riverpod 세션 컨트롤러 한곳에서 받고, 위젯마다 별도
   구독을 만들지 않는다.
6. 서버 상태와 애니메이션 상태를 섞지 않는다. 서버 미러 상태는 불변 Provider 상태,
   재생 여부와 `AnimationController`는 화면 로컬 상태가 소유한다.
7. 새 게임은 `TemplateGame`을 구현하고 `GameRegistry`에만 등록한다. 플랫폼 화면에
   게임 ID별 `if/switch`를 추가하지 않는다. 단, 임시 개발 화면은 문서에 명시한다.
8. 생성된 `lib/gen/assets.gen.dart`를 직접 편집하지 않는다. 에셋을 등록한 후
   `dart run build_runner build --delete-conflicting-outputs`로 다시 생성한다.
9. 게임 명령 재시도를 지원하려면 동일한 `commandId`를 유지하고 서버를 멱등하게 만든다.
10. `status`, 서버 `phase`, 화면 `GameScreenPhase`, 태블릿 연출 상태를 같은 개념으로
    취급하지 않는다.

## 새 게임 구현 기준

- 휴대폰 공통 흐름: `GameScreenPhase` + `PhoneGameShell`
- 태블릿 상태 분기: 타입이 있는 enum + exhaustive `switch`
- 쓰기: `<game>_command_service.dart` → callable Cloud Function
- 읽기: `<game>_query_service.dart` → RTDB `onValue`
- 상태: `NotifierProvider.autoDispose.family` + 불변 state
- 공유 애니메이션/상단바/사이드바/결과/퇴장 UI는 `lib/games/shared/`부터 확인
- 백엔드 타입과 상태 전이는 `functions/src/<game>/`에 함께 구현

## 완료 전 최소 검증

```bash
dart format lib test
flutter analyze
flutter test
cd functions && npm test
```

범위가 큰 게임 변경은 실제 기기에서 `방 생성 → 휴대폰 입장 → 좌석 저장 → 시작 →
턴 진행 → 재접속 → 결과 → 재시작/종료/퇴장`까지 확인한다.

