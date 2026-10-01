# 게임 패키지 전체 파일 참조

> 기준: 현재 working tree의 정적 import/export 관계를 자동 추출했다. 코드 리뷰 순서는
> [`GAME_CODE_REVIEW_GUIDE.md`](GAME_CODE_REVIEW_GUIDE.md)를 먼저 본다.

## 빠른 이동

- [앱과 게임 패키지 연결](#1-앱과-게임-패키지-연결-파일)
- [`game_kit`](#2-game_kit--공통-게임-기반)
- [`game_template`](#3-game_template--새-게임-복사용-기준)
- [`game_liars_poker`](#4-game_liars_poker--라이어스포커)
- [`game_final_call`](#5-game_final_call--파이널콜)
- [`game_mafia`](#6-game_mafia--마피아)
- [게임 관련 Cloud Functions](#7-게임-관련-cloud-functions)
- [테스트와 비코드 파일](#8-테스트와-비코드-파일을-보는-기준)

파일이 많으므로 브라우저나 편집기의 검색에서 정확한 파일명(예:
`game_controller.dart`)을 입력하는 방법이 가장 빠르다.

## 읽는 방법

- 대상: `packages/*/lib`의 production Dart 227개, 앱 연결 Dart 7개, 게임 관련 Functions TypeScript 61개.
- 생성 코드: 5개. 직접 수정하지 않고 생성 원본·설정·사용처만 확인한다.
- 제외: package별 `.dart_tool/build/entrypoint/build.dart` 4개는 로컬 build 도구가 만든 임시 산출물이라 production 리뷰 대상이 아니다.
- 이미지·음원은 코드처럼 한 파일씩 읽는 대상이 아니므로 package별 개수·확장자·주요 소유 폴더로 집계했다.
- `이 파일이 직접 참조`는 import/export/part의 정적 내부 의존이다.
- `이 파일을 직접 참조`는 `lib/`, `packages/`, `test/` 또는 `functions/test/`에서 이 파일을 import한 역참조다.
- 런타임 문자열 호출(Cloud Function 이름, RTDB 경로), reflection이 아닌 ID 연결, Firestore 데이터 연결은 import 그래프에 나타나지 않는다. 이 연결은 메인 가이드의 실행 흐름과 command 대응표에서 따로 확인한다.
- `_`로 시작하는 private 타입은 파일 내부 구현이므로 핵심 공개 선언 목록에서 제외했다.

## 1. 앱과 게임 패키지 연결 파일

#### 1. [`lib/games/game_registry.dart`](../../lib/games/game_registry.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: 앱에 포함된 게임 구현을 ID별로 등록하고 플랫폼에 GameCatalog로 제공한다.
- 핵심 공개 선언: `GameRegistry`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)
- 이 파일을 직접 참조:
- [lib/app.dart](../../lib/app.dart)<br>- [lib/main.dart](../../lib/main.dart)<br>- [test/game_compatibility_test.dart](../../test/game_compatibility_test.dart)<br>- [test/room_leave_state_test.dart](../../test/room_leave_state_test.dart)<br>- [test/tablet_game_selection_test.dart](../../test/tablet_game_selection_test.dart)

#### 2. [`lib/game_assets/game_asset_bootstrap.dart`](../../lib/game_assets/game_asset_bootstrap.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: 앱 시작 시 게임 에셋 캐시와 전역 GameAssetStore를 조립한다. 네트워크 다운로드는 자동 실행하지 않는다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [lib/game_assets/firebase_game_asset_source.dart](../../lib/game_assets/firebase_game_asset_source.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_cache.dart](../../packages/game_kit/lib/core/assets/game_asset_cache.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_source.dart](../../packages/game_kit/lib/core/assets/game_asset_source.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)
- 이 파일을 직접 참조:
- [lib/main.dart](../../lib/main.dart)<br>- [test/game_asset_bootstrap_test.dart](../../test/game_asset_bootstrap_test.dart)

#### 3. [`lib/game_assets/firebase_game_asset_source.dart`](../../lib/game_assets/firebase_game_asset_source.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: Firebase Storage의 manifest와 원격 에셋을 GameAssetSource 계약으로 연결한다.
- 핵심 공개 선언: `FirebaseGameAssetSource`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_manifest.dart](../../packages/game_kit/lib/core/assets/game_asset_manifest.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_source.dart](../../packages/game_kit/lib/core/assets/game_asset_source.dart)
- 이 파일을 직접 참조:
- [lib/game_assets/game_asset_bootstrap.dart](../../lib/game_assets/game_asset_bootstrap.dart)

#### 4. [`lib/platform/home/gamelist/models/game_info.dart`](../../lib/platform/home/gamelist/models/game_info.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: Firestore 게임 목록 문서를 플랫폼 표시 모델로 변환한다.
- 핵심 공개 선언: `GameAccessType`, `GameInfo`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/firebase/utils/firestore_value.dart](../../packages/game_kit/lib/firebase/utils/firestore_value.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/gamelist/provider/game_list_provider.dart](../../lib/platform/home/gamelist/provider/game_list_provider.dart)<br>- [lib/platform/home/gamelist/service/game_compatibility.dart](../../lib/platform/home/gamelist/service/game_compatibility.dart)<br>- [lib/platform/home/gamelist/service/game_list_service.dart](../../lib/platform/home/gamelist/service/game_list_service.dart)<br>- [lib/platform/home/phone/screens/phone_home.dart](../../lib/platform/home/phone/screens/phone_home.dart)<br>- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/phone/widgets/phone_game_card.dart](../../lib/platform/home/phone/widgets/phone_game_card.dart)<br>- [lib/platform/home/phone/widgets/phone_own_game_list.dart](../../lib/platform/home/phone/widgets/phone_own_game_list.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_list.dart](../../lib/platform/home/tablet/widgets/tablet_game_list.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [test/game_compatibility_test.dart](../../test/game_compatibility_test.dart)<br>- [test/phone_room_waiting_test.dart](../../test/phone_room_waiting_test.dart)<br>- [test/tablet_game_selection_test.dart](../../test/tablet_game_selection_test.dart)

#### 5. [`lib/platform/home/gamelist/provider/game_list_provider.dart`](../../lib/platform/home/gamelist/provider/game_list_provider.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: 플랫폼 게임 목록의 비동기 상태를 Riverpod으로 노출한다.
- 핵심 공개 선언: `GameProvider`
- 이 파일이 직접 참조:
- [lib/platform/home/gamelist/models/game_info.dart](../../lib/platform/home/gamelist/models/game_info.dart)<br>- [lib/platform/home/gamelist/service/game_list_service.dart](../../lib/platform/home/gamelist/service/game_list_service.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_list.dart](../../lib/platform/home/tablet/widgets/tablet_game_list.dart)<br>- [test/tablet_game_selection_test.dart](../../test/tablet_game_selection_test.dart)

#### 6. [`lib/platform/home/gamelist/service/game_compatibility.dart`](../../lib/platform/home/gamelist/service/game_compatibility.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: 앱 버전·에셋 버전을 기준으로 게임 실행 가능 여부를 판정한다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [lib/platform/home/gamelist/models/game_info.dart](../../lib/platform/home/gamelist/models/game_info.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/constants/app_constants.dart](../../packages/game_kit/lib/core/constants/app_constants.dart)<br>- [packages/game_kit/lib/core/utils/app_version.dart](../../packages/game_kit/lib/core/utils/app_version.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [test/game_compatibility_test.dart](../../test/game_compatibility_test.dart)

#### 7. [`lib/platform/home/gamelist/service/game_list_service.dart`](../../lib/platform/home/gamelist/service/game_list_service.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: Firestore 게임 목록과 로컬 GameCatalog를 결합해 플랫폼에 제공한다.
- 핵심 공개 선언: `GameService`
- 이 파일이 직접 참조:
- [lib/platform/home/gamelist/models/game_info.dart](../../lib/platform/home/gamelist/models/game_info.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/gamelist/provider/game_list_provider.dart](../../lib/platform/home/gamelist/provider/game_list_provider.dart)<br>- [lib/platform/home/phone/screens/phone_home.dart](../../lib/platform/home/phone/screens/phone_home.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [test/controller_reconnect_guard_test.dart](../../test/controller_reconnect_guard_test.dart)<br>- [test/controller_room_lifecycle_test.dart](../../test/controller_room_lifecycle_test.dart)<br>- [test/phone_room_waiting_test.dart](../../test/phone_room_waiting_test.dart)<br>- [test/room_leave_button_test.dart](../../test/room_leave_button_test.dart)<br>- [test/room_leave_error_copy_test.dart](../../test/room_leave_error_copy_test.dart)<br>- [test/room_leave_state_test.dart](../../test/room_leave_state_test.dart)<br>- [test/room_restore_to_waiting_test.dart](../../test/room_restore_to_waiting_test.dart)<br>- [test/seating_roster_guard_test.dart](../../test/seating_roster_guard_test.dart)<br>- [test/tablet_game_selection_test.dart](../../test/tablet_game_selection_test.dart)<br>- [test/tablet_room_reset_test.dart](../../test/tablet_room_reset_test.dart)<br>- [test/tablet_settings_dialog_test.dart](../../test/tablet_settings_dialog_test.dart)

## 2. `game_kit` — 공통 게임 기반

- 설정: [packages/game_kit/pubspec.yaml](../../packages/game_kit/pubspec.yaml)
- 총 35개 (`(확장자 없음)` 1개, `.m4a` 1개, `.mp3` 5개, `.webp` 28개)
- 파일이 많은 폴더: `packages/game_kit/assets/images/character` 17개, `packages/game_kit/assets/images/widgets/roulette` 6개, `packages/game_kit/assets/sounds` 6개, `packages/game_kit/assets/images/patch` 2개, `packages/game_kit/assets/images/reconnect` 2개, `packages/game_kit/assets/images/others` 1개, `packages/game_kit/assets/images/phone_result` 1개

#### 8. [`packages/game_kit/lib/tablet/animations/board_element_entrance.dart`](../../packages/game_kit/lib/tablet/animations/board_element_entrance.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [board_element_entrance.dart] 는 여러 게임이 함께 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `BoardElementEntrance`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/curve_intervals.dart](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart](../../packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart)

#### 9. [`packages/game_kit/lib/tablet/animations/card_deal_animation.dart`](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [card_deal_animation.dart] 는 여러 게임이 함께 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `DealCardBuilder`, `CardDealAnimation`, `CardDealAnimationState`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/curve_intervals.dart](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)<br>- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)<br>- [packages/game_kit/lib/widgets/game_card_face.dart](../../packages/game_kit/lib/widgets/game_card_face.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [test/card_deal_sound_test.dart](../../test/card_deal_sound_test.dart)

#### 10. [`packages/game_kit/lib/shared/animations/curve_intervals.dart`](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [curve_intervals.dart] 는 여러 게임이 함께 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/tablet/animations/board_element_entrance.dart](../../packages/game_kit/lib/tablet/animations/board_element_entrance.dart)<br>- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/phone/animations/card_receive_animation.dart](../../packages/game_kit/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_kit/lib/phone/animations/control_entry_animation.dart](../../packages/game_kit/lib/phone/animations/control_entry_animation.dart)<br>- [packages/game_kit/lib/phone/animations/game_start_animation.dart](../../packages/game_kit/lib/phone/animations/game_start_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)

#### 11. [`packages/game_kit/lib/shared/animations/fade_hold_fade.dart`](../../packages/game_kit/lib/shared/animations/fade_hold_fade.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [fade_hold_fade.dart] 는 여러 게임이 함께 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `FadeHoldFade`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)

#### 12. [`packages/game_kit/lib/phone/animations/game_entry_unroll.dart`](../../packages/game_kit/lib/phone/animations/game_entry_unroll.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_entry_unroll.dart] 는 여러 게임이 함께 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `GameEntryUnroll`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/mat_unroll_animation.dart](../../packages/game_kit/lib/shared/animations/mat_unroll_animation.dart)<br>- [packages/game_kit/lib/shared/animations/one_shot_timeline.dart](../../packages/game_kit/lib/shared/animations/one_shot_timeline.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)

#### 13. [`packages/game_kit/lib/shared/animations/mat_unroll_animation.dart`](../../packages/game_kit/lib/shared/animations/mat_unroll_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [mat_unroll_animation.dart] 는 여러 게임이 함께 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `MatUnrollAnimation`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/phone/animations/game_entry_unroll.dart](../../packages/game_kit/lib/phone/animations/game_entry_unroll.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 14. [`packages/game_kit/lib/shared/animations/one_shot_timeline.dart`](../../packages/game_kit/lib/shared/animations/one_shot_timeline.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [one_shot_timeline.dart] 는 여러 게임이 함께 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `OneShotTimelineBuilder`, `OneShotTimeline`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_kit/lib/phone/animations/game_entry_unroll.dart](../../packages/game_kit/lib/phone/animations/game_entry_unroll.dart)

#### 15. [`packages/game_kit/lib/phone/animations/card_receive_animation.dart`](../../packages/game_kit/lib/phone/animations/card_receive_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [card_receive_animation.dart] 는 여러 게임이 함께 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `PhoneCardReceiveAnimation`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/curve_intervals.dart](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)<br>- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_kit/lib/widgets/game_card_face.dart](../../packages/game_kit/lib/widgets/game_card_face.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/animations/card_receive_animation.dart](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)

#### 16. [`packages/game_kit/lib/phone/animations/control_entry_animation.dart`](../../packages/game_kit/lib/phone/animations/control_entry_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [control_entry_animation.dart] 는 여러 게임이 함께 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `PhoneControlEntryStyle`, `PhoneControlEntryAnimation`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/curve_intervals.dart](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/top_bar.dart](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)

#### 17. [`packages/game_kit/lib/phone/animations/game_start_animation.dart`](../../packages/game_kit/lib/phone/animations/game_start_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_start_animation.dart] 는 여러 게임이 함께 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `PhoneGameStartAnimation`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/curve_intervals.dart](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)

#### 18. [`packages/game_kit/lib/shared/animations/progress_sound_cue.dart`](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [progress_sound_cue.dart] 는 여러 게임이 함께 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `ProgressSoundCue`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)

#### 19. [`packages/game_kit/lib/core/assets/game_asset_cache.dart`](../../packages/game_kit/lib/core/assets/game_asset_cache.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_asset_cache.dart] 는 여러 게임이 함께 사용하는 게임 에셋 저장·검증·경로 해석을 담당하는 파일이다.
- 핵심 공개 선언: `GameAssetCache`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_manifest.dart](../../packages/game_kit/lib/core/assets/game_asset_manifest.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_source.dart](../../packages/game_kit/lib/core/assets/game_asset_source.dart)
- 이 파일을 직접 참조:
- [lib/game_assets/game_asset_bootstrap.dart](../../lib/game_assets/game_asset_bootstrap.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [test/game_asset_cache_test.dart](../../test/game_asset_cache_test.dart)<br>- [test/game_asset_store_test.dart](../../test/game_asset_store_test.dart)

#### 20. [`packages/game_kit/lib/core/assets/game_asset_manifest.dart`](../../packages/game_kit/lib/core/assets/game_asset_manifest.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_asset_manifest.dart] 는 여러 게임이 함께 사용하는 게임 에셋 저장·검증·경로 해석을 담당하는 파일이다.
- 핵심 공개 선언: `GameAssetManifest`, `GameAssetFile`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/game_assets/firebase_game_asset_source.dart](../../lib/game_assets/firebase_game_asset_source.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_cache.dart](../../packages/game_kit/lib/core/assets/game_asset_cache.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_source.dart](../../packages/game_kit/lib/core/assets/game_asset_source.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [test/game_asset_bootstrap_test.dart](../../test/game_asset_bootstrap_test.dart)<br>- [test/game_asset_cache_test.dart](../../test/game_asset_cache_test.dart)<br>- [test/game_asset_manifest_test.dart](../../test/game_asset_manifest_test.dart)<br>- [test/game_asset_store_test.dart](../../test/game_asset_store_test.dart)

#### 21. [`packages/game_kit/lib/core/assets/game_asset_source.dart`](../../packages/game_kit/lib/core/assets/game_asset_source.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_asset_source.dart] 는 여러 게임이 함께 사용하는 게임 에셋 저장·검증·경로 해석을 담당하는 파일이다.
- 핵심 공개 선언: `GameAssetSource`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_manifest.dart](../../packages/game_kit/lib/core/assets/game_asset_manifest.dart)
- 이 파일을 직접 참조:
- [lib/game_assets/firebase_game_asset_source.dart](../../lib/game_assets/firebase_game_asset_source.dart)<br>- [lib/game_assets/game_asset_bootstrap.dart](../../lib/game_assets/game_asset_bootstrap.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_cache.dart](../../packages/game_kit/lib/core/assets/game_asset_cache.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [test/game_asset_bootstrap_test.dart](../../test/game_asset_bootstrap_test.dart)<br>- [test/game_asset_cache_test.dart](../../test/game_asset_cache_test.dart)<br>- [test/game_asset_store_test.dart](../../test/game_asset_store_test.dart)

#### 22. [`packages/game_kit/lib/core/assets/game_asset_store.dart`](../../packages/game_kit/lib/core/assets/game_asset_store.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_asset_store.dart] 는 여러 게임이 함께 사용하는 게임 에셋 저장·검증·경로 해석을 담당하는 파일이다.
- 핵심 공개 선언: `GameAssetStore`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_cache.dart](../../packages/game_kit/lib/core/assets/game_asset_cache.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_manifest.dart](../../packages/game_kit/lib/core/assets/game_asset_manifest.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_source.dart](../../packages/game_kit/lib/core/assets/game_asset_source.dart)
- 이 파일을 직접 참조:
- [lib/game_assets/game_asset_bootstrap.dart](../../lib/game_assets/game_asset_bootstrap.dart)<br>- [lib/platform/home/gamelist/service/game_compatibility.dart](../../lib/platform/home/gamelist/service/game_compatibility.dart)<br>- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/core/assets/game_image.dart](../../packages/game_kit/lib/core/assets/game_image.dart)<br>- [packages/game_kit/lib/core/sound/service/sound_service.dart](../../packages/game_kit/lib/core/sound/service/sound_service.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/game_asset_bootstrap_test.dart](../../test/game_asset_bootstrap_test.dart)<br>- [test/game_asset_store_test.dart](../../test/game_asset_store_test.dart)

#### 23. [`packages/game_kit/lib/core/assets/game_image.dart`](../../packages/game_kit/lib/core/assets/game_image.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_image.dart] 는 여러 게임이 함께 사용하는 게임 에셋 저장·검증·경로 해석을 담당하는 파일이다.
- 핵심 공개 선언: `GameImage`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [test/game_asset_store_test.dart](../../test/game_asset_store_test.dart)

#### 24. [`packages/game_kit/lib/core/constants/app_constants.dart`](../../packages/game_kit/lib/core/constants/app_constants.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [app_constants.dart] 는 여러 게임이 함께 사용하는 앱 전체에서 반복 사용하는 고정값과 기준을 모아두는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/gamelist/service/game_compatibility.dart](../../lib/platform/home/gamelist/service/game_compatibility.dart)<br>- [test/game_compatibility_test.dart](../../test/game_compatibility_test.dart)

#### 25. [`packages/game_kit/lib/core/constants/room_character.dart`](../../packages/game_kit/lib/core/constants/room_character.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [room_character.dart] 는 여러 게임이 함께 사용하는 앱 전체에서 반복 사용하는 고정값과 기준을 모아두는 파일이다.
- 핵심 공개 선언: `RoomCharacter`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/howtoplay/widgets/how_to_play_pieces.dart](../../lib/platform/home/howtoplay/widgets/how_to_play_pieces.dart)<br>- [lib/platform/home/phone/screens/phone_room_nickname.dart](../../lib/platform/home/phone/screens/phone_room_nickname.dart)<br>- [lib/platform/home/phone/widgets/phone_room_participant_list.dart](../../lib/platform/home/phone/widgets/phone_room_participant_list.dart)<br>- [lib/platform/home/room/models/room_player.dart](../../lib/platform/home/room/models/room_player.dart)<br>- [lib/platform/home/tablet/widgets/tablet_room_panel.dart](../../lib/platform/home/tablet/widgets/tablet_room_panel.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart)<br>- [packages/game_final_call/lib/tablet/widgets/result_overlay.dart](../../packages/game_final_call/lib/tablet/widgets/result_overlay.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_editor.dart](../../packages/game_kit/lib/player_layouts/player_layout_editor.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/phone_result_dialog.dart](../../packages/game_kit/lib/widgets/phone_result_dialog.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/result.dart](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)<br>- [test/room_character_test.dart](../../test/room_character_test.dart)

#### 26. [`packages/game_kit/lib/core/diagnostics/crash_reporting.dart`](../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [crash_reporting.dart] 는 여러 게임이 함께 사용하는 게임 통신과 실행 오류를 기록하거나 화면에 보여주는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/diagnostics/dev_error_log.dart](../../packages/game_kit/lib/core/diagnostics/dev_error_log.dart)
- 이 파일을 직접 참조:
- [lib/main.dart](../../lib/main.dart)<br>- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)

#### 27. [`packages/game_kit/lib/core/diagnostics/dev_error_log.dart`](../../packages/game_kit/lib/core/diagnostics/dev_error_log.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [dev_error_log.dart] 는 여러 게임이 함께 사용하는 게임 통신과 실행 오류를 기록하거나 화면에 보여주는 파일이다.
- 핵심 공개 선언: `DevErrorLog`, `DevErrorEntry`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/room/providers/room_command_executor.dart](../../lib/platform/home/room/providers/room_command_executor.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [packages/game_kit/lib/core/diagnostics/crash_reporting.dart](../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart)<br>- [packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart](../../packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [test/diagnostics/dev_error_log_test.dart](../../test/diagnostics/dev_error_log_test.dart)

#### 28. [`packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart`](../../packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [dev_error_overlay.dart] 는 여러 게임이 함께 사용하는 게임 통신과 실행 오류를 기록하거나 화면에 보여주는 파일이다.
- 핵심 공개 선언: `DevErrorOverlay`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/diagnostics/dev_error_log.dart](../../packages/game_kit/lib/core/diagnostics/dev_error_log.dart)<br>- [packages/game_kit/lib/core/diagnostics/game_communication_log.dart](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)
- 이 파일을 직접 참조:
- [lib/app.dart](../../lib/app.dart)<br>- [lib/main.dart](../../lib/main.dart)<br>- [test/diagnostics/dev_error_log_test.dart](../../test/diagnostics/dev_error_log_test.dart)

#### 29. [`packages/game_kit/lib/core/diagnostics/game_communication_log.dart`](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [game_communication_log.dart] 는 여러 게임이 함께 사용하는 게임 통신과 실행 오류를 기록하거나 화면에 보여주는 파일이다.
- 핵심 공개 선언: `GameCommunicationLog`, `GameCommunicationLevel`, `GameCommunicationEntry`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart](../../packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart)<br>- [packages/game_kit/lib/core/network/realtime_connection_monitor.dart](../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)<br>- [packages/game_kit/lib/services/game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart)<br>- [test/diagnostics/dev_error_log_test.dart](../../test/diagnostics/dev_error_log_test.dart)<br>- [test/diagnostics/game_communication_log_test.dart](../../test/diagnostics/game_communication_log_test.dart)

#### 30. [`packages/game_kit/lib/core/error/app_exception.dart`](../../packages/game_kit/lib/core/error/app_exception.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [app_exception.dart] 는 여러 게임이 함께 사용하는 앱과 게임에서 발생하는 오류를 공통 형태로 정리하는 파일이다.
- 핵심 공개 선언: `AppException`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/core/error/user_error_message.dart](../../packages/game_kit/lib/core/error/user_error_message.dart)

#### 31. [`packages/game_kit/lib/core/error/room_command_exception.dart`](../../packages/game_kit/lib/core/error/room_command_exception.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [room_command_exception.dart] 는 여러 게임이 함께 사용하는 앱과 게임에서 발생하는 오류를 공통 형태로 정리하는 파일이다.
- 핵심 공개 선언: `RoomCommandException`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/room/services/room_common.dart](../../lib/platform/home/room/services/room_common.dart)<br>- [packages/game_kit/lib/core/error/user_error_message.dart](../../packages/game_kit/lib/core/error/user_error_message.dart)

#### 32. [`packages/game_kit/lib/core/error/user_error_message.dart`](../../packages/game_kit/lib/core/error/user_error_message.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [user_error_message.dart] 는 여러 게임이 함께 사용하는 앱과 게임에서 발생하는 오류를 공통 형태로 정리하는 파일이다.
- 핵심 공개 선언: `UserErrorContext`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/error/app_exception.dart](../../packages/game_kit/lib/core/error/app_exception.dart)<br>- [packages/game_kit/lib/core/error/room_command_exception.dart](../../packages/game_kit/lib/core/error/room_command_exception.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/room/providers/room_command_executor.dart](../../lib/platform/home/room/providers/room_command_executor.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [lib/platform/home/room/services/room_service.dart](../../lib/platform/home/room/services/room_service.dart)<br>- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [test/user_error_message_test.dart](../../test/user_error_message_test.dart)

#### 33. [`packages/game_kit/lib/core/layout/app_orientation.dart`](../../packages/game_kit/lib/core/layout/app_orientation.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [app_orientation.dart] 는 여러 게임이 함께 사용하는 기기 종류·화면 방향·시스템 UI 기준을 관리하는 파일이다.
- 핵심 공개 선언: `PhoneGameOrientation`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/layout/device_layout.dart](../../packages/game_kit/lib/core/layout/device_layout.dart)
- 이 파일을 직접 참조:
- [lib/main.dart](../../lib/main.dart)<br>- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)<br>- [test/platform_orientation_restore_test.dart](../../test/platform_orientation_restore_test.dart)

#### 34. [`packages/game_kit/lib/core/layout/app_system_ui.dart`](../../packages/game_kit/lib/core/layout/app_system_ui.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [app_system_ui.dart] 는 여러 게임이 함께 사용하는 기기 종류·화면 방향·시스템 UI 기준을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/phone/screens/phone_home.dart](../../lib/platform/home/phone/screens/phone_home.dart)<br>- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_editor.dart](../../packages/game_kit/lib/player_layouts/player_layout_editor.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)

#### 35. [`packages/game_kit/lib/core/layout/device_layout.dart`](../../packages/game_kit/lib/core/layout/device_layout.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [device_layout.dart] 는 여러 게임이 함께 사용하는 기기 종류·화면 방향·시스템 UI 기준을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/app.dart](../../lib/app.dart)<br>- [lib/main.dart](../../lib/main.dart)<br>- [lib/platform/home/home.dart](../../lib/platform/home/home.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/network/network_unavailable_modal.dart](../../packages/game_kit/lib/core/network/network_unavailable_modal.dart)<br>- [test/platform_orientation_restore_test.dart](../../test/platform_orientation_restore_test.dart)

#### 36. [`packages/game_kit/lib/core/network/app_network_guard.dart`](../../packages/game_kit/lib/core/network/app_network_guard.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [app_network_guard.dart] 는 여러 게임이 함께 사용하는 네트워크 연결 상태와 재연결 흐름을 관리하는 파일이다.
- 핵심 공개 선언: `AppNetworkGuard`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/network/network_unavailable_modal.dart](../../packages/game_kit/lib/core/network/network_unavailable_modal.dart)
- 이 파일을 직접 참조:
- [lib/app.dart](../../lib/app.dart)<br>- [packages/game_kit/lib/widgets/critical_network_guard.dart](../../packages/game_kit/lib/widgets/critical_network_guard.dart)<br>- [test/app_network_guard_test.dart](../../test/app_network_guard_test.dart)

#### 37. [`packages/game_kit/lib/core/network/network_unavailable_modal.dart`](../../packages/game_kit/lib/core/network/network_unavailable_modal.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [network_unavailable_modal.dart] 는 여러 게임이 함께 사용하는 네트워크 연결 상태와 재연결 흐름을 관리하는 파일이다.
- 핵심 공개 선언: `NetworkUnavailableModal`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/layout/device_layout.dart](../../packages/game_kit/lib/core/layout/device_layout.dart)<br>- [packages/game_kit/lib/gen/assets.gen.dart](../../packages/game_kit/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/core/network/app_network_guard.dart](../../packages/game_kit/lib/core/network/app_network_guard.dart)<br>- [test/app_network_guard_test.dart](../../test/app_network_guard_test.dart)

#### 38. [`packages/game_kit/lib/core/network/realtime_connection_monitor.dart`](../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [realtime_connection_monitor.dart] 는 여러 게임이 함께 사용하는 네트워크 연결 상태와 재연결 흐름을 관리하는 파일이다.
- 핵심 공개 선언: `RealtimeConnectionMonitor`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/diagnostics/game_communication_log.dart](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/room/services/room_service.dart](../../lib/platform/home/room/services/room_service.dart)<br>- [test/app_network_guard_test.dart](../../test/app_network_guard_test.dart)

#### 39. [`packages/game_kit/lib/core/sound/app_sounds.dart`](../../packages/game_kit/lib/core/sound/app_sounds.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [app_sounds.dart] 는 여러 게임이 함께 사용하는 앱 공통 효과음과 재생 상태를 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/game_sounds.dart](../../packages/game_final_call/lib/game_sounds.dart)<br>- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_liars_poker/lib/game_sounds.dart](../../packages/game_liars_poker/lib/game_sounds.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)<br>- [test/countdown_tick_cue_test.dart](../../test/countdown_tick_cue_test.dart)<br>- [test/penalty_lever_sound_test.dart](../../test/penalty_lever_sound_test.dart)

#### 40. [`packages/game_kit/lib/core/sound/providers/sound_provider.dart`](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [sound_provider.dart] 는 여러 게임이 함께 사용하는 앱 공통 효과음과 재생 상태를 관리하는 파일이다.
- 핵심 공개 선언: `SoundProvider`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_kit/lib/core/sound/service/sound_service.dart](../../packages/game_kit/lib/core/sound/service/sound_service.dart)
- 이 파일을 직접 참조:
- [lib/main.dart](../../lib/main.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_kit/lib/sound/game_background_music.dart](../../packages/game_kit/lib/sound/game_background_music.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [test/countdown_tick_cue_test.dart](../../test/countdown_tick_cue_test.dart)<br>- [test/liars_poker_submit_sound_test.dart](../../test/liars_poker_submit_sound_test.dart)<br>- [test/mafia_background_music_test.dart](../../test/mafia_background_music_test.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)<br>- [test/penalty_lever_sound_test.dart](../../test/penalty_lever_sound_test.dart)<br>- [test/tablet_settings_dialog_test.dart](../../test/tablet_settings_dialog_test.dart)

#### 41. [`packages/game_kit/lib/core/sound/service/sound_service.dart`](../../packages/game_kit/lib/core/sound/service/sound_service.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [sound_service.dart] 는 여러 게임이 함께 사용하는 앱 공통 효과음과 재생 상태를 관리하는 파일이다.
- 핵심 공개 선언: `SoundService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)<br>- [test/sound_start_offset_test.dart](../../test/sound_start_offset_test.dart)

#### 42. [`packages/game_kit/lib/core/sound/sound_effects.dart`](../../packages/game_kit/lib/core/sound/sound_effects.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [sound_effects.dart] 는 여러 게임이 함께 사용하는 앱 공통 효과음과 재생 상태를 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_kit/lib/sound/game_background_music.dart](../../packages/game_kit/lib/sound/game_background_music.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)

#### 43. [`packages/game_kit/lib/core/time/server_clock.dart`](../../packages/game_kit/lib/core/time/server_clock.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [server_clock.dart] 는 여러 게임이 함께 사용하는 서버 시간과 기기 시간의 차이를 보정하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/main.dart](../../lib/main.dart)<br>- [lib/platform/auth/screens/register_screen.dart](../../lib/platform/auth/screens/register_screen.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/game_turn_countdown.dart](../../packages/game_kit/lib/widgets/game_turn_countdown.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/controller_room_lifecycle_test.dart](../../test/controller_room_lifecycle_test.dart)<br>- [test/countdown_tick_cue_test.dart](../../test/countdown_tick_cue_test.dart)<br>- [test/final_call_turn_timer_test.dart](../../test/final_call_turn_timer_test.dart)<br>- [test/game_interruption_finish_now_test.dart](../../test/game_interruption_finish_now_test.dart)<br>- [test/game_turn_countdown_test.dart](../../test/game_turn_countdown_test.dart)<br>- [test/liars_poker_turn_timer_test.dart](../../test/liars_poker_turn_timer_test.dart)

#### 44. [`packages/game_kit/lib/core/update/shorebird_patch_gate.dart`](../../packages/game_kit/lib/core/update/shorebird_patch_gate.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [shorebird_patch_gate.dart] 는 여러 게임이 함께 사용하는 Shorebird 패치 확인과 진입 차단 흐름을 관리하는 파일이다.
- 핵심 공개 선언: `ShorebirdPatchGate`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/update/shorebird_patch_screen.dart](../../packages/game_kit/lib/core/update/shorebird_patch_screen.dart)
- 이 파일을 직접 참조:
- [lib/app.dart](../../lib/app.dart)<br>- [test/shorebird_patch_gate_test.dart](../../test/shorebird_patch_gate_test.dart)

#### 45. [`packages/game_kit/lib/core/update/shorebird_patch_screen.dart`](../../packages/game_kit/lib/core/update/shorebird_patch_screen.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [shorebird_patch_screen.dart] 는 여러 게임이 함께 사용하는 Shorebird 패치 확인과 진입 차단 흐름을 관리하는 파일이다.
- 핵심 공개 선언: `ShorebirdPatchScreen`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/widgets/game_reconnect_screen.dart](../../packages/game_kit/lib/widgets/game_reconnect_screen.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/core/update/shorebird_patch_gate.dart](../../packages/game_kit/lib/core/update/shorebird_patch_gate.dart)<br>- [test/shorebird_patch_screen_test.dart](../../test/shorebird_patch_screen_test.dart)

#### 46. [`packages/game_kit/lib/core/utils/app_version.dart`](../../packages/game_kit/lib/core/utils/app_version.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [app_version.dart] 는 여러 게임이 함께 사용하는 앱 공통 보조 계산과 값 변환을 제공하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/gamelist/service/game_compatibility.dart](../../lib/platform/home/gamelist/service/game_compatibility.dart)<br>- [test/game_compatibility_test.dart](../../test/game_compatibility_test.dart)

#### 47. [`packages/game_kit/lib/firebase/firebase_options.dart`](../../packages/game_kit/lib/firebase/firebase_options.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: FlutterFire CLI가 생성한 Firebase 플랫폼 옵션이다. 직접 수정하지 않는다.
- 핵심 공개 선언: 생성 코드 — 선언 목록보다 생성 원본과 사용 경로만 확인
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/main.dart](../../lib/main.dart)

#### 48. [`packages/game_kit/lib/firebase/services/realtime_database_service.dart`](../../packages/game_kit/lib/firebase/services/realtime_database_service.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [realtime_database_service.dart] 는 여러 게임이 함께 사용하는 Firebase Realtime Database 접근을 공통으로 처리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/room/services/room_service.dart](../../lib/platform/home/room/services/room_service.dart)<br>- [packages/game_kit/lib/services/game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart)

#### 49. [`packages/game_kit/lib/firebase/utils/firestore_value.dart`](../../packages/game_kit/lib/firebase/utils/firestore_value.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [firestore_value.dart] 는 여러 게임이 함께 사용하는 Firestore에서 받은 값을 안전한 Dart 값으로 변환하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/gamelist/models/game_info.dart](../../lib/platform/home/gamelist/models/game_info.dart)<br>- [lib/platform/home/room/models/room_data.dart](../../lib/platform/home/room/models/room_data.dart)<br>- [lib/platform/home/room/models/room_device.dart](../../lib/platform/home/room/models/room_device.dart)

#### 50. [`packages/game_kit/lib/game_assets.dart`](../../packages/game_kit/lib/game_assets.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: game_assets 기능을 담당하는 게임 코드다.
- 핵심 공개 선언: `GameKitImageX`, `GameKitImageListX`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_image.dart](../../packages/game_kit/lib/core/assets/game_image.dart)<br>- [packages/game_kit/lib/gen/assets.gen.dart](../../packages/game_kit/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/phone/animations/card_receive_animation.dart](../../packages/game_kit/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/widgets/game_card_face.dart](../../packages/game_kit/lib/widgets/game_card_face.dart)<br>- [packages/game_kit/lib/widgets/phone_result_dialog.dart](../../packages/game_kit/lib/widgets/phone_result_dialog.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart)

#### 51. [`packages/game_kit/lib/game_feedback.dart`](../../packages/game_kit/lib/game_feedback.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: game_feedback 기능을 담당하는 게임 코드다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)

#### 52. [`packages/game_kit/lib/game_flow/game_announcement.dart`](../../packages/game_kit/lib/game_flow/game_announcement.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_announcement.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: `GameAnnouncementKind`, `GameAnnouncementTone`, `GameAnnouncement`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_flow_config.dart](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)

#### 53. [`packages/game_kit/lib/game_flow/game_finish.dart`](../../packages/game_kit/lib/game_flow/game_finish.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_finish.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)

#### 54. [`packages/game_kit/lib/game_flow/game_flow_auto_complete.dart`](../../packages/game_kit/lib/game_flow/game_flow_auto_complete.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_flow_auto_complete.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: `GameFlowAutoComplete`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 55. [`packages/game_kit/lib/game_flow/game_flow_config.dart`](../../packages/game_kit/lib/game_flow/game_flow_config.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_flow_config.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: `GameFlowAdvancePolicy`, `GameFlowAnimationConfig`, `GameFlowStep`, `GameFlowConfig`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_flow_config.dart](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)

#### 56. [`packages/game_kit/lib/game_flow/game_flow_copy.dart`](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_flow_copy.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/leave_failure_notice.dart](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_flow_config.dart](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_kit/lib/widgets/game_connecting_overlay.dart](../../packages/game_kit/lib/widgets/game_connecting_overlay.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)<br>- [test/game_connecting_overlay_test.dart](../../test/game_connecting_overlay_test.dart)

#### 57. [`packages/game_kit/lib/game_flow/game_interruption.dart`](../../packages/game_kit/lib/game_flow/game_interruption.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_interruption.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: `GameInterruptionReason`, `GameInterruption`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/shared/models/game_state.dart](../../packages/game_final_call/lib/shared/models/game_state.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [test/game_interruption_finish_now_test.dart](../../test/game_interruption_finish_now_test.dart)

#### 58. [`packages/game_kit/lib/game_flow/game_screen_phase.dart`](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [game_screen_phase.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: `GameScreenPhase`, `GameScreenPhaseX`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_flow_config.dart](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_template/lib/phone/phone_board.dart](../../packages/game_template/lib/phone/phone_board.dart)

#### 59. [`packages/game_kit/lib/game_flow/leave_failure_notice.dart`](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [leave_failure_notice.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)

#### 60. [`packages/game_kit/lib/game_flow/phone_game_flow_config.dart`](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [phone_game_flow_config.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/game_flow/game_screen_phase.dart](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_template/lib/phone/phone_board.dart](../../packages/game_template/lib/phone/phone_board.dart)

#### 61. [`packages/game_kit/lib/game_flow/phone_game_shell.dart`](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [phone_game_shell.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
- 핵심 공개 선언: `PhoneGameShell`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/phone/animations/game_entry_unroll.dart](../../packages/game_kit/lib/phone/animations/game_entry_unroll.dart)<br>- [packages/game_kit/lib/phone/animations/control_entry_animation.dart](../../packages/game_kit/lib/phone/animations/control_entry_animation.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/game_flow/game_screen_phase.dart](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_flow_config.dart](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_kit/lib/widgets/game_connecting_overlay.dart](../../packages/game_kit/lib/widgets/game_connecting_overlay.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_template/lib/phone/phone_board.dart](../../packages/game_template/lib/phone/phone_board.dart)

#### 62. [`packages/game_kit/lib/gen/assets.gen.dart`](../../packages/game_kit/lib/gen/assets.gen.dart)

- 리뷰 단계: **11. 생성 코드 확인**
- 역할: FlutterGen이 패키지 assets를 타입 안전한 Dart 경로로 생성한 파일이다. 직접 수정하지 않는다.
- 핵심 공개 선언: 생성 코드 — 선언 목록보다 생성 원본과 사용 경로만 확인
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/core/network/network_unavailable_modal.dart](../../packages/game_kit/lib/core/network/network_unavailable_modal.dart)<br>- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_kit/lib/widgets/phone_result_dialog.dart](../../packages/game_kit/lib/widgets/phone_result_dialog.dart)

#### 63. [`packages/game_kit/lib/models/game_room_context.dart`](../../packages/game_kit/lib/models/game_room_context.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: [game_room_context.dart] 는 여러 게임이 함께 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `GameRoomContext`, `GameRoomPlayer`, `GameRoomMetadata`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/gamelist/models/game_info.dart](../../lib/platform/home/gamelist/models/game_info.dart)<br>- [lib/platform/home/room/models/room_player.dart](../../lib/platform/home/room/models/room_player.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_overlay.dart](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/tablet/widgets/rolebook.dart](../../packages/game_final_call/lib/tablet/widgets/rolebook.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_kit/lib/game_flow/leave_failure_notice.dart](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_factory.dart](../../packages/game_kit/lib/player_layouts/player_layout_factory.dart)<br>- [packages/game_kit/lib/player_layouts/seating_roster_guard.dart](../../packages/game_kit/lib/player_layouts/seating_roster_guard.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_kit/lib/widgets/critical_network_guard.dart](../../packages/game_kit/lib/widgets/critical_network_guard.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/rolebook.dart](../../packages/game_liars_poker/lib/tablet/widgets/rolebook.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)

#### 64. [`packages/game_kit/lib/models/game_room_model.dart`](../../packages/game_kit/lib/models/game_room_model.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [game_room_model.dart] 는 여러 게임이 함께 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `GameRoomModel`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 65. [`packages/game_kit/lib/penalty/roulette.dart`](../../packages/game_kit/lib/penalty/roulette.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [roulette.dart] 는 여러 게임이 함께 사용하는 패널티 룰렛의 상태와 회전 결과를 표현하는 파일이다.
- 핵심 공개 선언: `RouletteResult`, `PenaltyRoulette`, `RouletteWheel`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/core/diagnostics/game_communication_log.dart](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)<br>- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_kit/lib/gen/assets.gen.dart](../../packages/game_kit/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart](../../packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_penalty.dart](../../packages/game_liars_poker/lib/tablet/screens/game_penalty.dart)<br>- [test/penalty_lever_sound_test.dart](../../test/penalty_lever_sound_test.dart)

#### 66. [`packages/game_kit/lib/player_layouts/player_layout_editor.dart`](../../packages/game_kit/lib/player_layouts/player_layout_editor.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [player_layout_editor.dart] 는 여러 게임이 함께 사용하는 태블릿의 플레이어 자리 배치와 편집 규칙을 관리하는 파일이다.
- 핵심 공개 선언: `PlayerLayoutPrepared`, `PlayerLayoutCompleted`, `PlayerLayoutCancelled`, `PlayerLayoutEditor`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)<br>- [packages/game_kit/lib/widgets/game_setup_back_button.dart](../../packages/game_kit/lib/widgets/game_setup_back_button.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [test/player_layout_cancel_test.dart](../../test/player_layout_cancel_test.dart)<br>- [test/player_layout_seating_design_test.dart](../../test/player_layout_seating_design_test.dart)<br>- [test/tablet_game_selection_test.dart](../../test/tablet_game_selection_test.dart)

#### 67. [`packages/game_kit/lib/player_layouts/player_layout_factory.dart`](../../packages/game_kit/lib/player_layouts/player_layout_factory.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [player_layout_factory.dart] 는 여러 게임이 함께 사용하는 태블릿의 플레이어 자리 배치와 편집 규칙을 관리하는 파일이다.
- 핵심 공개 선언: `PlayerLayoutFactory`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)

#### 68. [`packages/game_kit/lib/player_layouts/player_layout_model.dart`](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [player_layout_model.dart] 는 여러 게임이 함께 사용하는 태블릿의 플레이어 자리 배치와 편집 규칙을 관리하는 파일이다.
- 핵심 공개 선언: `PlayerLayoutModel`, `PlayerLayoutPlayer`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_editor.dart](../../packages/game_kit/lib/player_layouts/player_layout_editor.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_factory.dart](../../packages/game_kit/lib/player_layouts/player_layout_factory.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/result.dart](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)<br>- [test/player_layout_cancel_test.dart](../../test/player_layout_cancel_test.dart)<br>- [test/player_layout_seating_design_test.dart](../../test/player_layout_seating_design_test.dart)

#### 69. [`packages/game_kit/lib/player_layouts/player_slot_positions.dart`](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [player_slot_positions.dart] 는 여러 게임이 함께 사용하는 태블릿의 플레이어 자리 배치와 편집 규칙을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/howtoplay/widgets/how_to_play_scenes.dart](../../lib/platform/home/howtoplay/widgets/how_to_play_scenes.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_editor.dart](../../packages/game_kit/lib/player_layouts/player_layout_editor.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart](../../packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart)<br>- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)

#### 70. [`packages/game_kit/lib/player_layouts/seating_roster_guard.dart`](../../packages/game_kit/lib/player_layouts/seating_roster_guard.dart)

- 리뷰 단계: **2. 공통 진행 흐름**
- 역할: [seating_roster_guard.dart] 는 여러 게임이 함께 사용하는 태블릿의 플레이어 자리 배치와 편집 규칙을 관리하는 파일이다.
- 핵심 공개 선언: `SeatingRosterGuard`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [test/seating_roster_guard_test.dart](../../test/seating_roster_guard_test.dart)

#### 71. [`packages/game_kit/lib/services/callable_retry_policy.dart`](../../packages/game_kit/lib/services/callable_retry_policy.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [callable_retry_policy.dart] 는 여러 게임이 함께 사용하는 게임의 조회·명령 서비스를 묶어 제공하는 파일이다.
- 핵심 공개 선언: `CallableRetryPolicy`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/room/services/room_service.dart](../../lib/platform/home/room/services/room_service.dart)<br>- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)<br>- [test/callable_retry_policy_test.dart](../../test/callable_retry_policy_test.dart)

#### 72. [`packages/game_kit/lib/services/game_command_service.dart`](../../packages/game_kit/lib/services/game_command_service.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [game_command_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
- 핵심 공개 선언: `GameCommandService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/diagnostics/game_communication_log.dart](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)<br>- [packages/game_kit/lib/services/callable_retry_policy.dart](../../packages/game_kit/lib/services/callable_retry_policy.dart)<br>- [packages/game_kit/lib/session/controller_room_session_store.dart](../../packages/game_kit/lib/session/controller_room_session_store.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/command_service.dart](../../packages/game_final_call/lib/shared/services/command_service.dart)<br>- [packages/game_kit/lib/services/game_interruption_command_service.dart](../../packages/game_kit/lib/services/game_interruption_command_service.dart)<br>- [packages/game_liars_poker/lib/shared/services/command_service.dart](../../packages/game_liars_poker/lib/shared/services/command_service.dart)<br>- [packages/game_mafia/lib/shared/services/command_service.dart](../../packages/game_mafia/lib/shared/services/command_service.dart)<br>- [packages/game_template/lib/shared/services/command_service.dart](../../packages/game_template/lib/shared/services/command_service.dart)

#### 73. [`packages/game_kit/lib/services/game_interruption_command_service.dart`](../../packages/game_kit/lib/services/game_interruption_command_service.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [game_interruption_command_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
- 핵심 공개 선언: `GameInterruptionCommandService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)<br>- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)<br>- [test/final_call_interruption_finish_now_test.dart](../../test/final_call_interruption_finish_now_test.dart)<br>- [test/final_call_warmup_test.dart](../../test/final_call_warmup_test.dart)<br>- [test/liars_poker_interruption_finish_now_test.dart](../../test/liars_poker_interruption_finish_now_test.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)<br>- [test/mafia_interruption_finish_now_test.dart](../../test/mafia_interruption_finish_now_test.dart)<br>- [test/mafia_room_gone_test.dart](../../test/mafia_room_gone_test.dart)

#### 74. [`packages/game_kit/lib/services/game_query_service.dart`](../../packages/game_kit/lib/services/game_query_service.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [game_query_service.dart] 는 여러 게임이 함께 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.
- 핵심 공개 선언: `GameQueryService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/diagnostics/game_communication_log.dart](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)<br>- [packages/game_kit/lib/firebase/services/realtime_database_service.dart](../../packages/game_kit/lib/firebase/services/realtime_database_service.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/query_service.dart](../../packages/game_final_call/lib/shared/services/query_service.dart)<br>- [packages/game_liars_poker/lib/shared/services/query_service.dart](../../packages/game_liars_poker/lib/shared/services/query_service.dart)<br>- [packages/game_mafia/lib/shared/services/query_service.dart](../../packages/game_mafia/lib/shared/services/query_service.dart)<br>- [packages/game_template/lib/shared/services/query_service.dart](../../packages/game_template/lib/shared/services/query_service.dart)

#### 75. [`packages/game_kit/lib/session/controller_room_session_store.dart`](../../packages/game_kit/lib/session/controller_room_session_store.dart)

- 리뷰 단계: **3. 공통 기반**
- 역할: [controller_room_session_store.dart] 는 여러 게임이 함께 사용하는 방 세션 컨트롤러의 생성과 수명 주기를 관리하는 파일이다.
- 핵심 공개 선언: `ControllerRoomSessionStore`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [lib/platform/home/room/services/room_service.dart](../../lib/platform/home/room/services/room_service.dart)<br>- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)

#### 76. [`packages/game_kit/lib/sound/countdown_tick_cue.dart`](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [countdown_tick_cue.dart] 는 여러 게임이 함께 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
- 핵심 공개 선언: `CountdownTickCue`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/widgets/turn_timer.dart](../../packages/game_final_call/lib/phone/widgets/turn_timer.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_timer.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_timer.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/countdown_tick_cue_test.dart](../../test/countdown_tick_cue_test.dart)

#### 77. [`packages/game_kit/lib/sound/game_background_music.dart`](../../packages/game_kit/lib/sound/game_background_music.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_background_music.dart] 는 여러 게임이 함께 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
- 핵심 공개 선언: `GameBackgroundMusic`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_background_music_test.dart](../../test/mafia_background_music_test.dart)

#### 78. [`packages/game_kit/lib/template_game.dart`](../../packages/game_kit/lib/template_game.dart)

- 리뷰 단계: **1. 연결 계약**
- 역할: [template_game.dart] 는 모든 게임이 따라야 하는 공통 규칙을 정의하는 파일이다.
- 핵심 공개 선언: `GameCatalog`, `EmptyGameCatalog`, `GameGateway`, `TemplateGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)
- 이 파일을 직접 참조:
- [lib/game_assets/game_asset_bootstrap.dart](../../lib/game_assets/game_asset_bootstrap.dart)<br>- [lib/games/game_registry.dart](../../lib/games/game_registry.dart)<br>- [lib/platform/auth/widgets/auth_gate.dart](../../lib/platform/auth/widgets/auth_gate.dart)<br>- [lib/platform/home/gamelist/service/game_compatibility.dart](../../lib/platform/home/gamelist/service/game_compatibility.dart)<br>- [lib/platform/home/home.dart](../../lib/platform/home/home.dart)<br>- [lib/platform/home/phone/screens/phone_home.dart](../../lib/platform/home/phone/screens/phone_home.dart)<br>- [lib/platform/home/phone/screens/phone_room_join.dart](../../lib/platform/home/phone/screens/phone_room_join.dart)<br>- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [lib/platform/home/room/providers/room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart)<br>- [lib/platform/home/tablet/screens/tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)<br>- [test/game_asset_bootstrap_test.dart](../../test/game_asset_bootstrap_test.dart)

#### 79. [`packages/game_kit/lib/widgets/cards/card.dart`](../../packages/game_kit/lib/widgets/cards/card.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [card.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameCard`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 80. [`packages/game_kit/lib/widgets/critical_network_guard.dart`](../../packages/game_kit/lib/widgets/critical_network_guard.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [critical_network_guard.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `CriticalNetworkGuard`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/network/app_network_guard.dart](../../packages/game_kit/lib/core/network/app_network_guard.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)
- 이 파일을 직접 참조:
- [lib/platform/home/phone/screens/phone_room_waiting.dart](../../lib/platform/home/phone/screens/phone_room_waiting.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)

#### 81. [`packages/game_kit/lib/widgets/game_announcement_layer.dart`](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_announcement_layer.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameAnnouncementStyle`, `GameAnnouncementLayer`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/fade_hold_fade.dart](../../packages/game_kit/lib/shared/animations/fade_hold_fade.dart)<br>- [packages/game_kit/lib/phone/animations/game_start_animation.dart](../../packages/game_kit/lib/phone/animations/game_start_animation.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)

#### 82. [`packages/game_kit/lib/widgets/game_card_face.dart`](../../packages/game_kit/lib/widgets/game_card_face.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_card_face.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameCardFace`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/phone/animations/card_receive_animation.dart](../../packages/game_kit/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)

#### 83. [`packages/game_kit/lib/widgets/game_connecting_overlay.dart`](../../packages/game_kit/lib/widgets/game_connecting_overlay.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_connecting_overlay.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameConnectingOverlay`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [test/game_connecting_overlay_test.dart](../../test/game_connecting_overlay_test.dart)

#### 84. [`packages/game_kit/lib/widgets/game_interruption_layer.dart`](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_interruption_layer.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameInterruptionPresentation`, `GameInterruptionLayer`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/game_interruption_finish_now_test.dart](../../test/game_interruption_finish_now_test.dart)

#### 85. [`packages/game_kit/lib/widgets/game_reconnect_screen.dart`](../../packages/game_kit/lib/widgets/game_reconnect_screen.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_reconnect_screen.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameReconnectScreen`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/home.dart](../../lib/platform/home/home.dart)<br>- [lib/platform/home/phone/widgets/controller_reconnect_guard.dart](../../lib/platform/home/phone/widgets/controller_reconnect_guard.dart)<br>- [lib/platform/home/phone/widgets/session_return_prompt.dart](../../lib/platform/home/phone/widgets/session_return_prompt.dart)<br>- [packages/game_kit/lib/core/update/shorebird_patch_screen.dart](../../packages/game_kit/lib/core/update/shorebird_patch_screen.dart)<br>- [test/game_reconnect_screen_test.dart](../../test/game_reconnect_screen_test.dart)<br>- [test/session_return_prompt_test.dart](../../test/session_return_prompt_test.dart)<br>- [test/shorebird_patch_screen_test.dart](../../test/shorebird_patch_screen_test.dart)

#### 86. [`packages/game_kit/lib/widgets/game_route_exit.dart`](../../packages/game_kit/lib/widgets/game_route_exit.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_route_exit.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [lib/platform/home/phone/widgets/controller_reconnect_guard.dart](../../lib/platform/home/phone/widgets/controller_reconnect_guard.dart)<br>- [lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart](../../lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/game_route_exit_test.dart](../../test/game_route_exit_test.dart)

#### 87. [`packages/game_kit/lib/widgets/game_setup_back_button.dart`](../../packages/game_kit/lib/widgets/game_setup_back_button.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_setup_back_button.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameSetupBackButton`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/player_layouts/player_layout_editor.dart](../../packages/game_kit/lib/player_layouts/player_layout_editor.dart)<br>- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)

#### 88. [`packages/game_kit/lib/widgets/game_turn_countdown.dart`](../../packages/game_kit/lib/widgets/game_turn_countdown.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_turn_countdown.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `GameTurnCountdown`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/widgets/turn_timer.dart](../../packages/game_final_call/lib/phone/widgets/turn_timer.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_timer.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_timer.dart)<br>- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/game_turn_countdown_test.dart](../../test/game_turn_countdown_test.dart)

#### 89. [`packages/game_kit/lib/widgets/phone_exit_modal.dart`](../../packages/game_kit/lib/widgets/phone_exit_modal.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [phone_exit_modal.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `SharedPhoneExitModal`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/widgets/phone_ripple_dialog.dart](../../packages/game_kit/lib/widgets/phone_ripple_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/exit_modal.dart](../../packages/game_liars_poker/lib/phone/widgets/exit_modal.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [test/phone_exit_modal_test.dart](../../test/phone_exit_modal_test.dart)

#### 90. [`packages/game_kit/lib/widgets/phone_game_top_bar.dart`](../../packages/game_kit/lib/widgets/phone_game_top_bar.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [phone_game_top_bar.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `SharedPhoneGameTopBar`, `PhoneGameTopBarMenu`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/top_bar.dart](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)

#### 91. [`packages/game_kit/lib/widgets/phone_result_dialog.dart`](../../packages/game_kit/lib/widgets/phone_result_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [phone_result_dialog.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `PhoneResultDialog`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_kit/lib/gen/assets.gen.dart](../../packages/game_kit/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [test/phone_result_dialog_test.dart](../../test/phone_result_dialog_test.dart)

#### 92. [`packages/game_kit/lib/widgets/phone_ripple_dialog.dart`](../../packages/game_kit/lib/widgets/phone_ripple_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [phone_ripple_dialog.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_kit/lib/widgets/phone_exit_modal.dart](../../packages/game_kit/lib/widgets/phone_exit_modal.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)

#### 93. [`packages/game_kit/lib/widgets/phone_rule_dialog.dart`](../../packages/game_kit/lib/widgets/phone_rule_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [phone_rule_dialog.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `PhoneGameRuleDialog`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)

#### 94. [`packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart`](../../packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [tablet_game_menu_overlay.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `TabletGameMenuOverlay`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/widgets/tablet_game_side_bar.dart](../../packages/game_kit/lib/widgets/tablet_game_side_bar.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_overlay.dart](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)

#### 95. [`packages/game_kit/lib/widgets/tablet_game_modal_frame.dart`](../../packages/game_kit/lib/widgets/tablet_game_modal_frame.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [tablet_game_modal_frame.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `TabletGameModalFrame`, `TabletGameDialogButton`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)

#### 96. [`packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart`](../../packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [tablet_game_rulebook_dialog.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `TabletGameRulebookDialog`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_assets.dart](../../packages/game_kit/lib/game_assets.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_modal_frame.dart](../../packages/game_kit/lib/widgets/tablet_game_modal_frame.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/widgets/rolebook.dart](../../packages/game_final_call/lib/tablet/widgets/rolebook.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/rolebook.dart](../../packages/game_liars_poker/lib/tablet/widgets/rolebook.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)

#### 97. [`packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart`](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [tablet_game_settings_dialog.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `TabletGameSettingsDialog`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/core/sound/providers/sound_provider.dart](../../packages/game_kit/lib/core/sound/providers/sound_provider.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_modal_frame.dart](../../packages/game_kit/lib/widgets/tablet_game_modal_frame.dart)
- 이 파일을 직접 참조:
- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/tablet_settings_dialog_test.dart](../../test/tablet_settings_dialog_test.dart)

#### 98. [`packages/game_kit/lib/widgets/tablet_game_side_bar.dart`](../../packages/game_kit/lib/widgets/tablet_game_side_bar.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [tablet_game_side_bar.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `TabletGameSideBar`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart](../../packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart)

## 3. `game_template` — 새 게임 복사용 기준

- 설정: [packages/game_template/pubspec.yaml](../../packages/game_template/pubspec.yaml)
- 총 1개 (`(확장자 없음)` 1개)
- 파일이 많은 폴더: `packages/game_template/assets` 1개

#### 99. [`packages/game_template/lib/game_template.dart`](../../packages/game_template/lib/game_template.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 게임 패키지를 플랫폼에 연결하는 진입 계약을 구현하는 파일이다.
- 핵심 공개 선언: `TemplateExampleGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_template/lib/phone/phone_board.dart](../../packages/game_template/lib/phone/phone_board.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)<br>- [packages/game_template/lib/shared/services/game_service.dart](../../packages/game_template/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 100. [`packages/game_template/lib/game_template.dart`](../../packages/game_template/lib/game_template.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_template.dart] 는 새 게임 패키지의 대표 진입 위치를 표시하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 101. [`packages/game_template/lib/phone/phone_board.dart`](../../packages/game_template/lib/phone/phone_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [phone_game.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 휴대폰 게임 화면의 진입점과 공통 흐름을 연결하는 파일이다.
- 핵심 공개 선언: `TemplatePhoneGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_screen_phase.dart](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_flow_config.dart](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)
- 이 파일을 직접 참조:
- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)

#### 102. [`packages/game_template/lib/tablet/providers/game_stage.dart`](../../packages/game_template/lib/tablet/providers/game_stage.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_stage.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `TemplateTabletStage`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)

#### 103. [`packages/game_template/lib/tablet/tablet_board.dart`](../../packages/game_template/lib/tablet/tablet_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [tablet_game.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 태블릿 게임 화면의 진입점과 공통 흐름을 연결하는 파일이다.
- 핵심 공개 선언: `TemplateTabletGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_template/lib/tablet/providers/game_stage.dart](../../packages/game_template/lib/tablet/providers/game_stage.dart)<br>- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)
- 이 파일을 직접 참조:
- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)

#### 104. [`packages/game_template/lib/shared/services/command_service.dart`](../../packages/game_template/lib/shared/services/command_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [command_service.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
- 핵심 공개 선언: `TemplateCommandService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_template/lib/shared/services/game_service.dart](../../packages/game_template/lib/shared/services/game_service.dart)

#### 105. [`packages/game_template/lib/shared/services/query_service.dart`](../../packages/game_template/lib/shared/services/query_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [query_service.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.
- 핵심 공개 선언: `TemplateQueryService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_template/lib/shared/services/game_service.dart](../../packages/game_template/lib/shared/services/game_service.dart)

#### 106. [`packages/game_template/lib/shared/services/game_service.dart`](../../packages/game_template/lib/shared/services/game_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [game_service.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 게임의 조회·명령 서비스를 묶어 제공하는 파일이다.
- 핵심 공개 선언: `TemplateService`
- 이 파일이 직접 참조:
- [packages/game_template/lib/shared/services/command_service.dart](../../packages/game_template/lib/shared/services/command_service.dart)<br>- [packages/game_template/lib/shared/services/query_service.dart](../../packages/game_template/lib/shared/services/query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_template/lib/game_template.dart](../../packages/game_template/lib/game_template.dart)

#### 107. [`packages/game_template/lib/tablet/tablet_board.dart`](../../packages/game_template/lib/tablet/tablet_board.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_flow_config.dart] 는 새 게임을 같은 구조로 시작할 때 사용하는 게임의 공통 진행 화면에 필요한 설정을 연결하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_template/lib/tablet/providers/game_stage.dart](../../packages/game_template/lib/tablet/providers/game_stage.dart)
- 이 파일을 직접 참조:
- [packages/game_template/lib/tablet/tablet_board.dart](../../packages/game_template/lib/tablet/tablet_board.dart)

## 4. `game_liars_poker` — 라이어스포커

- 설정: [packages/game_liars_poker/pubspec.yaml](../../packages/game_liars_poker/pubspec.yaml)
- 총 44개 (`(확장자 없음)` 3개, `.m4a` 1개, `.md` 1개, `.mp3` 2개, `.png` 5개, `.svg` 3개, `.webp` 29개)
- 파일이 많은 폴더: `packages/game_liars_poker/assets/games/liars_poker/images/button` 8개, `packages/game_liars_poker/assets/games/liars_poker/images/cards` 7개, `packages/game_liars_poker/assets/games/liars_poker/images/icons` 7개, `packages/game_liars_poker/assets/games/liars_poker/images/table` 6개, `packages/game_liars_poker/assets/games/liars_poker/images/background` 5개, `packages/game_liars_poker/assets/games/liars_poker/sounds` 4개, `packages/game_liars_poker/assets/games/liars_poker/images/layout` 2개, `packages/game_liars_poker/assets` 1개

#### 108. [`packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart`](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [tablet_card_play_animation.dart] 는 라이어스포커에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `CardPlayAnimation`, `CardPlayAnimationState`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/curve_intervals.dart](../../packages/game_kit/lib/shared/animations/curve_intervals.dart)<br>- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)<br>- [packages/game_kit/lib/widgets/game_card_face.dart](../../packages/game_kit/lib/widgets/game_card_face.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_sounds.dart](../../packages/game_liars_poker/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/animations/game_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/game_animation.dart)<br>- [test/liars_poker_submit_sound_test.dart](../../test/liars_poker_submit_sound_test.dart)

#### 109. [`packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart`](../../packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [tablet_round_start_reveal.dart] 는 라이어스포커에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `RoundStartReveal`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/tablet/animations/board_element_entrance.dart](../../packages/game_kit/lib/tablet/animations/board_element_entrance.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)

#### 110. [`packages/game_liars_poker/lib/shared/providers/game_controller.dart`](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [game_controller.dart] 는 라이어스포커에서 사용하는 게임 규칙과 사용자 입력에 따른 진행 명령을 조율하는 파일이다.
- 핵심 공개 선언: `LiarsPokerErrorHandler`, `LiarsPokerController`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/error/user_error_message.dart](../../packages/game_kit/lib/core/error/user_error_message.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/game_flow/game_finish.dart](../../packages/game_kit/lib/game_flow/game_finish.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)<br>- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart](../../packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_models.dart](../../packages/game_liars_poker/lib/shared/models/game_models.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/session_provider.dart](../../packages/game_liars_poker/lib/shared/providers/session_provider.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart)<br>- [test/liars_poker_interruption_finish_now_test.dart](../../test/liars_poker_interruption_finish_now_test.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)

#### 111. [`packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart`](../../packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [penalty_coordinator.dart] 는 라이어스포커에서 사용하는 패널티 룰렛 진행과 서버 상태 연결을 조율하는 파일이다.
- 핵심 공개 선언: `LiarsPokerPenaltyCoordinator`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_liars_poker/lib/shared/services/command_service.dart](../../packages/game_liars_poker/lib/shared/services/command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)

#### 112. [`packages/game_liars_poker/lib/game_assets.dart`](../../packages/game_liars_poker/lib/game_assets.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_assets.dart] 는 라이어스포커 이미지 에셋을 실행 코드에 연결하는 파일이다.
- 핵심 공개 선언: `LiarsPokerImageX`, `LiarsPokerImageListX`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_image.dart](../../packages/game_kit/lib/core/assets/game_image.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart](../../packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_helper.dart](../../packages/game_liars_poker/lib/tablet/screens/game_helper.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/exit_modal.dart](../../packages/game_liars_poker/lib/phone/widgets/exit_modal.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/top_bar.dart](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)<br>- [packages/game_liars_poker/lib/shared/widgets/pressable_button.dart](../../packages/game_liars_poker/lib/shared/widgets/pressable_button.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/result.dart](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/rolebook.dart](../../packages/game_liars_poker/lib/tablet/widgets/rolebook.dart)<br>- [test/liars_poker_hand_stack_rebuild_test.dart](../../test/liars_poker_hand_stack_rebuild_test.dart)<br>- [test/liars_poker_submit_sound_test.dart](../../test/liars_poker_submit_sound_test.dart)

#### 113. [`packages/game_liars_poker/lib/game_liars_poker.dart`](../../packages/game_liars_poker/lib/game_liars_poker.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_liars_poker.dart] 는 라이어스포커 패키지의 대표 진입 위치를 표시하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 114. [`packages/game_liars_poker/lib/gen/assets.gen.dart`](../../packages/game_liars_poker/lib/gen/assets.gen.dart)

- 리뷰 단계: **11. 생성 코드 확인**
- 역할: FlutterGen이 패키지 assets를 타입 안전한 Dart 경로로 생성한 파일이다. 직접 수정하지 않는다.
- 핵심 공개 선언: 생성 코드 — 선언 목록보다 생성 원본과 사용 경로만 확인
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart](../../packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_helper.dart](../../packages/game_liars_poker/lib/tablet/screens/game_helper.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/exit_modal.dart](../../packages/game_liars_poker/lib/phone/widgets/exit_modal.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/top_bar.dart](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/result.dart](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/rolebook.dart](../../packages/game_liars_poker/lib/tablet/widgets/rolebook.dart)<br>- [test/liars_poker_hand_stack_rebuild_test.dart](../../test/liars_poker_hand_stack_rebuild_test.dart)<br>- [test/liars_poker_submit_sound_test.dart](../../test/liars_poker_submit_sound_test.dart)

#### 115. [`packages/game_liars_poker/lib/game_copy.dart`](../../packages/game_liars_poker/lib/game_copy.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_copy.dart] 는 라이어스포커에서 사용하는 게임 화면에서 사용하는 문구를 한곳에 모아둔 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_penalty.dart](../../packages/game_liars_poker/lib/tablet/screens/game_penalty.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)

#### 116. [`packages/game_liars_poker/lib/tablet/tablet_board.dart`](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_flow_config.dart] 는 라이어스포커에서 사용하는 게임의 공통 진행 화면에 필요한 설정을 연결하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_liars_poker/lib/tablet/providers/game_stage.dart](../../packages/game_liars_poker/lib/tablet/providers/game_stage.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)

#### 117. [`packages/game_liars_poker/lib/game_liars_poker.dart`](../../packages/game_liars_poker/lib/game_liars_poker.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game.dart] 는 라이어스포커에서 사용하는 게임 패키지를 플랫폼에 연결하는 진입 계약을 구현하는 파일이다.
- 핵심 공개 선언: `LiarsPokerGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_kit/lib/widgets/critical_network_guard.dart](../../packages/game_kit/lib/widgets/critical_network_guard.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [lib/games/game_registry.dart](../../lib/games/game_registry.dart)<br>- [test/game_asset_bootstrap_test.dart](../../test/game_asset_bootstrap_test.dart)

#### 118. [`packages/game_liars_poker/lib/shared/services/asset_preloader.dart`](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_loading.dart] 는 라이어스포커에서 사용하는 게임 진입 중 필요한 준비 상태와 로딩 화면을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/core/diagnostics/crash_reporting.dart](../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_sounds.dart](../../packages/game_liars_poker/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 119. [`packages/game_liars_poker/lib/shared/models/game_models.dart`](../../packages/game_liars_poker/lib/shared/models/game_models.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_models.dart] 는 라이어스포커에서 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `PhoneHandCard`, `PhoneGamePlayer`, `PhonePenaltyResult`, `PublicLastPlay`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)

#### 120. [`packages/game_liars_poker/lib/shared/models/game_state.dart`](../../packages/game_liars_poker/lib/shared/models/game_state.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [game_state.dart] 는 라이어스포커에서 사용하는 서버에서 받은 게임 상태와 화면 구독 상태를 관리하는 파일이다.
- 핵심 공개 선언: `LiarsPokerGameState`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_models.dart](../../packages/game_liars_poker/lib/shared/models/game_models.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/providers/session_provider.dart](../../packages/game_liars_poker/lib/shared/providers/session_provider.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 121. [`packages/game_liars_poker/lib/shared/providers/session_provider.dart`](../../packages/game_liars_poker/lib/shared/providers/session_provider.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [session_provider.dart] 는 라이어스포커에서 사용하는 서버에서 받은 게임 상태와 화면 구독 상태를 관리하는 파일이다.
- 핵심 공개 선언: `LiarsPokerSessionArgs`
- 이 파일이 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [test/liars_poker_interruption_finish_now_test.dart](../../test/liars_poker_interruption_finish_now_test.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)

#### 122. [`packages/game_liars_poker/lib/phone/screens/game_screen.dart`](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_screen.dart] 는 라이어스포커에서 사용하는 휴대폰에서 보이는 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerPhoneGameScreen`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/phone/animations/control_entry_animation.dart](../../packages/game_kit/lib/phone/animations/control_entry_animation.dart)<br>- [packages/game_kit/lib/game_feedback.dart](../../packages/game_kit/lib/game_feedback.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/leave_failure_notice.dart](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_kit/lib/widgets/phone_ripple_dialog.dart](../../packages/game_kit/lib/widgets/phone_ripple_dialog.dart)<br>- [packages/game_kit/lib/widgets/phone_rule_dialog.dart](../../packages/game_kit/lib/widgets/phone_rule_dialog.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/exit_modal.dart](../../packages/game_liars_poker/lib/phone/widgets/exit_modal.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/liar_accusation.dart](../../packages/game_liars_poker/lib/phone/widgets/liar_accusation.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/settings_dialog.dart](../../packages/game_liars_poker/lib/phone/widgets/settings_dialog.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/top_bar.dart](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_timer.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_timer.dart)<br>- [packages/game_liars_poker/lib/shared/widgets/pressable_button.dart](../../packages/game_liars_poker/lib/shared/widgets/pressable_button.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)

#### 123. [`packages/game_liars_poker/lib/phone/phone_board.dart`](../../packages/game_liars_poker/lib/phone/phone_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [phone_game.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면의 진입점과 공통 흐름을 연결하는 파일이다.
- 핵심 공개 선언: `LiarsPokerPhoneGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/phone/animations/game_entry_unroll.dart](../../packages/game_kit/lib/phone/animations/game_entry_unroll.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/game_feedback.dart](../../packages/game_kit/lib/game_feedback.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/widgets/game_connecting_overlay.dart](../../packages/game_kit/lib/widgets/game_connecting_overlay.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/game_route_exit.dart](../../packages/game_kit/lib/widgets/game_route_exit.dart)<br>- [packages/game_kit/lib/widgets/phone_result_dialog.dart](../../packages/game_kit/lib/widgets/phone_result_dialog.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)<br>- [packages/game_liars_poker/lib/shared/providers/session_provider.dart](../../packages/game_liars_poker/lib/shared/providers/session_provider.dart)<br>- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)

#### 124. [`packages/game_liars_poker/lib/tablet/animations/game_animation.dart`](../../packages/game_liars_poker/lib/tablet/animations/game_animation.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_animation.dart] 는 라이어스포커에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerTabletGameAnimation`
- 이 파일이 직접 참조:
- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_helper.dart](../../packages/game_liars_poker/lib/tablet/screens/game_helper.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 125. [`packages/game_liars_poker/lib/tablet/screens/game_helper.dart`](../../packages/game_liars_poker/lib/tablet/screens/game_helper.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_helper.dart] 는 라이어스포커에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `SubmittedPlay`
- 이 파일이 직접 참조:
- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/animations/game_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/game_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 126. [`packages/game_liars_poker/lib/tablet/screens/game_layer.dart`](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_layer.dart] 는 라이어스포커에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerTabletGameLayer`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_auto_complete.dart](../../packages/game_kit/lib/game_flow/game_flow_auto_complete.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart](../../packages/game_liars_poker/lib/tablet/animations/round_start_reveal.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_helper.dart](../../packages/game_liars_poker/lib/tablet/screens/game_helper.dart)<br>- [packages/game_liars_poker/lib/tablet/providers/game_stage.dart](../../packages/game_liars_poker/lib/tablet/providers/game_stage.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/result.dart](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 127. [`packages/game_liars_poker/lib/tablet/screens/game_overlay.dart`](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_overlay.dart] 는 라이어스포커에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerTabletGameOverlay`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart](../../packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/tablet/providers/game_stage.dart](../../packages/game_liars_poker/lib/tablet/providers/game_stage.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/rolebook.dart](../../packages/game_liars_poker/lib/tablet/widgets/rolebook.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 128. [`packages/game_liars_poker/lib/tablet/screens/game_penalty.dart`](../../packages/game_liars_poker/lib/tablet/screens/game_penalty.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_penalty.dart] 는 라이어스포커에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerTabletGamePenalty`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/penalty/roulette.dart](../../packages/game_kit/lib/penalty/roulette.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 129. [`packages/game_liars_poker/lib/tablet/providers/game_stage.dart`](../../packages/game_liars_poker/lib/tablet/providers/game_stage.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_stage.dart] 는 라이어스포커에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerTabletStage`, `LiarsPokerTabletStageLabel`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

#### 130. [`packages/game_liars_poker/lib/tablet/tablet_board.dart`](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [tablet_game.dart] 는 라이어스포커에서 사용하는 태블릿 게임 화면의 진입점과 공통 흐름을 연결하는 파일이다.
- 핵심 공개 선언: `LiarsPokerTabletGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/mat_unroll_animation.dart](../../packages/game_kit/lib/shared/animations/mat_unroll_animation.dart)<br>- [packages/game_kit/lib/core/diagnostics/dev_error_log.dart](../../packages/game_kit/lib/core/diagnostics/dev_error_log.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_auto_complete.dart](../../packages/game_kit/lib/game_flow/game_flow_auto_complete.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/sound/game_background_music.dart](../../packages/game_kit/lib/sound/game_background_music.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/shared/models/game_state.dart](../../packages/game_liars_poker/lib/shared/models/game_state.dart)<br>- [packages/game_liars_poker/lib/shared/providers/session_provider.dart](../../packages/game_liars_poker/lib/shared/providers/session_provider.dart)<br>- [packages/game_liars_poker/lib/tablet/animations/game_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/game_animation.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_helper.dart](../../packages/game_liars_poker/lib/tablet/screens/game_helper.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_liars_poker/lib/tablet/screens/game_penalty.dart](../../packages/game_liars_poker/lib/tablet/screens/game_penalty.dart)<br>- [packages/game_liars_poker/lib/tablet/providers/game_stage.dart](../../packages/game_liars_poker/lib/tablet/providers/game_stage.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)<br>- [packages/game_liars_poker/lib/game_sounds.dart](../../packages/game_liars_poker/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)

#### 131. [`packages/game_liars_poker/lib/shared/services/command_service.dart`](../../packages/game_liars_poker/lib/shared/services/command_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [command_service.dart] 는 라이어스포커에서 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
- 핵심 공개 선언: `LiarsPokerCommandService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart](../../packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart)<br>- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)<br>- [test/liars_poker_interruption_finish_now_test.dart](../../test/liars_poker_interruption_finish_now_test.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)

#### 132. [`packages/game_liars_poker/lib/shared/services/query_service.dart`](../../packages/game_liars_poker/lib/shared/services/query_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [query_service.dart] 는 라이어스포커에서 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.
- 핵심 공개 선언: `LiarsPokerQueryService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/services/game_service.dart](../../packages/game_liars_poker/lib/shared/services/game_service.dart)<br>- [test/liars_poker_interruption_finish_now_test.dart](../../test/liars_poker_interruption_finish_now_test.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)

#### 133. [`packages/game_liars_poker/lib/shared/services/game_service.dart`](../../packages/game_liars_poker/lib/shared/services/game_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [game_service.dart] 는 라이어스포커에서 사용하는 게임의 조회·명령 서비스를 묶어 제공하는 파일이다.
- 핵심 공개 선언: `LiarsPokerService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_interruption_command_service.dart](../../packages/game_kit/lib/services/game_interruption_command_service.dart)<br>- [packages/game_liars_poker/lib/shared/services/command_service.dart](../../packages/game_liars_poker/lib/shared/services/command_service.dart)<br>- [packages/game_liars_poker/lib/shared/services/query_service.dart](../../packages/game_liars_poker/lib/shared/services/query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_liars_poker.dart](../../packages/game_liars_poker/lib/game_liars_poker.dart)<br>- [packages/game_liars_poker/lib/shared/providers/session_provider.dart](../../packages/game_liars_poker/lib/shared/providers/session_provider.dart)<br>- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [test/liars_poker_interruption_finish_now_test.dart](../../test/liars_poker_interruption_finish_now_test.dart)<br>- [test/liars_poker_rotation_test.dart](../../test/liars_poker_rotation_test.dart)

#### 134. [`packages/game_liars_poker/lib/game_sounds.dart`](../../packages/game_liars_poker/lib/game_sounds.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_sounds.dart] 는 라이어스포커에서 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart](../../packages/game_liars_poker/lib/tablet/animations/card_play_animation.dart)<br>- [packages/game_liars_poker/lib/shared/services/asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)<br>- [test/liars_poker_submit_sound_test.dart](../../test/liars_poker_submit_sound_test.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)

#### 135. [`packages/game_liars_poker/lib/phone/widgets/exit_modal.dart`](../../packages/game_liars_poker/lib/phone/widgets/exit_modal.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [exit_modal.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhoneExitModal`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/widgets/phone_exit_modal.dart](../../packages/game_kit/lib/widgets/phone_exit_modal.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)

#### 136. [`packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart`](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [hand_card_stack.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhoneHandCardStackController`, `PhoneHandCardStack`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/phone/animations/card_receive_animation.dart](../../packages/game_kit/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_kit/lib/widgets/game_card_face.dart](../../packages/game_kit/lib/widgets/game_card_face.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)<br>- [packages/game_liars_poker/lib/tablet/tablet_board.dart](../../packages/game_liars_poker/lib/tablet/tablet_board.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [test/liars_poker_hand_stack_rebuild_test.dart](../../test/liars_poker_hand_stack_rebuild_test.dart)

#### 137. [`packages/game_liars_poker/lib/phone/widgets/liar_accusation.dart`](../../packages/game_liars_poker/lib/phone/widgets/liar_accusation.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [liar_accusation.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `LiarAccusation`
- 이 파일이 직접 참조:
- [packages/game_liars_poker/lib/shared/widgets/pressable_button.dart](../../packages/game_liars_poker/lib/shared/widgets/pressable_button.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)

#### 138. [`packages/game_liars_poker/lib/phone/widgets/penalty_status.dart`](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [penalty_status.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhonePenaltyStatus`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/fade_hold_fade.dart](../../packages/game_kit/lib/shared/animations/fade_hold_fade.dart)<br>- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)

#### 139. [`packages/game_liars_poker/lib/phone/widgets/settings_dialog.dart`](../../packages/game_liars_poker/lib/phone/widgets/settings_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [settings_dialog.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhoneSettingsDialog`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)

#### 140. [`packages/game_liars_poker/lib/phone/widgets/spectator.dart`](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [spectator.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhoneSpectator`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/game_flow/leave_failure_notice.dart](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/widgets/phone_ripple_dialog.dart](../../packages/game_kit/lib/widgets/phone_ripple_dialog.dart)<br>- [packages/game_kit/lib/widgets/phone_rule_dialog.dart](../../packages/game_kit/lib/widgets/phone_rule_dialog.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/game_copy.dart](../../packages/game_liars_poker/lib/game_copy.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/exit_modal.dart](../../packages/game_liars_poker/lib/phone/widgets/exit_modal.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/settings_dialog.dart](../../packages/game_liars_poker/lib/phone/widgets/settings_dialog.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/top_bar.dart](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/phone_board.dart](../../packages/game_liars_poker/lib/phone/phone_board.dart)

#### 141. [`packages/game_liars_poker/lib/phone/widgets/top_bar.dart`](../../packages/game_liars_poker/lib/phone/widgets/top_bar.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [top_bar.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhoneGameTopBar`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/phone/animations/control_entry_animation.dart](../../packages/game_kit/lib/phone/animations/control_entry_animation.dart)<br>- [packages/game_kit/lib/widgets/phone_game_top_bar.dart](../../packages/game_kit/lib/widgets/phone_game_top_bar.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/spectator.dart](../../packages/game_liars_poker/lib/phone/widgets/spectator.dart)

#### 142. [`packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart`](../../packages/game_liars_poker/lib/phone/widgets/turn_action_switcher.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [turn_action_switcher.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `TurnActionSwitcher`, `TurnPlayerIndicator`, `PhonePlayerProfile`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_liars_poker/lib/shared/providers/game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/penalty_status.dart](../../packages/game_liars_poker/lib/phone/widgets/penalty_status.dart)

#### 143. [`packages/game_liars_poker/lib/phone/widgets/turn_timer.dart`](../../packages/game_liars_poker/lib/phone/widgets/turn_timer.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [turn_timer.dart] 는 라이어스포커에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `PhoneTimer`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_kit/lib/widgets/game_turn_countdown.dart](../../packages/game_kit/lib/widgets/game_turn_countdown.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [test/liars_poker_turn_timer_test.dart](../../test/liars_poker_turn_timer_test.dart)

#### 144. [`packages/game_liars_poker/lib/shared/widgets/pressable_button.dart`](../../packages/game_liars_poker/lib/shared/widgets/pressable_button.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [pressable_button.dart] 는 라이어스포커에서 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `LiarsPokerPressableAssetButton`, `LiarsPokerArcadeButtonSurface`, `LiarsPokerButtonSurface`
- 이 파일이 직접 참조:
- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/phone/screens/game_screen.dart](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)<br>- [packages/game_liars_poker/lib/phone/widgets/liar_accusation.dart](../../packages/game_liars_poker/lib/phone/widgets/liar_accusation.dart)<br>- [packages/game_liars_poker/lib/tablet/widgets/result.dart](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)

#### 145. [`packages/game_liars_poker/lib/tablet/widgets/result.dart`](../../packages/game_liars_poker/lib/tablet/widgets/result.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [result.dart] 는 라이어스포커에서 사용하는 태블릿 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `Result`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)<br>- [packages/game_liars_poker/lib/shared/widgets/pressable_button.dart](../../packages/game_liars_poker/lib/shared/widgets/pressable_button.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/screens/game_layer.dart](../../packages/game_liars_poker/lib/tablet/screens/game_layer.dart)

#### 146. [`packages/game_liars_poker/lib/tablet/widgets/rolebook.dart`](../../packages/game_liars_poker/lib/tablet/widgets/rolebook.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [rolebook.dart] 는 라이어스포커에서 사용하는 태블릿 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `RoleBook`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart)<br>- [packages/game_liars_poker/lib/game_assets.dart](../../packages/game_liars_poker/lib/game_assets.dart)<br>- [packages/game_liars_poker/lib/gen/assets.gen.dart](../../packages/game_liars_poker/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)

#### 147. [`packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart`](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [settings.dart] 는 라이어스포커에서 사용하는 태블릿 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `Setting`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_liars_poker/lib/tablet/screens/game_overlay.dart](../../packages/game_liars_poker/lib/tablet/screens/game_overlay.dart)

## 5. `game_final_call` — 파이널콜

- 설정: [packages/game_final_call/pubspec.yaml](../../packages/game_final_call/pubspec.yaml)
- 총 74개 (`(확장자 없음)` 3개, `.m4a` 4개, `.md` 1개, `.mp3` 2개, `.png` 7개, `.webp` 57개)
- 파일이 많은 폴더: `packages/game_final_call/assets/games/final_call/images/cards` 42개, `packages/game_final_call/assets/games/final_call/images/icons` 11개, `packages/game_final_call/assets/games/final_call/sounds` 7개, `packages/game_final_call/assets/games/final_call/images/button` 4개, `packages/game_final_call/assets/games/final_call/images/background` 2개, `packages/game_final_call/assets/games/final_call/images/layout` 2개, `packages/game_final_call/assets/games/final_call/images/modal` 2개, `packages/game_final_call/assets` 1개

#### 148. [`packages/game_final_call/lib/phone/animations/card_receive_animation.dart`](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [card_receive_animation.dart] 는 파이널콜에서 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `FinalCallPhoneCardReceiveAnimation`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_kit/lib/phone/animations/card_receive_animation.dart](../../packages/game_kit/lib/phone/animations/card_receive_animation.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/widgets/hand_card_stack.dart](../../packages/game_final_call/lib/phone/widgets/hand_card_stack.dart)

#### 149. [`packages/game_final_call/lib/tablet/animations/center_card_reveal.dart`](../../packages/game_final_call/lib/tablet/animations/center_card_reveal.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [tablet_center_card_reveal.dart] 는 파이널콜에서 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
- 핵심 공개 선언: `FinalCallCenterCardReveal`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)

#### 150. [`packages/game_final_call/lib/shared/providers/game_controller.dart`](../../packages/game_final_call/lib/shared/providers/game_controller.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [game_controller.dart] 는 파이널콜에서 사용하는 서버 상태 구독과 사용자 명령 흐름을 조정하는 파일이다.
- 핵심 공개 선언: `FinalCallController`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/models/game_state.dart](../../packages/game_final_call/lib/shared/models/game_state.dart)<br>- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [packages/game_kit/lib/core/error/user_error_message.dart](../../packages/game_kit/lib/core/error/user_error_message.dart)<br>- [packages/game_kit/lib/game_flow/game_finish.dart](../../packages/game_kit/lib/game_flow/game_finish.dart)<br>- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/providers/session_provider.dart](../../packages/game_final_call/lib/shared/providers/session_provider.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [test/final_call_interruption_finish_now_test.dart](../../test/final_call_interruption_finish_now_test.dart)

#### 151. [`packages/game_final_call/lib/game_copy.dart`](../../packages/game_final_call/lib/game_copy.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_copy.dart] 는 파이널콜에서 사용하는 게임 화면에서 사용하는 문구를 모아 둔 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart)

#### 152. [`packages/game_final_call/lib/tablet/tablet_board.dart`](../../packages/game_final_call/lib/tablet/tablet_board.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_flow_config.dart] 는 파이널콜에서 사용하는 게임 단계와 안내 시간표를 정의하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/tablet/providers/game_stage.dart](../../packages/game_final_call/lib/tablet/providers/game_stage.dart)<br>- [packages/game_kit/lib/game_flow/game_announcement.dart](../../packages/game_kit/lib/game_flow/game_announcement.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 153. [`packages/game_final_call/lib/game_final_call.dart`](../../packages/game_final_call/lib/game_final_call.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game.dart] 는 파이널콜에서 사용하는 게임 정보를 플랫폼 공통 계약에 연결하는 파일이다.
- 핵심 공개 선언: `FinalCallGame`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_kit/lib/widgets/critical_network_guard.dart](../../packages/game_kit/lib/widgets/critical_network_guard.dart)
- 이 파일을 직접 참조:
- [lib/games/game_registry.dart](../../lib/games/game_registry.dart)

#### 154. [`packages/game_final_call/lib/game_assets.dart`](../../packages/game_final_call/lib/game_assets.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_assets.dart] 는 파이널콜에서 사용하는 생성된 에셋 경로를 실행 코드에 연결하는 파일이다.
- 핵심 공개 선언: `FinalCallImageX`, `FinalCallImageListX`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_kit/lib/core/assets/game_image.dart](../../packages/game_kit/lib/core/assets/game_image.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/animations/card_receive_animation.dart](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_final_call/lib/tablet/widgets/result_overlay.dart](../../packages/game_final_call/lib/tablet/widgets/result_overlay.dart)<br>- [packages/game_final_call/lib/tablet/widgets/rolebook.dart](../../packages/game_final_call/lib/tablet/widgets/rolebook.dart)

#### 155. [`packages/game_final_call/lib/game_final_call.dart`](../../packages/game_final_call/lib/game_final_call.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_final_call.dart] 는 파이널콜 패키지의 대표 진입 위치를 표시하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 156. [`packages/game_final_call/lib/gen/assets.gen.dart`](../../packages/game_final_call/lib/gen/assets.gen.dart)

- 리뷰 단계: **11. 생성 코드 확인**
- 역할: FlutterGen이 패키지 assets를 타입 안전한 Dart 경로로 생성한 파일이다. 직접 수정하지 않는다.
- 핵심 공개 선언: 생성 코드 — 선언 목록보다 생성 원본과 사용 경로만 확인
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/animations/card_receive_animation.dart](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_overlay.dart](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_final_call/lib/tablet/widgets/result_overlay.dart](../../packages/game_final_call/lib/tablet/widgets/result_overlay.dart)<br>- [packages/game_final_call/lib/tablet/widgets/rolebook.dart](../../packages/game_final_call/lib/tablet/widgets/rolebook.dart)

#### 157. [`packages/game_final_call/lib/shared/services/asset_preloader.dart`](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_loading.dart] 는 파이널콜에서 사용하는 게임 진입 전 로딩과 준비 흐름을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/game_sounds.dart](../../packages/game_final_call/lib/game_sounds.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_kit/lib/core/diagnostics/crash_reporting.dart](../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 158. [`packages/game_final_call/lib/shared/models/game_models.dart`](../../packages/game_final_call/lib/shared/models/game_models.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_models.dart] 는 파이널콜에서 사용하는 게임 데이터를 타입으로 표현하고 변환하는 파일이다.
- 핵심 공개 선언: `FinalCallCard`, `FinalCallCombinationType`, `FinalCallScoreResult`, `FinalCallDiscardEvent`, `FinalCallPlayer`, `FinalCallTeam`, `FinalCallRoundResult`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/animations/card_receive_animation.dart](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_final_call/lib/tablet/animations/center_card_reveal.dart](../../packages/game_final_call/lib/tablet/animations/center_card_reveal.dart)<br>- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/shared/models/game_state.dart](../../packages/game_final_call/lib/shared/models/game_state.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/game_sounds.dart](../../packages/game_final_call/lib/game_sounds.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/hand_card_stack.dart](../../packages/game_final_call/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart)<br>- [packages/game_final_call/lib/tablet/widgets/result_overlay.dart](../../packages/game_final_call/lib/tablet/widgets/result_overlay.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)

#### 159. [`packages/game_final_call/lib/shared/models/game_state.dart`](../../packages/game_final_call/lib/shared/models/game_state.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [game_state.dart] 는 파이널콜에서 사용하는 게임 상태와 Riverpod 생명주기를 관리하는 파일이다.
- 핵심 공개 선언: `FinalCallGameState`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/shared/providers/session_provider.dart](../../packages/game_final_call/lib/shared/providers/session_provider.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 160. [`packages/game_final_call/lib/shared/providers/session_provider.dart`](../../packages/game_final_call/lib/shared/providers/session_provider.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [session_provider.dart] 는 파이널콜에서 사용하는 게임 상태와 Riverpod 생명주기를 관리하는 파일이다.
- 핵심 공개 선언: `FinalCallSessionArgs`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/shared/models/game_state.dart](../../packages/game_final_call/lib/shared/models/game_state.dart)<br>- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [test/final_call_interruption_finish_now_test.dart](../../test/final_call_interruption_finish_now_test.dart)<br>- [test/final_call_warmup_test.dart](../../test/final_call_warmup_test.dart)

#### 161. [`packages/game_final_call/lib/phone/screens/game_screen.dart`](../../packages/game_final_call/lib/phone/screens/game_screen.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_screen.dart] 는 파이널콜에서 사용하는 휴대폰 게임의 세부 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallPhoneGameScreen`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/game_copy.dart](../../packages/game_final_call/lib/game_copy.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/hand_card_stack.dart](../../packages/game_final_call/lib/phone/widgets/hand_card_stack.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart](../../packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart)<br>- [packages/game_final_call/lib/phone/widgets/turn_timer.dart](../../packages/game_final_call/lib/phone/widgets/turn_timer.dart)<br>- [packages/game_kit/lib/phone/animations/control_entry_animation.dart](../../packages/game_kit/lib/phone/animations/control_entry_animation.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/game_feedback.dart](../../packages/game_kit/lib/game_feedback.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)

#### 162. [`packages/game_final_call/lib/phone/phone_board.dart`](../../packages/game_final_call/lib/phone/phone_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [phone_game.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면의 진입과 전체 흐름을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallPhoneGame`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/shared/models/game_state.dart](../../packages/game_final_call/lib/shared/models/game_state.dart)<br>- [packages/game_final_call/lib/shared/providers/session_provider.dart](../../packages/game_final_call/lib/shared/providers/session_provider.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/top_bar.dart](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/game_feedback.dart](../../packages/game_kit/lib/game_feedback.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/game_flow/game_screen_phase.dart](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)<br>- [packages/game_kit/lib/game_flow/leave_failure_notice.dart](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/game_route_exit.dart](../../packages/game_kit/lib/widgets/game_route_exit.dart)<br>- [packages/game_kit/lib/widgets/phone_exit_modal.dart](../../packages/game_kit/lib/widgets/phone_exit_modal.dart)<br>- [packages/game_kit/lib/widgets/phone_result_dialog.dart](../../packages/game_kit/lib/widgets/phone_result_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)

#### 163. [`packages/game_final_call/lib/tablet/animations/game_animation.dart`](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_animation.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletCallAnimation`, `FinalCallTabletDiscardAnimation`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_helper.dart](../../packages/game_final_call/lib/tablet/screens/game_helper.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 164. [`packages/game_final_call/lib/tablet/screens/game_helper.dart`](../../packages/game_final_call/lib/tablet/screens/game_helper.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_helper.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)

#### 165. [`packages/game_final_call/lib/tablet/screens/game_layer.dart`](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_layer.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletGameLayer`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/tablet/animations/center_card_reveal.dart](../../packages/game_final_call/lib/tablet/animations/center_card_reveal.dart)<br>- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_helper.dart](../../packages/game_final_call/lib/tablet/screens/game_helper.dart)<br>- [packages/game_final_call/lib/tablet/providers/game_stage.dart](../../packages/game_final_call/lib/tablet/providers/game_stage.dart)<br>- [packages/game_final_call/lib/game_sounds.dart](../../packages/game_final_call/lib/game_sounds.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_kit/lib/tablet/animations/board_element_entrance.dart](../../packages/game_kit/lib/tablet/animations/board_element_entrance.dart)<br>- [packages/game_kit/lib/tablet/animations/card_deal_animation.dart](../../packages/game_kit/lib/tablet/animations/card_deal_animation.dart)<br>- [packages/game_kit/lib/shared/animations/one_shot_timeline.dart](../../packages/game_kit/lib/shared/animations/one_shot_timeline.dart)<br>- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_auto_complete.dart](../../packages/game_kit/lib/game_flow/game_flow_auto_complete.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_config.dart](../../packages/game_kit/lib/game_flow/game_flow_config.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 166. [`packages/game_final_call/lib/tablet/screens/game_overlay.dart`](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_overlay.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletGameOverlay`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/tablet/widgets/rolebook.dart](../../packages/game_final_call/lib/tablet/widgets/rolebook.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart](../../packages/game_kit/lib/widgets/tablet_game_menu_overlay.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 167. [`packages/game_final_call/lib/tablet/providers/game_stage.dart`](../../packages/game_final_call/lib/tablet/providers/game_stage.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_stage.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletStage`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 168. [`packages/game_final_call/lib/tablet/tablet_board.dart`](../../packages/game_final_call/lib/tablet/tablet_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [tablet_game.dart] 는 파이널콜에서 사용하는 태블릿 게임 화면의 진입과 전체 흐름을 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletGame`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/shared/models/game_state.dart](../../packages/game_final_call/lib/shared/models/game_state.dart)<br>- [packages/game_final_call/lib/shared/providers/session_provider.dart](../../packages/game_final_call/lib/shared/providers/session_provider.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_overlay.dart](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)<br>- [packages/game_final_call/lib/tablet/providers/game_stage.dart](../../packages/game_final_call/lib/tablet/providers/game_stage.dart)<br>- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [packages/game_final_call/lib/game_sounds.dart](../../packages/game_final_call/lib/game_sounds.dart)<br>- [packages/game_final_call/lib/tablet/widgets/result_overlay.dart](../../packages/game_final_call/lib/tablet/widgets/result_overlay.dart)<br>- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/sound/game_background_music.dart](../../packages/game_kit/lib/sound/game_background_music.dart)<br>- [packages/game_kit/lib/widgets/game_announcement_layer.dart](../../packages/game_kit/lib/widgets/game_announcement_layer.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/game_route_exit.dart](../../packages/game_kit/lib/widgets/game_route_exit.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)

#### 169. [`packages/game_final_call/lib/shared/services/command_service.dart`](../../packages/game_final_call/lib/shared/services/command_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [command_service.dart] 는 파이널콜에서 사용하는 Cloud Functions 쓰기 명령을 모아 둔 파일이다.
- 핵심 공개 선언: `FinalCallCommandService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [test/final_call_interruption_finish_now_test.dart](../../test/final_call_interruption_finish_now_test.dart)<br>- [test/final_call_warmup_test.dart](../../test/final_call_warmup_test.dart)

#### 170. [`packages/game_final_call/lib/shared/services/query_service.dart`](../../packages/game_final_call/lib/shared/services/query_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [query_service.dart] 는 파이널콜에서 사용하는 Realtime Database 읽기와 구독을 모아 둔 파일이다.
- 핵심 공개 선언: `FinalCallQueryService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/game_service.dart](../../packages/game_final_call/lib/shared/services/game_service.dart)<br>- [test/final_call_interruption_finish_now_test.dart](../../test/final_call_interruption_finish_now_test.dart)<br>- [test/final_call_warmup_test.dart](../../test/final_call_warmup_test.dart)

#### 171. [`packages/game_final_call/lib/shared/services/game_service.dart`](../../packages/game_final_call/lib/shared/services/game_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [game_service.dart] 는 파이널콜에서 사용하는 게임의 읽기·쓰기 서비스를 묶어 제공하는 파일이다.
- 핵심 공개 선언: `FinalCallService`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/services/command_service.dart](../../packages/game_final_call/lib/shared/services/command_service.dart)<br>- [packages/game_final_call/lib/shared/services/query_service.dart](../../packages/game_final_call/lib/shared/services/query_service.dart)<br>- [packages/game_kit/lib/services/game_interruption_command_service.dart](../../packages/game_kit/lib/services/game_interruption_command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/game_final_call.dart](../../packages/game_final_call/lib/game_final_call.dart)<br>- [packages/game_final_call/lib/shared/providers/session_provider.dart](../../packages/game_final_call/lib/shared/providers/session_provider.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [test/final_call_interruption_finish_now_test.dart](../../test/final_call_interruption_finish_now_test.dart)<br>- [test/final_call_warmup_test.dart](../../test/final_call_warmup_test.dart)

#### 172. [`packages/game_final_call/lib/game_sounds.dart`](../../packages/game_final_call/lib/game_sounds.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_sounds.dart] 는 파이널콜에서 사용하는 게임 단계에 맞는 배경음과 효과음 재생을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/shared/services/asset_preloader.dart](../../packages/game_final_call/lib/shared/services/asset_preloader.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)

#### 173. [`packages/game_final_call/lib/shared/widgets/card_view.dart`](../../packages/game_final_call/lib/shared/widgets/card_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [card_view.dart] 는 파이널콜에서 사용하는 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallCardView`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/animations/card_receive_animation.dart](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_final_call/lib/tablet/animations/center_card_reveal.dart](../../packages/game_final_call/lib/tablet/animations/center_card_reveal.dart)<br>- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/tablet/animations/game_animation.dart](../../packages/game_final_call/lib/tablet/animations/game_animation.dart)<br>- [packages/game_final_call/lib/tablet/screens/game_layer.dart](../../packages/game_final_call/lib/tablet/screens/game_layer.dart)<br>- [packages/game_final_call/lib/phone/widgets/card_change_dialog.dart](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)<br>- [packages/game_final_call/lib/phone/widgets/game_actions.dart](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)<br>- [packages/game_final_call/lib/phone/widgets/hand_card_stack.dart](../../packages/game_final_call/lib/phone/widgets/hand_card_stack.dart)

#### 174. [`packages/game_final_call/lib/phone/widgets/card_change_dialog.dart`](../../packages/game_final_call/lib/phone/widgets/card_change_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [card_change_dialog.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallCardChangeDialog`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_copy.dart](../../packages/game_final_call/lib/game_copy.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)

#### 175. [`packages/game_final_call/lib/phone/widgets/game_actions.dart`](../../packages/game_final_call/lib/phone/widgets/game_actions.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_actions.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallPhoneActions`, `FinalCallPrimaryActionHint`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/game_copy.dart](../../packages/game_final_call/lib/game_copy.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)

#### 176. [`packages/game_final_call/lib/phone/widgets/hand_card_stack.dart`](../../packages/game_final_call/lib/phone/widgets/hand_card_stack.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [hand_card_stack.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallPhoneHandCardStack`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/phone/animations/card_receive_animation.dart](../../packages/game_final_call/lib/phone/animations/card_receive_animation.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_final_call/lib/shared/widgets/card_view.dart](../../packages/game_final_call/lib/shared/widgets/card_view.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)

#### 177. [`packages/game_final_call/lib/phone/widgets/top_bar.dart`](../../packages/game_final_call/lib/phone/widgets/top_bar.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [top_bar.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallPhoneTopBar`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/shared/providers/game_controller.dart](../../packages/game_final_call/lib/shared/providers/game_controller.dart)<br>- [packages/game_final_call/lib/game_copy.dart](../../packages/game_final_call/lib/game_copy.dart)<br>- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_kit/lib/widgets/phone_game_top_bar.dart](../../packages/game_kit/lib/widgets/phone_game_top_bar.dart)<br>- [packages/game_kit/lib/widgets/phone_ripple_dialog.dart](../../packages/game_kit/lib/widgets/phone_ripple_dialog.dart)<br>- [packages/game_kit/lib/widgets/phone_rule_dialog.dart](../../packages/game_kit/lib/widgets/phone_rule_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [packages/game_final_call/lib/phone/phone_board.dart](../../packages/game_final_call/lib/phone/phone_board.dart)

#### 178. [`packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart`](../../packages/game_final_call/lib/phone/widgets/turn_action_switcher.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [turn_action_switcher.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTurnActionSwitcher`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_copy.dart](../../packages/game_final_call/lib/game_copy.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)

#### 179. [`packages/game_final_call/lib/phone/widgets/turn_timer.dart`](../../packages/game_final_call/lib/phone/widgets/turn_timer.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [turn_timer.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTimer`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_kit/lib/widgets/game_turn_countdown.dart](../../packages/game_kit/lib/widgets/game_turn_countdown.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/phone/screens/game_screen.dart](../../packages/game_final_call/lib/phone/screens/game_screen.dart)<br>- [test/final_call_turn_timer_test.dart](../../test/final_call_turn_timer_test.dart)

#### 180. [`packages/game_final_call/lib/tablet/widgets/result_overlay.dart`](../../packages/game_final_call/lib/tablet/widgets/result_overlay.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [result_overlay.dart] 는 파이널콜에서 사용하는 태블릿 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallResultOverlay`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_final_call/lib/shared/models/game_models.dart](../../packages/game_final_call/lib/shared/models/game_models.dart)<br>- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/tablet_board.dart](../../packages/game_final_call/lib/tablet/tablet_board.dart)

#### 181. [`packages/game_final_call/lib/tablet/widgets/rolebook.dart`](../../packages/game_final_call/lib/tablet/widgets/rolebook.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [rolebook.dart] 는 파이널콜에서 사용하는 태블릿 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletRoleBook`
- 이 파일이 직접 참조:
- [packages/game_final_call/lib/game_assets.dart](../../packages/game_final_call/lib/game_assets.dart)<br>- [packages/game_final_call/lib/gen/assets.gen.dart](../../packages/game_final_call/lib/gen/assets.gen.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_overlay.dart](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)

#### 182. [`packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart`](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [settings.dart] 는 파이널콜에서 사용하는 태블릿 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
- 핵심 공개 선언: `FinalCallTabletSetting`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)
- 이 파일을 직접 참조:
- [packages/game_final_call/lib/tablet/screens/game_overlay.dart](../../packages/game_final_call/lib/tablet/screens/game_overlay.dart)

## 6. `game_mafia` — 마피아

- 설정: [packages/game_mafia/pubspec.yaml](../../packages/game_mafia/pubspec.yaml)
- 총 125개 (`(확장자 없음)` 2개, `.m4a` 5개, `.md` 1개, `.mp3` 4개, `.png` 13개, `.svg` 1개, `.webp` 99개)
- 파일이 많은 폴더: `packages/game_mafia/assets/games/mafia/images/cards` 49개, `packages/game_mafia/assets/games/mafia/images/background` 19개, `packages/game_mafia/assets/games/mafia/images/roles` 19개, `packages/game_mafia/assets/games/mafia/images/icons` 9개, `packages/game_mafia/assets/games/mafia/images/other` 9개, `packages/game_mafia/assets/games/mafia/sounds` 8개, `packages/game_mafia/assets/games/mafia/images/background/bird` 4개, `packages/game_mafia/assets/games/mafia/images/banner` 4개

#### 183. [`packages/game_mafia/lib/shared/animations/announcement_reveal.dart`](../../packages/game_mafia/lib/shared/animations/announcement_reveal.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [announcement_reveal.dart] 는 마피아에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `MafiaAnnouncementReveal`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_sequence.dart](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)<br>- [test/mafia_stage_notice_test.dart](../../test/mafia_stage_notice_test.dart)

#### 184. [`packages/game_mafia/lib/shared/animations/ballot_animations.dart`](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [ballot_animations.dart] 는 마피아에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `MafiaBallotPaper`, `MafiaTabletProjection`, `MafiaBallotTossLayer`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/day_view.dart](../../packages/game_mafia/lib/tablet/screens/day_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/vote_view.dart](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)<br>- [test/mafia_ballot_animation_test.dart](../../test/mafia_ballot_animation_test.dart)<br>- [test/mafia_vote_submit_animation_test.dart](../../test/mafia_vote_submit_animation_test.dart)

#### 185. [`packages/game_mafia/lib/shared/animations/ejection_text.dart`](../../packages/game_mafia/lib/shared/animations/ejection_text.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [ejection_text.dart] 는 마피아에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `MafiaEjectionText`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [test/mafia_ejection_text_test.dart](../../test/mafia_ejection_text_test.dart)

#### 186. [`packages/game_mafia/lib/shared/animations/phase_transition.dart`](../../packages/game_mafia/lib/shared/animations/phase_transition.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [phase_transition.dart] 는 마피아에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `MafiaPhaseTransition`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [test/mafia_phase_transition_test.dart](../../test/mafia_phase_transition_test.dart)

#### 187. [`packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart`](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [role_deal_toss_animation.dart] 는 마피아에서 사용하는 게임 화면의 등장·전환·카드 연출 시간을 관리하는 파일이다.
- 핵심 공개 선언: `MafiaRoleDealTossAnimation`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/player_layouts/player_slot_positions.dart](../../packages/game_kit/lib/player_layouts/player_slot_positions.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [test/mafia_night_cue_test.dart](../../test/mafia_night_cue_test.dart)<br>- [test/mafia_role_deal_toss_test.dart](../../test/mafia_role_deal_toss_test.dart)

#### 188. [`packages/game_mafia/lib/shared/providers/game_controller.dart`](../../packages/game_mafia/lib/shared/providers/game_controller.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [game_controller.dart] 는 마피아에서 사용하는 게임 규칙과 사용자 입력에 따른 진행 명령을 조율하는 파일이다.
- 핵심 공개 선언: `MafiaController`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/diagnostics/crash_reporting.dart](../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart)<br>- [packages/game_kit/lib/core/error/user_error_message.dart](../../packages/game_kit/lib/core/error/user_error_message.dart)<br>- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)<br>- [packages/game_mafia/lib/shared/models/state_models.dart](../../packages/game_mafia/lib/shared/models/state_models.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/session_provider.dart](../../packages/game_mafia/lib/shared/providers/session_provider.dart)<br>- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_interruption_finish_now_test.dart](../../test/mafia_interruption_finish_now_test.dart)

#### 189. [`packages/game_mafia/lib/game_assets.dart`](../../packages/game_mafia/lib/game_assets.dart)

- 리뷰 단계: **4. 에셋 경계**
- 역할: [game_assets.dart] 는 마피아 이미지 에셋을 실행 코드에 연결하는 파일이다.
- 핵심 공개 선언: `MafiaImageX`, `MafiaImageListX`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_image.dart](../../packages/game_kit/lib/core/assets/game_image.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_mafia/lib/shared/widgets/result_art.dart](../../packages/game_mafia/lib/shared/widgets/result_art.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)<br>- [packages/game_mafia/lib/tablet/screens/day_view.dart](../../packages/game_mafia/lib/tablet/screens/day_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/screens/night_bird.dart](../../packages/game_mafia/lib/tablet/screens/night_bird.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/shared/widgets/flip_card.dart](../../packages/game_mafia/lib/shared/widgets/flip_card.dart)<br>- [packages/game_mafia/lib/phone/widgets/day_discussion_view.dart](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)<br>- [packages/game_mafia/lib/phone/widgets/role_card_layer.dart](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)

#### 190. [`packages/game_mafia/lib/game_mafia.dart`](../../packages/game_mafia/lib/game_mafia.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_mafia.dart] 는 마피아 패키지의 대표 진입 위치를 표시하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- 저장소 내부 import/export 없음

#### 191. [`packages/game_mafia/lib/gen/assets.gen.dart`](../../packages/game_mafia/lib/gen/assets.gen.dart)

- 리뷰 단계: **11. 생성 코드 확인**
- 역할: FlutterGen이 패키지 assets를 타입 안전한 Dart 경로로 생성한 파일이다. 직접 수정하지 않는다.
- 핵심 공개 선언: 생성 코드 — 선언 목록보다 생성 원본과 사용 경로만 확인
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_mafia/lib/shared/widgets/result_art.dart](../../packages/game_mafia/lib/shared/widgets/result_art.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)<br>- [packages/game_mafia/lib/tablet/screens/day_view.dart](../../packages/game_mafia/lib/tablet/screens/day_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/screens/night_bird.dart](../../packages/game_mafia/lib/tablet/screens/night_bird.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/day_discussion_view.dart](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)<br>- [packages/game_mafia/lib/phone/widgets/role_card_layer.dart](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)

#### 192. [`packages/game_mafia/lib/shared/services/asset_preloader.dart`](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_loading.dart] 는 마피아에서 사용하는 게임 진입 중 필요한 준비 상태와 로딩 화면을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/diagnostics/crash_reporting.dart](../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)

#### 193. [`packages/game_mafia/lib/game_copy.dart`](../../packages/game_mafia/lib/game_copy.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_copy.dart] 는 마피아에서 사용하는 게임 화면에서 사용하는 문구를 한곳에 모아둔 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/phone/widgets/day_discussion_view.dart](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)<br>- [test/mafia_copy_test.dart](../../test/mafia_copy_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_stage_notice_test.dart](../../test/mafia_stage_notice_test.dart)

#### 194. [`packages/game_mafia/lib/shared/models/server_timing.dart`](../../packages/game_mafia/lib/shared/models/server_timing.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_flow_config.dart] 는 마피아에서 사용하는 게임의 공통 진행 화면에 필요한 설정을 연결하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_stage_notice_test.dart](../../test/mafia_stage_notice_test.dart)

#### 195. [`packages/game_mafia/lib/game_mafia.dart`](../../packages/game_mafia/lib/game_mafia.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game.dart] 는 마피아에서 사용하는 게임 패키지를 플랫폼에 연결하는 진입 계약을 구현하는 파일이다.
- 핵심 공개 선언: `MafiaGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/template_game.dart](../../packages/game_kit/lib/template_game.dart)<br>- [packages/game_kit/lib/widgets/critical_network_guard.dart](../../packages/game_kit/lib/widgets/critical_network_guard.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [lib/games/game_registry.dart](../../lib/games/game_registry.dart)

#### 196. [`packages/game_mafia/lib/shared/widgets/result_art.dart`](../../packages/game_mafia/lib/shared/widgets/result_art.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [result_art.dart] 는 마피아 승리 결과에 맞는 그림을 선택하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_view.dart](../../packages/game_mafia/lib/phone/widgets/result_view.dart)<br>- [test/mafia_neutral_result_art_test.dart](../../test/mafia_neutral_result_art_test.dart)<br>- [test/mafia_result_test.dart](../../test/mafia_result_test.dart)

#### 197. [`packages/game_mafia/lib/shared/models/game_composition.dart`](../../packages/game_mafia/lib/shared/models/game_composition.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [game_composition.dart] 는 마피아에서 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `MafiaGameMode`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)<br>- [test/mafia_player_select_grid_test.dart](../../test/mafia_player_select_grid_test.dart)<br>- [test/mafia_role_catalog_test.dart](../../test/mafia_role_catalog_test.dart)

#### 198. [`packages/game_mafia/lib/shared/models/player.dart`](../../packages/game_mafia/lib/shared/models/player.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [player.dart] 는 마피아에서 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `MafiaPlayer`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/night_action_view.dart](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_sequence.dart](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/vote_view.dart](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)<br>- [test/mafia_ballot_animation_test.dart](../../test/mafia_ballot_animation_test.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)<br>- [test/mafia_investigation_result_test.dart](../../test/mafia_investigation_result_test.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_new_role_views_test.dart](../../test/mafia_new_role_views_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_phase_exit_test.dart](../../test/mafia_phase_exit_test.dart)<br>- [test/mafia_result_test.dart](../../test/mafia_result_test.dart)<br>- [test/mafia_role_deal_toss_test.dart](../../test/mafia_role_deal_toss_test.dart)<br>- [test/mafia_stage_notice_test.dart](../../test/mafia_stage_notice_test.dart)<br>- [test/mafia_tablet_result_test.dart](../../test/mafia_tablet_result_test.dart)<br>- [test/mafia_vote_submit_animation_test.dart](../../test/mafia_vote_submit_animation_test.dart)

#### 199. [`packages/game_mafia/lib/shared/models/role.dart`](../../packages/game_mafia/lib/shared/models/role.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [role.dart] 는 마피아에서 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `MafiaFaction`, `MafiaRoleTier`, `MafiaAbilityTiming`, `MafiaNightAction`, `MafiaNightTargetScope`, `MafiaNightPhase`, `MafiaInvestigationAppearance`, `MafiaWinCondition`, `MafiaRole`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/widgets/result_art.dart](../../packages/game_mafia/lib/shared/widgets/result_art.dart)<br>- [packages/game_mafia/lib/shared/models/game_composition.dart](../../packages/game_mafia/lib/shared/models/game_composition.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)<br>- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)<br>- [packages/game_mafia/lib/phone/widgets/day_discussion_view.dart](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/night_action_view.dart](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_sequence.dart](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_view.dart](../../packages/game_mafia/lib/phone/widgets/result_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/role_card_layer.dart](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/vote_view.dart](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)<br>- [test/mafia_investigation_result_test.dart](../../test/mafia_investigation_result_test.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_neutral_result_art_test.dart](../../test/mafia_neutral_result_art_test.dart)<br>- [test/mafia_new_role_views_test.dart](../../test/mafia_new_role_views_test.dart)<br>- [test/mafia_night_cue_test.dart](../../test/mafia_night_cue_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_result_test.dart](../../test/mafia_result_test.dart)<br>- [test/mafia_role_catalog_test.dart](../../test/mafia_role_catalog_test.dart)<br>- [test/mafia_tablet_result_test.dart](../../test/mafia_tablet_result_test.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)

#### 200. [`packages/game_mafia/lib/shared/models/role_catalog.dart`](../../packages/game_mafia/lib/shared/models/role_catalog.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [role_catalog.dart] 는 마피아에서 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/widgets/result_art.dart](../../packages/game_mafia/lib/shared/widgets/result_art.dart)<br>- [packages/game_mafia/lib/shared/models/game_composition.dart](../../packages/game_mafia/lib/shared/models/game_composition.dart)<br>- [packages/game_mafia/lib/tablet/screens/role_setup_screen.dart](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/phone/widgets/night_action_view.dart](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)<br>- [test/mafia_copy_test.dart](../../test/mafia_copy_test.dart)<br>- [test/mafia_day_discussion_test.dart](../../test/mafia_day_discussion_test.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)<br>- [test/mafia_investigation_result_test.dart](../../test/mafia_investigation_result_test.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_neutral_result_art_test.dart](../../test/mafia_neutral_result_art_test.dart)<br>- [test/mafia_new_role_views_test.dart](../../test/mafia_new_role_views_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_phase_exit_test.dart](../../test/mafia_phase_exit_test.dart)<br>- [test/mafia_phase_transition_test.dart](../../test/mafia_phase_transition_test.dart)<br>- [test/mafia_role_card_layer_test.dart](../../test/mafia_role_card_layer_test.dart)<br>- [test/mafia_role_card_naming_test.dart](../../test/mafia_role_card_naming_test.dart)<br>- [test/mafia_role_catalog_test.dart](../../test/mafia_role_catalog_test.dart)<br>- [test/mafia_tablet_result_test.dart](../../test/mafia_tablet_result_test.dart)<br>- [test/mafia_vote_submit_animation_test.dart](../../test/mafia_vote_submit_animation_test.dart)

#### 201. [`packages/game_mafia/lib/shared/models/state_models.dart`](../../packages/game_mafia/lib/shared/models/state_models.dart)

- 리뷰 단계: **5. 게임 계약·모델**
- 역할: [state_models.dart] 는 마피아에서 사용하는 게임 상태와 규칙 데이터를 Dart 객체로 표현하는 파일이다.
- 핵심 공개 선언: `MafiaMorningResult`, `MafiaNightActionCue`, `MafiaVoteResult`, `MafiaInvestigation`
- 이 파일이 직접 참조:
- 저장소 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/tablet/services/night_cue_speaker.dart](../../packages/game_mafia/lib/tablet/services/night_cue_speaker.dart)<br>- [packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)<br>- [test/mafia_ballot_animation_test.dart](../../test/mafia_ballot_animation_test.dart)<br>- [test/mafia_game_state_copy_with_test.dart](../../test/mafia_game_state_copy_with_test.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_night_cue_test.dart](../../test/mafia_night_cue_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_stage_notice_test.dart](../../test/mafia_stage_notice_test.dart)

#### 202. [`packages/game_mafia/lib/shared/models/game_state.dart`](../../packages/game_mafia/lib/shared/models/game_state.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [game_state.dart] 는 마피아에서 사용하는 서버에서 받은 게임 상태와 화면 구독 상태를 관리하는 파일이다.
- 핵심 공개 선언: `MafiaGameState`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/game_flow/game_interruption.dart](../../packages/game_kit/lib/game_flow/game_interruption.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/state_models.dart](../../packages/game_mafia/lib/shared/models/state_models.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/providers/session_provider.dart](../../packages/game_mafia/lib/shared/providers/session_provider.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_game_state_copy_with_test.dart](../../test/mafia_game_state_copy_with_test.dart)

#### 203. [`packages/game_mafia/lib/shared/providers/session_provider.dart`](../../packages/game_mafia/lib/shared/providers/session_provider.dart)

- 리뷰 단계: **7. 상태·제어**
- 역할: [session_provider.dart] 는 마피아에서 사용하는 서버에서 받은 게임 상태와 화면 구독 상태를 관리하는 파일이다.
- 핵심 공개 선언: `MafiaSessionArgs`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_interruption_finish_now_test.dart](../../test/mafia_interruption_finish_now_test.dart)<br>- [test/mafia_room_gone_test.dart](../../test/mafia_room_gone_test.dart)

#### 204. [`packages/game_mafia/lib/phone/screens/game_screen.dart`](../../packages/game_mafia/lib/phone/screens/game_screen.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_screen.dart] 는 마피아에서 사용하는 휴대폰에서 보이는 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaPhoneGameScreen`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/widgets/game_turn_countdown.dart](../../packages/game_kit/lib/widgets/game_turn_countdown.dart)<br>- [packages/game_mafia/lib/shared/animations/phase_transition.dart](../../packages/game_mafia/lib/shared/animations/phase_transition.dart)<br>- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/models/server_timing.dart](../../packages/game_mafia/lib/shared/models/server_timing.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/phone/widgets/day_discussion_view.dart](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/night_action_view.dart](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/role_card_layer.dart](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/vote_view.dart](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)

#### 205. [`packages/game_mafia/lib/phone/phone_board.dart`](../../packages/game_mafia/lib/phone/phone_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [phone_game.dart] 는 마피아에서 사용하는 휴대폰 게임 화면의 진입점과 공통 흐름을 연결하는 파일이다.
- 핵심 공개 선언: `MafiaPhoneGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/game_flow/game_flow_copy.dart](../../packages/game_kit/lib/game_flow/game_flow_copy.dart)<br>- [packages/game_kit/lib/game_flow/game_screen_phase.dart](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)<br>- [packages/game_kit/lib/game_flow/leave_failure_notice.dart](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)<br>- [packages/game_kit/lib/game_flow/phone_game_shell.dart](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/game_route_exit.dart](../../packages/game_kit/lib/widgets/game_route_exit.dart)<br>- [packages/game_kit/lib/widgets/phone_exit_modal.dart](../../packages/game_kit/lib/widgets/phone_exit_modal.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/shared/providers/session_provider.dart](../../packages/game_mafia/lib/shared/providers/session_provider.dart)<br>- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_sequence.dart](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)<br>- [packages/game_mafia/lib/phone/widgets/top_bar.dart](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)

#### 206. [`packages/game_mafia/lib/tablet/screens/day_view.dart`](../../packages/game_mafia/lib/tablet/screens/day_view.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [day_view.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletDayView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [test/mafia_ballot_animation_test.dart](../../test/mafia_ballot_animation_test.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)

#### 207. [`packages/game_mafia/lib/tablet/screens/execution_view.dart`](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [execution_view.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletExecutionView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/shared/widgets/flip_card.dart](../../packages/game_mafia/lib/shared/widgets/flip_card.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)

#### 208. [`packages/game_mafia/lib/tablet/screens/game_layout.dart`](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_layout.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletBox`, `MafiaTabletBackground`, `MafiaTabletSun`, `MafiaTabletMoon`, `MafiaTabletNotice`, `MafiaTabletChrome`, `MafiaTabletHeadline`, `MafiaTabletAnnouncement`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_mafia/lib/shared/animations/ejection_text.dart](../../packages/game_mafia/lib/shared/animations/ejection_text.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/tablet/screens/day_view.dart](../../packages/game_mafia/lib/tablet/screens/day_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [packages/game_mafia/lib/tablet/screens/night_bird.dart](../../packages/game_mafia/lib/tablet/screens/night_bird.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_tablet_background_wipe_test.dart](../../test/mafia_tablet_background_wipe_test.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)

#### 209. [`packages/game_mafia/lib/tablet/providers/game_stage.dart`](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [game_stage.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletStage`, `MafiaTabletStageView`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_mafia/lib/shared/animations/announcement_reveal.dart](../../packages/game_mafia/lib/shared/animations/announcement_reveal.dart)<br>- [packages/game_mafia/lib/shared/animations/phase_transition.dart](../../packages/game_mafia/lib/shared/animations/phase_transition.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/tablet/screens/day_view.dart](../../packages/game_mafia/lib/tablet/screens/day_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)

#### 210. [`packages/game_mafia/lib/tablet/screens/night_bird.dart`](../../packages/game_mafia/lib/tablet/screens/night_bird.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [night_bird.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletNightBird`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)

#### 211. [`packages/game_mafia/lib/tablet/screens/phase_views.dart`](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [phase_views.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletRoleDealView`, `MafiaTabletNightView`, `MafiaTabletMorningView`, `MafiaTabletMorningSequence`, `MafiaTabletVoteResultSequence`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/animations/announcement_reveal.dart](../../packages/game_mafia/lib/shared/animations/announcement_reveal.dart)<br>- [packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart](../../packages/game_mafia/lib/shared/animations/role_deal_toss_animation.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/state_models.dart](../../packages/game_mafia/lib/shared/models/state_models.dart)<br>- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/screens/night_bird.dart](../../packages/game_mafia/lib/tablet/screens/night_bird.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_phase_exit_test.dart](../../test/mafia_phase_exit_test.dart)<br>- [test/mafia_role_deal_toss_test.dart](../../test/mafia_role_deal_toss_test.dart)<br>- [test/mafia_stage_notice_test.dart](../../test/mafia_stage_notice_test.dart)

#### 212. [`packages/game_mafia/lib/tablet/screens/result_view.dart`](../../packages/game_mafia/lib/tablet/screens/result_view.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [result_view.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletResultView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/widgets/result_art.dart](../../packages/game_mafia/lib/shared/widgets/result_art.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/shared/widgets/flip_card.dart](../../packages/game_mafia/lib/shared/widgets/flip_card.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)<br>- [test/mafia_result_test.dart](../../test/mafia_result_test.dart)<br>- [test/mafia_tablet_result_test.dart](../../test/mafia_tablet_result_test.dart)

#### 213. [`packages/game_mafia/lib/tablet/screens/role_setup_screen.dart`](../../packages/game_mafia/lib/tablet/screens/role_setup_screen.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [role_setup_screen.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaRoleSetupScreen`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/widgets/game_setup_back_button.dart](../../packages/game_kit/lib/widgets/game_setup_back_button.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/game_composition.dart](../../packages/game_mafia/lib/shared/models/game_composition.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [test/mafia_role_setup_test.dart](../../test/mafia_role_setup_test.dart)

#### 214. [`packages/game_mafia/lib/tablet/screens/tally_view.dart`](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [tally_view.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaTabletTallyView`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/shared/animations/progress_sound_cue.dart](../../packages/game_kit/lib/shared/animations/progress_sound_cue.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/state_models.dart](../../packages/game_mafia/lib/shared/models/state_models.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [test/mafia_ballot_animation_test.dart](../../test/mafia_ballot_animation_test.dart)<br>- [test/mafia_landscape_smoke_test.dart](../../test/mafia_landscape_smoke_test.dart)

#### 215. [`packages/game_mafia/lib/tablet/tablet_board.dart`](../../packages/game_mafia/lib/tablet/tablet_board.dart)

- 리뷰 단계: **8. 화면 조립**
- 역할: [tablet_game.dart] 는 마피아에서 사용하는 태블릿 게임 화면의 진입점과 공통 흐름을 연결하는 파일이다.
- 핵심 공개 선언: `MafiaTabletGame`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/assets/game_asset_store.dart](../../packages/game_kit/lib/core/assets/game_asset_store.dart)<br>- [packages/game_kit/lib/core/layout/app_orientation.dart](../../packages/game_kit/lib/core/layout/app_orientation.dart)<br>- [packages/game_kit/lib/core/layout/app_system_ui.dart](../../packages/game_kit/lib/core/layout/app_system_ui.dart)<br>- [packages/game_kit/lib/core/sound/sound_effects.dart](../../packages/game_kit/lib/core/sound/sound_effects.dart)<br>- [packages/game_kit/lib/core/time/server_clock.dart](../../packages/game_kit/lib/core/time/server_clock.dart)<br>- [packages/game_kit/lib/models/game_room_context.dart](../../packages/game_kit/lib/models/game_room_context.dart)<br>- [packages/game_kit/lib/player_layouts/player_layout_model.dart](../../packages/game_kit/lib/player_layouts/player_layout_model.dart)<br>- [packages/game_kit/lib/sound/countdown_tick_cue.dart](../../packages/game_kit/lib/sound/countdown_tick_cue.dart)<br>- [packages/game_kit/lib/sound/game_background_music.dart](../../packages/game_kit/lib/sound/game_background_music.dart)<br>- [packages/game_kit/lib/widgets/game_interruption_layer.dart](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)<br>- [packages/game_kit/lib/widgets/game_route_exit.dart](../../packages/game_kit/lib/widgets/game_route_exit.dart)<br>- [packages/game_kit/lib/widgets/game_turn_countdown.dart](../../packages/game_kit/lib/widgets/game_turn_countdown.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_rulebook_dialog.dart)<br>- [packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart](../../packages/game_kit/lib/widgets/tablet_game_settings_dialog.dart)<br>- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/shared/models/server_timing.dart](../../packages/game_mafia/lib/shared/models/server_timing.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)<br>- [packages/game_mafia/lib/shared/models/game_state.dart](../../packages/game_mafia/lib/shared/models/game_state.dart)<br>- [packages/game_mafia/lib/shared/providers/session_provider.dart](../../packages/game_mafia/lib/shared/providers/session_provider.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/providers/game_stage.dart](../../packages/game_mafia/lib/tablet/providers/game_stage.dart)<br>- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)<br>- [packages/game_mafia/lib/tablet/services/bgm_plan.dart](../../packages/game_mafia/lib/tablet/services/bgm_plan.dart)<br>- [packages/game_mafia/lib/tablet/services/night_cue_speaker.dart](../../packages/game_mafia/lib/tablet/services/night_cue_speaker.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)

#### 216. [`packages/game_mafia/lib/shared/services/command_service.dart`](../../packages/game_mafia/lib/shared/services/command_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [command_service.dart] 는 마피아에서 사용하는 서버의 게임 상태를 변경하는 명령을 모아둔 파일이다.
- 핵심 공개 선언: `MafiaCommandService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)<br>- [test/mafia_interruption_finish_now_test.dart](../../test/mafia_interruption_finish_now_test.dart)<br>- [test/mafia_room_gone_test.dart](../../test/mafia_room_gone_test.dart)

#### 217. [`packages/game_mafia/lib/shared/services/query_service.dart`](../../packages/game_mafia/lib/shared/services/query_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [query_service.dart] 는 마피아에서 사용하는 서버의 게임 상태를 조회하고 해석하는 파일이다.
- 핵심 공개 선언: `MafiaQueryService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/services/game_service.dart](../../packages/game_mafia/lib/shared/services/game_service.dart)<br>- [test/mafia_interruption_finish_now_test.dart](../../test/mafia_interruption_finish_now_test.dart)<br>- [test/mafia_room_gone_test.dart](../../test/mafia_room_gone_test.dart)

#### 218. [`packages/game_mafia/lib/shared/services/game_service.dart`](../../packages/game_mafia/lib/shared/services/game_service.dart)

- 리뷰 단계: **6. 서버 통신**
- 역할: [game_service.dart] 는 마피아에서 사용하는 게임의 조회·명령 서비스를 묶어 제공하는 파일이다.
- 핵심 공개 선언: `MafiaService`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/services/game_interruption_command_service.dart](../../packages/game_kit/lib/services/game_interruption_command_service.dart)<br>- [packages/game_mafia/lib/shared/services/command_service.dart](../../packages/game_mafia/lib/shared/services/command_service.dart)<br>- [packages/game_mafia/lib/shared/services/query_service.dart](../../packages/game_mafia/lib/shared/services/query_service.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/providers/game_controller.dart](../../packages/game_mafia/lib/shared/providers/game_controller.dart)<br>- [packages/game_mafia/lib/game_mafia.dart](../../packages/game_mafia/lib/game_mafia.dart)<br>- [packages/game_mafia/lib/shared/providers/session_provider.dart](../../packages/game_mafia/lib/shared/providers/session_provider.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_interruption_finish_now_test.dart](../../test/mafia_interruption_finish_now_test.dart)<br>- [test/mafia_room_gone_test.dart](../../test/mafia_room_gone_test.dart)

#### 219. [`packages/game_mafia/lib/tablet/services/bgm_plan.dart`](../../packages/game_mafia/lib/tablet/services/bgm_plan.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [bgm_plan.dart] 는 마피아에서 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_background_music_test.dart](../../test/mafia_background_music_test.dart)

#### 220. [`packages/game_mafia/lib/tablet/services/night_cue_speaker.dart`](../../packages/game_mafia/lib/tablet/services/night_cue_speaker.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [night_cue_speaker.dart] 는 마피아에서 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
- 핵심 공개 선언: `MafiaNightCueSpeaker`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/models/state_models.dart](../../packages/game_mafia/lib/shared/models/state_models.dart)<br>- [packages/game_mafia/lib/game_sounds.dart](../../packages/game_mafia/lib/game_sounds.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [test/mafia_night_cue_test.dart](../../test/mafia_night_cue_test.dart)

#### 221. [`packages/game_mafia/lib/game_sounds.dart`](../../packages/game_mafia/lib/game_sounds.dart)

- 리뷰 단계: **10. 연출·사운드**
- 역할: [game_sounds.dart] 는 마피아에서 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
- 핵심 공개 선언: 공개 타입 선언 없음 — top-level 함수·상수 또는 export 진입점
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/sound/app_sounds.dart](../../packages/game_kit/lib/core/sound/app_sounds.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/shared/services/asset_preloader.dart](../../packages/game_mafia/lib/shared/services/asset_preloader.dart)<br>- [packages/game_mafia/lib/tablet/screens/game_layout.dart](../../packages/game_mafia/lib/tablet/screens/game_layout.dart)<br>- [packages/game_mafia/lib/tablet/screens/phase_views.dart](../../packages/game_mafia/lib/tablet/screens/phase_views.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/tablet/tablet_board.dart](../../packages/game_mafia/lib/tablet/tablet_board.dart)<br>- [packages/game_mafia/lib/tablet/services/bgm_plan.dart](../../packages/game_mafia/lib/tablet/services/bgm_plan.dart)<br>- [packages/game_mafia/lib/tablet/services/night_cue_speaker.dart](../../packages/game_mafia/lib/tablet/services/night_cue_speaker.dart)<br>- [test/mafia_background_music_test.dart](../../test/mafia_background_music_test.dart)<br>- [test/mafia_night_cue_test.dart](../../test/mafia_night_cue_test.dart)<br>- [test/narration_sounds_test.dart](../../test/narration_sounds_test.dart)

#### 222. [`packages/game_mafia/lib/shared/widgets/flip_card.dart`](../../packages/game_mafia/lib/shared/widgets/flip_card.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [flip_card.dart] 는 마피아에서 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
- 핵심 공개 선언: `MafiaFlipCard`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/result_view.dart](../../packages/game_mafia/lib/tablet/screens/result_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/role_card_layer.dart](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)<br>- [test/mafia_role_card_layer_test.dart](../../test/mafia_role_card_layer_test.dart)<br>- [test/mafia_tablet_result_test.dart](../../test/mafia_tablet_result_test.dart)

#### 223. [`packages/game_mafia/lib/phone/widgets/day_discussion_view.dart`](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [day_discussion_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaDayDiscussionView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [test/mafia_day_discussion_test.dart](../../test/mafia_day_discussion_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_phase_transition_test.dart](../../test/mafia_phase_transition_test.dart)

#### 224. [`packages/game_mafia/lib/phone/widgets/execution_view.dart`](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [execution_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaExecutionResultView`, `MafiaExecutionRevealView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/widgets/flip_card.dart](../../packages/game_mafia/lib/shared/widgets/flip_card.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)

#### 225. [`packages/game_mafia/lib/phone/widgets/game_layout.dart`](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [game_layout.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaPhoneAnnouncement`, `MafiaTileGridSpec`, `MafiaPhoneActionButton`, `MafiaPhoneShellChrome`, `MafiaStoredRoleCard`, `MafiaPhoneBackground`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/animations/ejection_text.dart](../../packages/game_mafia/lib/shared/animations/ejection_text.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [packages/game_mafia/lib/phone/widgets/day_discussion_view.dart](../../packages/game_mafia/lib/phone/widgets/day_discussion_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/night_action_view.dart](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_view.dart](../../packages/game_mafia/lib/phone/widgets/result_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/role_card_layer.dart](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/vote_view.dart](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)<br>- [test/mafia_day_discussion_test.dart](../../test/mafia_day_discussion_test.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)<br>- [test/mafia_phase_exit_test.dart](../../test/mafia_phase_exit_test.dart)<br>- [test/mafia_phase_transition_test.dart](../../test/mafia_phase_transition_test.dart)<br>- [test/mafia_phone_layout_center_test.dart](../../test/mafia_phone_layout_center_test.dart)<br>- [test/mafia_player_select_grid_test.dart](../../test/mafia_player_select_grid_test.dart)

#### 226. [`packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart`](../../packages/game_mafia/lib/phone/widgets/morning_announcement_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [morning_announcement_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaMorningAnnouncementView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/state_models.dart](../../packages/game_mafia/lib/shared/models/state_models.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)

#### 227. [`packages/game_mafia/lib/phone/widgets/night_action_view.dart`](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [night_action_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaNightInvestigationResult`, `MafiaNightActionView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/models/role_catalog.dart](../../packages/game_mafia/lib/shared/models/role_catalog.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [test/mafia_investigation_result_test.dart](../../test/mafia_investigation_result_test.dart)<br>- [test/mafia_new_role_views_test.dart](../../test/mafia_new_role_views_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_phase_exit_test.dart](../../test/mafia_phase_exit_test.dart)

#### 228. [`packages/game_mafia/lib/phone/widgets/player_select_grid.dart`](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [player_select_grid.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaPlayerSelectGrid`, `MafiaProfileImage`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/core/constants/room_character.dart](../../packages/game_kit/lib/core/constants/room_character.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/tablet/screens/execution_view.dart](../../packages/game_mafia/lib/tablet/screens/execution_view.dart)<br>- [packages/game_mafia/lib/tablet/screens/tally_view.dart](../../packages/game_mafia/lib/tablet/screens/tally_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/execution_view.dart](../../packages/game_mafia/lib/phone/widgets/execution_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/night_action_view.dart](../../packages/game_mafia/lib/phone/widgets/night_action_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/vote_view.dart](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)<br>- [test/mafia_ballot_animation_test.dart](../../test/mafia_ballot_animation_test.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)<br>- [test/mafia_phone_layout_center_test.dart](../../test/mafia_phone_layout_center_test.dart)<br>- [test/mafia_player_select_grid_test.dart](../../test/mafia_player_select_grid_test.dart)<br>- [test/mafia_vote_submit_animation_test.dart](../../test/mafia_vote_submit_animation_test.dart)

#### 229. [`packages/game_mafia/lib/phone/widgets/result_sequence.dart`](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [result_sequence.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaPhoneResultSequence`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/animations/announcement_reveal.dart](../../packages/game_mafia/lib/shared/animations/announcement_reveal.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_view.dart](../../packages/game_mafia/lib/phone/widgets/result_view.dart)<br>- [packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)<br>- [test/mafia_result_test.dart](../../test/mafia_result_test.dart)

#### 230. [`packages/game_mafia/lib/phone/widgets/result_view.dart`](../../packages/game_mafia/lib/phone/widgets/result_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [result_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaResultView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/widgets/result_art.dart](../../packages/game_mafia/lib/shared/widgets/result_art.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/widgets/result_sequence.dart](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)<br>- [test/mafia_result_test.dart](../../test/mafia_result_test.dart)

#### 231. [`packages/game_mafia/lib/phone/widgets/role_card_layer.dart`](../../packages/game_mafia/lib/phone/widgets/role_card_layer.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [role_card_layer.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaPhoneRoleCardLayer`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/shared/widgets/flip_card.dart](../../packages/game_mafia/lib/shared/widgets/flip_card.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [test/mafia_new_role_views_test.dart](../../test/mafia_new_role_views_test.dart)<br>- [test/mafia_role_card_layer_test.dart](../../test/mafia_role_card_layer_test.dart)

#### 232. [`packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart`](../../packages/game_mafia/lib/phone/widgets/spectator_roster_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [spectator_roster_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaRevealedPlayer`, `MafiaSpectatorRosterView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [packages/game_mafia/lib/phone/widgets/result_sequence.dart](../../packages/game_mafia/lib/phone/widgets/result_sequence.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)

#### 233. [`packages/game_mafia/lib/phone/widgets/top_bar.dart`](../../packages/game_mafia/lib/phone/widgets/top_bar.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [top_bar.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaPhoneTopBar`
- 이 파일이 직접 참조:
- [packages/game_kit/lib/widgets/phone_game_top_bar.dart](../../packages/game_kit/lib/widgets/phone_game_top_bar.dart)<br>- [packages/game_kit/lib/widgets/phone_ripple_dialog.dart](../../packages/game_kit/lib/widgets/phone_ripple_dialog.dart)<br>- [packages/game_kit/lib/widgets/phone_rule_dialog.dart](../../packages/game_kit/lib/widgets/phone_rule_dialog.dart)<br>- [packages/game_mafia/lib/game_assets.dart](../../packages/game_mafia/lib/game_assets.dart)<br>- [packages/game_mafia/lib/gen/assets.gen.dart](../../packages/game_mafia/lib/gen/assets.gen.dart)<br>- [packages/game_mafia/lib/game_copy.dart](../../packages/game_mafia/lib/game_copy.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/phone_board.dart](../../packages/game_mafia/lib/phone/phone_board.dart)

#### 234. [`packages/game_mafia/lib/phone/widgets/vote_view.dart`](../../packages/game_mafia/lib/phone/widgets/vote_view.dart)

- 리뷰 단계: **9. 세부 UI**
- 역할: [vote_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
- 핵심 공개 선언: `MafiaVoteView`
- 이 파일이 직접 참조:
- [packages/game_mafia/lib/shared/animations/ballot_animations.dart](../../packages/game_mafia/lib/shared/animations/ballot_animations.dart)<br>- [packages/game_mafia/lib/shared/models/player.dart](../../packages/game_mafia/lib/shared/models/player.dart)<br>- [packages/game_mafia/lib/shared/models/role.dart](../../packages/game_mafia/lib/shared/models/role.dart)<br>- [packages/game_mafia/lib/phone/widgets/game_layout.dart](../../packages/game_mafia/lib/phone/widgets/game_layout.dart)<br>- [packages/game_mafia/lib/phone/widgets/player_select_grid.dart](../../packages/game_mafia/lib/phone/widgets/player_select_grid.dart)
- 이 파일을 직접 참조:
- [packages/game_mafia/lib/phone/screens/game_screen.dart](../../packages/game_mafia/lib/phone/screens/game_screen.dart)<br>- [test/mafia_day_phase_views_test.dart](../../test/mafia_day_phase_views_test.dart)<br>- [test/mafia_new_role_views_test.dart](../../test/mafia_new_role_views_test.dart)<br>- [test/mafia_night_rules_test.dart](../../test/mafia_night_rules_test.dart)<br>- [test/mafia_vote_submit_animation_test.dart](../../test/mafia_vote_submit_animation_test.dart)

## 7. 게임 관련 Cloud Functions

클라이언트 command service가 문자열로 호출하므로 Dart import 역참조에는 나타나지 않는다. `functions/src/index.ts`의 export 이름과 각 `<game>_command_service.dart`의 callable 이름을 반드시 함께 비교한다.

#### F1. [`functions/src/index.ts`](../../functions/src/index.ts)

- 역할: 배포할 callable·trigger를 한곳에서 export하는 Cloud Functions 진입점이다.
- 핵심 export: 공개 선언 없음 — side-effect/재export 여부 확인
- 이 파일이 직접 참조:
- [functions/src/auth/check-email.ts](../../functions/src/auth/check-email.ts)<br>- [functions/src/auth/cleanup-incomplete-accounts.ts](../../functions/src/auth/cleanup-incomplete-accounts.ts)<br>- [functions/src/auth/delete-account.ts](../../functions/src/auth/delete-account.ts)<br>- [functions/src/auth/onboarding.ts](../../functions/src/auth/onboarding.ts)<br>- [functions/src/auth/register-profile.ts](../../functions/src/auth/register-profile.ts)<br>- [functions/src/auth/sync-apple-profile.ts](../../functions/src/auth/sync-apple-profile.ts)<br>- [functions/src/auth/sync-google-profile.ts](../../functions/src/auth/sync-google-profile.ts)<br>- [functions/src/final-call/call.ts](../../functions/src/final-call/call.ts)<br>- [functions/src/final-call/clear-game.ts](../../functions/src/final-call/clear-game.ts)<br>- [functions/src/final-call/complete-dealing.ts](../../functions/src/final-call/complete-dealing.ts)<br>- [functions/src/final-call/complete-result-reveal.ts](../../functions/src/final-call/complete-result-reveal.ts)<br>- [functions/src/final-call/complete-turn.ts](../../functions/src/final-call/complete-turn.ts)<br>- [functions/src/final-call/draw-card.ts](../../functions/src/final-call/draw-card.ts)<br>- [functions/src/final-call/end-game.ts](../../functions/src/final-call/end-game.ts)<br>- [functions/src/final-call/leave-game.ts](../../functions/src/final-call/leave-game.ts)<br>- [functions/src/final-call/next-round.ts](../../functions/src/final-call/next-round.ts)<br>- [functions/src/final-call/start-game.ts](../../functions/src/final-call/start-game.ts)<br>- [functions/src/final-call/submit-final-hand.ts](../../functions/src/final-call/submit-final-hand.ts)<br>- [functions/src/final-call/timeout-turn.ts](../../functions/src/final-call/timeout-turn.ts)<br>- [functions/src/game-interruption/controller-presence.ts](../../functions/src/game-interruption/controller-presence.ts)<br>- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now.ts](../../functions/src/game-interruption/finish-now.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/src/liars-poker/call-liar.ts](../../functions/src/liars-poker/call-liar.ts)<br>- [functions/src/liars-poker/complete-dealing.ts](../../functions/src/liars-poker/complete-dealing.ts)<br>- [functions/src/liars-poker/end-game.ts](../../functions/src/liars-poker/end-game.ts)<br>- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/src/liars-poker/force-timeout.ts](../../functions/src/liars-poker/force-timeout.ts)<br>- [functions/src/liars-poker/leave-game.ts](../../functions/src/liars-poker/leave-game.ts)<br>- [functions/src/liars-poker/pass-challenge.ts](../../functions/src/liars-poker/pass-challenge.ts)<br>- [functions/src/liars-poker/ready-turn.ts](../../functions/src/liars-poker/ready-turn.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/src/liars-poker/submit-card.ts](../../functions/src/liars-poker/submit-card.ts)<br>- [functions/src/mafia/day.ts](../../functions/src/mafia/day.ts)<br>- [functions/src/mafia/end-game.ts](../../functions/src/mafia/end-game.ts)<br>- [functions/src/mafia/morning.ts](../../functions/src/mafia/morning.ts)<br>- [functions/src/mafia/night.ts](../../functions/src/mafia/night.ts)<br>- [functions/src/mafia/role-reveal.ts](../../functions/src/mafia/role-reveal.ts)<br>- [functions/src/mafia/start-game.ts](../../functions/src/mafia/start-game.ts)<br>- [functions/src/mafia/vote.ts](../../functions/src/mafia/vote.ts)<br>- [functions/src/room/realtime-room-functions.ts](../../functions/src/room/realtime-room-functions.ts)<br>- [functions/src/room/realtime-room-lifecycle.ts](../../functions/src/room/realtime-room-lifecycle.ts)
- 이 파일을 직접 참조:
- Functions/tests 내부 import 없음

#### F2. [`functions/src/common/start-game-transaction.ts`](../../functions/src/common/start-game-transaction.ts)

- 역할: 서버 transaction 안에서 게임 시작 조건을 검증하고 초기 상태를 만든다.
- 핵심 export: `startGameFingerprint`, `assertStartGameSnapshot`
- 이 파일이 직접 참조:
- Functions 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [functions/src/final-call/start-game.ts](../../functions/src/final-call/start-game.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/src/mafia/start-game.ts](../../functions/src/mafia/start-game.ts)<br>- [functions/test/start-game-transaction.test.mjs](../../functions/test/start-game-transaction.test.mjs)

#### F3. [`functions/src/game-interruption/controller-presence.ts`](../../functions/src/game-interruption/controller-presence.ts)

- 역할: controller-presence에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `ControllerPauseOutcome`, `applyControllerPauseToTurnTimer`, `reconcileControllerConnection`, `game_common_controller_presence_changed`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)<br>- [functions/src/room/room-transaction.ts](../../functions/src/room/room-transaction.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)<br>- [functions/test/controller-presence-timer.test.mjs](../../functions/test/controller-presence-timer.test.mjs)

#### F4. [`functions/src/game-interruption/expire-resolution.ts`](../../functions/src/game-interruption/expire-resolution.ts)

- 역할: 제한 시간 만료나 강제 진행 상황을 서버에서 판정하고 처리한다.
- 핵심 export: `InterruptionExpiryOutcome`, `InterruptionExpiryResult`, `resolveExpiredInterruption`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/test/game-interruption-expire-resolution.test.mjs](../../functions/test/game-interruption-expire-resolution.test.mjs)

#### F5. [`functions/src/game-interruption/expire-scheduler.ts`](../../functions/src/game-interruption/expire-scheduler.ts)

- 역할: 제한 시간 만료나 강제 진행 상황을 서버에서 판정하고 처리한다.
- 핵심 export: `cleanupExpiredGameInterruptions`, `cleanupGhostRoomPlayers`
- 이 파일이 직접 참조:
- [functions/src/final-call/exclude-player.ts](../../functions/src/final-call/exclude-player.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/game-interruption/expire-resolution.ts](../../functions/src/game-interruption/expire-resolution.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/exclude-player.ts](../../functions/src/liars-poker/exclude-player.ts)<br>- [functions/src/mafia/exclude-player.ts](../../functions/src/mafia/exclude-player.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/room/ghost-player-policy.ts](../../functions/src/room/ghost-player-policy.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F6. [`functions/src/game-interruption/finish-now-resolution.ts`](../../functions/src/game-interruption/finish-now-resolution.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `FinishNowRoom`, `FinishNowInput`, `supportsInsufficientPlayerFinish`, `finishGameForInsufficientPlayers`, `resolveInterruptionFinishNow`
- 이 파일이 직접 참조:
- [functions/src/final-call/exclude-player.ts](../../functions/src/final-call/exclude-player.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)<br>- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/exclude-player.ts](../../functions/src/liars-poker/exclude-player.ts)<br>- [functions/src/mafia/exclude-player.ts](../../functions/src/mafia/exclude-player.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/room/controller-session.ts](../../functions/src/room/controller-session.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-resolution.ts](../../functions/src/game-interruption/expire-resolution.ts)<br>- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now.ts](../../functions/src/game-interruption/finish-now.ts)<br>- [functions/test/game-interruption-finish-now.test.mjs](../../functions/test/game-interruption-finish-now.test.mjs)

#### F7. [`functions/src/game-interruption/finish-now.ts`](../../functions/src/game-interruption/finish-now.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `game_common_interruption_finish_now`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F8. [`functions/src/game-interruption/functions.ts`](../../functions/src/game-interruption/functions.ts)

- 역할: 게임 중단 관련 callable·trigger 구현을 묶는다.
- 핵심 export: `game_common_interruption_report_stale_player`, `game_common_interruption_vote_to_continue`, `game_common_interruption_exclude_player`, `game_common_interruption_expire`, `game_common_interruption_on_connection_changed`
- 이 파일이 직접 참조:
- [functions/src/final-call/exclude-player.ts](../../functions/src/final-call/exclude-player.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/game-interruption/expire-resolution.ts](../../functions/src/game-interruption/expire-resolution.ts)<br>- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)<br>- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/exclude-player.ts](../../functions/src/liars-poker/exclude-player.ts)<br>- [functions/src/mafia/exclude-player.ts](../../functions/src/mafia/exclude-player.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/room/controller-session.ts](../../functions/src/room/controller-session.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F9. [`functions/src/game-interruption/state.ts`](../../functions/src/game-interruption/state.ts)

- 역할: 게임 중단 상태를 읽고 갱신하는 공통 서버 로직이다.
- 핵심 export: `GAME_INTERRUPTION_VOTE_MS`, `PLAYER_HEARTBEAT_STALE_MS`, `InterruptibleRoom`, `StalePlayerResult`, `disconnectStaleGamePlayer`, `reconcileGamePlayerConnection`, `beginGameInterruption`, `cancelGameInterruption`, `completeGameInterruption`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)
- 이 파일을 직접 참조:
- [functions/src/final-call/leave-game.ts](../../functions/src/final-call/leave-game.ts)<br>- [functions/src/game-interruption/expire-resolution.ts](../../functions/src/game-interruption/expire-resolution.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/src/liars-poker/leave-game.ts](../../functions/src/liars-poker/leave-game.ts)<br>- [functions/src/mafia/end-game.ts](../../functions/src/mafia/end-game.ts)<br>- [functions/src/room/realtime-room-functions.ts](../../functions/src/room/realtime-room-functions.ts)<br>- [functions/test/controller-presence-timer.test.mjs](../../functions/test/controller-presence-timer.test.mjs)<br>- [functions/test/game-interruption-expire-resolution.test.mjs](../../functions/test/game-interruption-expire-resolution.test.mjs)<br>- [functions/test/game-interruption-finish-now.test.mjs](../../functions/test/game-interruption-finish-now.test.mjs)<br>- [functions/test/game-interruption.test.mjs](../../functions/test/game-interruption.test.mjs)

#### F10. [`functions/src/game-interruption/types.ts`](../../functions/src/game-interruption/types.ts)

- 역할: 서버 게임 상태와 명령 payload 타입을 정의한다.
- 핵심 export: `GameInterruptionReason`, `PublicGameInterruption`, `ServerGameInterruption`, `InterruptiblePublicGameState`, `ServerControllerPause`, `InterruptibleServerGameState`, `InterruptibleGameState`
- 이 파일이 직접 참조:
- Functions 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/game-interruption/controller-presence.ts](../../functions/src/game-interruption/controller-presence.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)

#### F11. [`functions/src/liars-poker/call-liar.ts`](../../functions/src/liars-poker/call-liar.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_liars_poker_call_liar`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/commands.ts](../../functions/src/liars-poker/common/commands.ts)<br>- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F12. [`functions/src/liars-poker/common/commands.ts`](../../functions/src/liars-poker/common/commands.ts)

- 역할: command ID, 멱등 처리와 공통 명령 보조 로직을 제공한다.
- 핵심 export: `processedResult`, `recordCommand`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/call-liar.ts](../../functions/src/liars-poker/call-liar.ts)<br>- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/src/liars-poker/pass-challenge.ts](../../functions/src/liars-poker/pass-challenge.ts)<br>- [functions/src/liars-poker/ready-turn.ts](../../functions/src/liars-poker/ready-turn.ts)<br>- [functions/src/liars-poker/submit-card.ts](../../functions/src/liars-poker/submit-card.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)

#### F13. [`functions/src/liars-poker/common/deal-card.ts`](../../functions/src/liars-poker/common/deal-card.ts)

- 역할: deal-card에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `dealCards`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)

#### F14. [`functions/src/liars-poker/common/deck.ts`](../../functions/src/liars-poker/common/deck.ts)

- 역할: deck에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `createDeck`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)

#### F15. [`functions/src/liars-poker/common/next-turn.ts`](../../functions/src/liars-poker/common/next-turn.ts)

- 역할: next-turn에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `findNextAlivePlayer`, `countPlayersWithCards`, `findNextPlayerWithCards`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/call-liar.ts](../../functions/src/liars-poker/call-liar.ts)<br>- [functions/src/liars-poker/exclude-player.ts](../../functions/src/liars-poker/exclude-player.ts)<br>- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/src/liars-poker/forced-timeout-resolution.ts](../../functions/src/liars-poker/forced-timeout-resolution.ts)<br>- [functions/src/liars-poker/pass-challenge.ts](../../functions/src/liars-poker/pass-challenge.ts)<br>- [functions/src/liars-poker/submit-card.ts](../../functions/src/liars-poker/submit-card.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)<br>- [functions/test/liars-poker-turn-order.test.mjs](../../functions/test/liars-poker-turn-order.test.mjs)

#### F16. [`functions/src/liars-poker/common/table.ts`](../../functions/src/liars-poker/common/table.ts)

- 역할: table에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `Table`, `createTable`
- 이 파일이 직접 참조:
- Functions 내부 직접 의존 없음
- 이 파일을 직접 참조:
- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)

#### F17. [`functions/src/liars-poker/common/types.ts`](../../functions/src/liars-poker/common/types.ts)

- 역할: 서버 게임 상태와 명령 payload 타입을 정의한다.
- 핵심 export: `CARD_RANKS`, `CardRank`, `TURN_DURATION_MS`, `LAST_CARD_CHALLENGE_DURATION_MS`, `GameCard`, `PublicGamePlayer`, `PublicLastPlay`, `PublicPenaltyResult`, `PublicGameState`, `PrivatePlayerState`, `ProcessedCommand`, `ServerGameState`, `LiarsPokerGameState`, `RealtimeRoom`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/src/liars-poker/call-liar.ts](../../functions/src/liars-poker/call-liar.ts)<br>- [functions/src/liars-poker/common/commands.ts](../../functions/src/liars-poker/common/commands.ts)<br>- [functions/src/liars-poker/common/deal-card.ts](../../functions/src/liars-poker/common/deal-card.ts)<br>- [functions/src/liars-poker/common/deck.ts](../../functions/src/liars-poker/common/deck.ts)<br>- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)<br>- [functions/src/liars-poker/complete-dealing.ts](../../functions/src/liars-poker/complete-dealing.ts)<br>- [functions/src/liars-poker/end-game.ts](../../functions/src/liars-poker/end-game.ts)<br>- [functions/src/liars-poker/exclude-player.ts](../../functions/src/liars-poker/exclude-player.ts)<br>- [functions/src/liars-poker/finish-game.ts](../../functions/src/liars-poker/finish-game.ts)<br>- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/src/liars-poker/force-timeout.ts](../../functions/src/liars-poker/force-timeout.ts)<br>- [functions/src/liars-poker/forced-timeout-resolution.ts](../../functions/src/liars-poker/forced-timeout-resolution.ts)<br>- [functions/src/liars-poker/leave-game.ts](../../functions/src/liars-poker/leave-game.ts)<br>- [functions/src/liars-poker/pass-challenge.ts](../../functions/src/liars-poker/pass-challenge.ts)<br>- [functions/src/liars-poker/ready-turn.ts](../../functions/src/liars-poker/ready-turn.ts)<br>- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/src/liars-poker/submit-card.ts](../../functions/src/liars-poker/submit-card.ts)

#### F18. [`functions/src/liars-poker/common/validator.ts`](../../functions/src/liars-poker/common/validator.ts)

- 역할: 서버가 상태·입력·권한을 검사하는 검증 함수 모음이다.
- 핵심 export: `REGION`, `requireUid`, `parseRoomCode`, `parseCommandId`, `parseCardIds`, `requireGame`, `assertController`, `assertRoomExists`, `assertGameExists`, `assertPlayerExists`, `assertPlayerAlive`, `assertPlayerTurn`, `assertGameStatus`, `assertCardsNotEmpty`, `assertCardCount`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/room/controller-session.ts](../../functions/src/room/controller-session.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/call-liar.ts](../../functions/src/liars-poker/call-liar.ts)<br>- [functions/src/liars-poker/complete-dealing.ts](../../functions/src/liars-poker/complete-dealing.ts)<br>- [functions/src/liars-poker/end-game.ts](../../functions/src/liars-poker/end-game.ts)<br>- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/src/liars-poker/force-timeout.ts](../../functions/src/liars-poker/force-timeout.ts)<br>- [functions/src/liars-poker/leave-game.ts](../../functions/src/liars-poker/leave-game.ts)<br>- [functions/src/liars-poker/pass-challenge.ts](../../functions/src/liars-poker/pass-challenge.ts)<br>- [functions/src/liars-poker/ready-turn.ts](../../functions/src/liars-poker/ready-turn.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/src/liars-poker/submit-card.ts](../../functions/src/liars-poker/submit-card.ts)

#### F19. [`functions/src/liars-poker/complete-dealing.ts`](../../functions/src/liars-poker/complete-dealing.ts)

- 역할: 해당 연출/턴 단계가 끝났다는 클라이언트 명령을 검증해 다음 서버 상태로 전환한다.
- 핵심 export: `game_liars_poker_complete_dealing`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F20. [`functions/src/liars-poker/end-game.ts`](../../functions/src/liars-poker/end-game.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `game_liars_poker_end_game`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F21. [`functions/src/liars-poker/exclude-player.ts`](../../functions/src/liars-poker/exclude-player.ts)

- 역할: 게임 중 참가자 퇴장·제외를 서버 상태에 안전하게 반영한다.
- 핵심 export: `excludeLiarsPokerPlayer`, `finishLiarsPokerForInsufficientPlayers`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/test/liars-poker-turn-order.test.mjs](../../functions/test/liars-poker-turn-order.test.mjs)

#### F22. [`functions/src/liars-poker/finish-game.ts`](../../functions/src/liars-poker/finish-game.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `finishGame`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)

#### F23. [`functions/src/liars-poker/finish-penalty.ts`](../../functions/src/liars-poker/finish-penalty.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `game_liars_poker_prepare_penalty`, `game_liars_poker_resolve_penalty`, `drawPenaltyResult`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/commands.ts](../../functions/src/liars-poker/common/commands.ts)<br>- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)<br>- [functions/src/liars-poker/finish-game.ts](../../functions/src/liars-poker/finish-game.ts)<br>- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)

#### F24. [`functions/src/liars-poker/force-timeout.ts`](../../functions/src/liars-poker/force-timeout.ts)

- 역할: 제한 시간 만료나 강제 진행 상황을 서버에서 판정하고 처리한다.
- 핵심 export: `game_liars_poker_force_timeout`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)<br>- [functions/src/liars-poker/forced-timeout-resolution.ts](../../functions/src/liars-poker/forced-timeout-resolution.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F25. [`functions/src/liars-poker/forced-timeout-resolution.ts`](../../functions/src/liars-poker/forced-timeout-resolution.ts)

- 역할: 제한 시간 만료나 강제 진행 상황을 서버에서 판정하고 처리한다.
- 핵심 export: `resolveForcedTimeout`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/force-timeout.ts](../../functions/src/liars-poker/force-timeout.ts)<br>- [functions/test/liars-poker-forced-timeout.test.mjs](../../functions/test/liars-poker-forced-timeout.test.mjs)

#### F26. [`functions/src/liars-poker/leave-game.ts`](../../functions/src/liars-poker/leave-game.ts)

- 역할: 게임 중 참가자 퇴장·제외를 서버 상태에 안전하게 반영한다.
- 핵심 export: `game_liars_poker_leave_game`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F27. [`functions/src/liars-poker/pass-challenge.ts`](../../functions/src/liars-poker/pass-challenge.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_liars_poker_pass_challenge`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/commands.ts](../../functions/src/liars-poker/common/commands.ts)<br>- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F28. [`functions/src/liars-poker/ready-turn.ts`](../../functions/src/liars-poker/ready-turn.ts)

- 역할: ready-turn에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `game_liars_poker_ready_turn`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/commands.ts](../../functions/src/liars-poker/common/commands.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F29. [`functions/src/liars-poker/restart-round.ts`](../../functions/src/liars-poker/restart-round.ts)

- 역할: restart-round에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `CARDS_PER_PLAYER`, `restartRound`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/deal-card.ts](../../functions/src/liars-poker/common/deal-card.ts)<br>- [functions/src/liars-poker/common/deck.ts](../../functions/src/liars-poker/common/deck.ts)<br>- [functions/src/liars-poker/common/table.ts](../../functions/src/liars-poker/common/table.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)
- 이 파일을 직접 참조:
- [functions/src/liars-poker/exclude-player.ts](../../functions/src/liars-poker/exclude-player.ts)<br>- [functions/src/liars-poker/finish-penalty.ts](../../functions/src/liars-poker/finish-penalty.ts)<br>- [functions/src/liars-poker/forced-timeout-resolution.ts](../../functions/src/liars-poker/forced-timeout-resolution.ts)<br>- [functions/src/liars-poker/start-game.ts](../../functions/src/liars-poker/start-game.ts)<br>- [functions/src/liars-poker/submit-card.ts](../../functions/src/liars-poker/submit-card.ts)<br>- [functions/test/liars-poker-common.test.mjs](../../functions/test/liars-poker-common.test.mjs)

#### F30. [`functions/src/liars-poker/start-game.ts`](../../functions/src/liars-poker/start-game.ts)

- 역할: 서버 transaction 안에서 게임 시작 조건을 검증하고 초기 상태를 만든다.
- 핵심 export: `game_liars_poker_start_game`
- 이 파일이 직접 참조:
- [functions/src/common/start-game-transaction.ts](../../functions/src/common/start-game-transaction.ts)<br>- [functions/src/liars-poker/common/deal-card.ts](../../functions/src/liars-poker/common/deal-card.ts)<br>- [functions/src/liars-poker/common/deck.ts](../../functions/src/liars-poker/common/deck.ts)<br>- [functions/src/liars-poker/common/table.ts](../../functions/src/liars-poker/common/table.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)<br>- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F31. [`functions/src/liars-poker/submit-card.ts`](../../functions/src/liars-poker/submit-card.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_liars_poker_submit_cards`
- 이 파일이 직접 참조:
- [functions/src/liars-poker/common/commands.ts](../../functions/src/liars-poker/common/commands.ts)<br>- [functions/src/liars-poker/common/next-turn.ts](../../functions/src/liars-poker/common/next-turn.ts)<br>- [functions/src/liars-poker/common/types.ts](../../functions/src/liars-poker/common/types.ts)<br>- [functions/src/liars-poker/common/validator.ts](../../functions/src/liars-poker/common/validator.ts)<br>- [functions/src/liars-poker/restart-round.ts](../../functions/src/liars-poker/restart-round.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F32. [`functions/src/final-call/call.ts`](../../functions/src/final-call/call.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_final_call_declare`
- 이 파일이 직접 참조:
- [functions/src/final-call/commands.ts](../../functions/src/final-call/commands.ts)<br>- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F33. [`functions/src/final-call/clear-game.ts`](../../functions/src/final-call/clear-game.ts)

- 역할: clear-game에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `game_final_call_clear_game`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F34. [`functions/src/final-call/commands.ts`](../../functions/src/final-call/commands.ts)

- 역할: command ID, 멱등 처리와 공통 명령 보조 로직을 제공한다.
- 핵심 export: `finalCallProcessed`, `recordFinalCallCommand`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)
- 이 파일을 직접 참조:
- [functions/src/final-call/call.ts](../../functions/src/final-call/call.ts)<br>- [functions/src/final-call/complete-turn.ts](../../functions/src/final-call/complete-turn.ts)<br>- [functions/src/final-call/draw-card.ts](../../functions/src/final-call/draw-card.ts)<br>- [functions/src/final-call/submit-final-hand.ts](../../functions/src/final-call/submit-final-hand.ts)

#### F35. [`functions/src/final-call/complete-dealing.ts`](../../functions/src/final-call/complete-dealing.ts)

- 역할: 해당 연출/턴 단계가 끝났다는 클라이언트 명령을 검증해 다음 서버 상태로 전환한다.
- 핵심 export: `game_final_call_complete_dealing`
- 이 파일이 직접 참조:
- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F36. [`functions/src/final-call/complete-result-reveal.ts`](../../functions/src/final-call/complete-result-reveal.ts)

- 역할: 해당 연출/턴 단계가 끝났다는 클라이언트 명령을 검증해 다음 서버 상태로 전환한다.
- 핵심 export: `game_final_call_complete_result_reveal`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F37. [`functions/src/final-call/complete-turn.ts`](../../functions/src/final-call/complete-turn.ts)

- 역할: 해당 연출/턴 단계가 끝났다는 클라이언트 명령을 검증해 다음 서버 상태로 전환한다.
- 핵심 export: `game_final_call_complete_turn`
- 이 파일이 직접 참조:
- [functions/src/final-call/commands.ts](../../functions/src/final-call/commands.ts)<br>- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F38. [`functions/src/final-call/draw-card.ts`](../../functions/src/final-call/draw-card.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_final_call_draw_card`
- 이 파일이 직접 참조:
- [functions/src/final-call/commands.ts](../../functions/src/final-call/commands.ts)<br>- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F39. [`functions/src/final-call/end-game.ts`](../../functions/src/final-call/end-game.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `game_final_call_end_game`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F40. [`functions/src/final-call/exclude-player.ts`](../../functions/src/final-call/exclude-player.ts)

- 역할: 게임 중 참가자 퇴장·제외를 서버 상태에 안전하게 반영한다.
- 핵심 export: `excludeFinalCallPlayer`, `finishFinalCallForInsufficientPlayers`
- 이 파일이 직접 참조:
- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)

#### F41. [`functions/src/final-call/game.ts`](../../functions/src/final-call/game.ts)

- 역할: 해당 게임의 공통 상태 계산과 상태 전이 보조 로직을 제공한다.
- 핵심 export: `createFinalCallDeck`, `createFinalCallPlayers`, `prepareFinalCallRound`, `calculateFinalCallScore`, `isFinalCallFourOfAKind`, `selectBestFinalCallCombination`, `resolveFinalCallRound`, `nextFinalCallRoundStarter`, `nextFinalCallPlayer`, `orderedAlivePlayers`, `orderedPlayers`, `finalCallTeamForSeat`, `removeFinalTurnPendingPlayer`, `createInitialFinalCallGame`, `startTurn`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)
- 이 파일을 직접 참조:
- [functions/src/final-call/call.ts](../../functions/src/final-call/call.ts)<br>- [functions/src/final-call/complete-dealing.ts](../../functions/src/final-call/complete-dealing.ts)<br>- [functions/src/final-call/complete-turn.ts](../../functions/src/final-call/complete-turn.ts)<br>- [functions/src/final-call/draw-card.ts](../../functions/src/final-call/draw-card.ts)<br>- [functions/src/final-call/exclude-player.ts](../../functions/src/final-call/exclude-player.ts)<br>- [functions/src/final-call/next-round.ts](../../functions/src/final-call/next-round.ts)<br>- [functions/src/final-call/start-game.ts](../../functions/src/final-call/start-game.ts)<br>- [functions/src/final-call/submit-final-hand.ts](../../functions/src/final-call/submit-final-hand.ts)<br>- [functions/src/final-call/timeout-turn.ts](../../functions/src/final-call/timeout-turn.ts)<br>- [functions/test/final-call-game.test.mjs](../../functions/test/final-call-game.test.mjs)

#### F42. [`functions/src/final-call/leave-game.ts`](../../functions/src/final-call/leave-game.ts)

- 역할: 게임 중 참가자 퇴장·제외를 서버 상태에 안전하게 반영한다.
- 핵심 export: `game_final_call_leave_game`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)<br>- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F43. [`functions/src/final-call/next-round.ts`](../../functions/src/final-call/next-round.ts)

- 역할: next-round에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `game_final_call_start_next_round`
- 이 파일이 직접 참조:
- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F44. [`functions/src/final-call/start-game.ts`](../../functions/src/final-call/start-game.ts)

- 역할: 서버 transaction 안에서 게임 시작 조건을 검증하고 초기 상태를 만든다.
- 핵심 export: `game_final_call_start_game`
- 이 파일이 직접 참조:
- [functions/src/common/start-game-transaction.ts](../../functions/src/common/start-game-transaction.ts)<br>- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F45. [`functions/src/final-call/submit-final-hand.ts`](../../functions/src/final-call/submit-final-hand.ts)

- 역할: submit-final-hand에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `game_final_call_submit_hand`
- 이 파일이 직접 참조:
- [functions/src/final-call/commands.ts](../../functions/src/final-call/commands.ts)<br>- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F46. [`functions/src/final-call/timeout-turn.ts`](../../functions/src/final-call/timeout-turn.ts)

- 역할: 제한 시간 만료나 강제 진행 상황을 서버에서 판정하고 처리한다.
- 핵심 export: `game_final_call_timeout_turn`
- 이 파일이 직접 참조:
- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)<br>- [functions/src/room/controller-session.ts](../../functions/src/room/controller-session.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F47. [`functions/src/final-call/types.ts`](../../functions/src/final-call/types.ts)

- 역할: 서버 게임 상태와 명령 payload 타입을 정의한다.
- 핵심 export: `FINAL_CALL_TURN_MS`, `FINAL_CALL_CARDS_PER_PLAYER`, `FinalCallColor`, `FinalCallTeam`, `FinalCallCard`, `FinalCallPlayer`, `FinalCallRoundResult`, `FinalCallPublicState`, `FinalCallPrivatePlayer`, `FinalCallProcessedCommand`, `FinalCallServerState`, `FinalCallGameState`, `FinalCallRoom`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)
- 이 파일을 직접 참조:
- [functions/src/final-call/call.ts](../../functions/src/final-call/call.ts)<br>- [functions/src/final-call/clear-game.ts](../../functions/src/final-call/clear-game.ts)<br>- [functions/src/final-call/commands.ts](../../functions/src/final-call/commands.ts)<br>- [functions/src/final-call/complete-dealing.ts](../../functions/src/final-call/complete-dealing.ts)<br>- [functions/src/final-call/complete-result-reveal.ts](../../functions/src/final-call/complete-result-reveal.ts)<br>- [functions/src/final-call/complete-turn.ts](../../functions/src/final-call/complete-turn.ts)<br>- [functions/src/final-call/draw-card.ts](../../functions/src/final-call/draw-card.ts)<br>- [functions/src/final-call/end-game.ts](../../functions/src/final-call/end-game.ts)<br>- [functions/src/final-call/exclude-player.ts](../../functions/src/final-call/exclude-player.ts)<br>- [functions/src/final-call/game.ts](../../functions/src/final-call/game.ts)<br>- [functions/src/final-call/leave-game.ts](../../functions/src/final-call/leave-game.ts)<br>- [functions/src/final-call/next-round.ts](../../functions/src/final-call/next-round.ts)<br>- [functions/src/final-call/start-game.ts](../../functions/src/final-call/start-game.ts)<br>- [functions/src/final-call/submit-final-hand.ts](../../functions/src/final-call/submit-final-hand.ts)<br>- [functions/src/final-call/timeout-turn.ts](../../functions/src/final-call/timeout-turn.ts)<br>- [functions/src/final-call/validation.ts](../../functions/src/final-call/validation.ts)<br>- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)

#### F48. [`functions/src/final-call/validation.ts`](../../functions/src/final-call/validation.ts)

- 역할: 서버가 상태·입력·권한을 검사하는 검증 함수 모음이다.
- 핵심 export: `FINAL_CALL_REGION`, `finalCallUid`, `finalCallRoomCode`, `finalCallCommandId`, `requireFinalCallGame`, `assertFinalCallController`, `assertFinalCallTurn`
- 이 파일이 직접 참조:
- [functions/src/final-call/types.ts](../../functions/src/final-call/types.ts)<br>- [functions/src/room/controller-session.ts](../../functions/src/room/controller-session.ts)
- 이 파일을 직접 참조:
- [functions/src/final-call/call.ts](../../functions/src/final-call/call.ts)<br>- [functions/src/final-call/clear-game.ts](../../functions/src/final-call/clear-game.ts)<br>- [functions/src/final-call/complete-dealing.ts](../../functions/src/final-call/complete-dealing.ts)<br>- [functions/src/final-call/complete-result-reveal.ts](../../functions/src/final-call/complete-result-reveal.ts)<br>- [functions/src/final-call/complete-turn.ts](../../functions/src/final-call/complete-turn.ts)<br>- [functions/src/final-call/draw-card.ts](../../functions/src/final-call/draw-card.ts)<br>- [functions/src/final-call/end-game.ts](../../functions/src/final-call/end-game.ts)<br>- [functions/src/final-call/leave-game.ts](../../functions/src/final-call/leave-game.ts)<br>- [functions/src/final-call/next-round.ts](../../functions/src/final-call/next-round.ts)<br>- [functions/src/final-call/start-game.ts](../../functions/src/final-call/start-game.ts)<br>- [functions/src/final-call/submit-final-hand.ts](../../functions/src/final-call/submit-final-hand.ts)<br>- [functions/src/final-call/timeout-turn.ts](../../functions/src/final-call/timeout-turn.ts)

#### F49. [`functions/src/mafia/commands.ts`](../../functions/src/mafia/commands.ts)

- 역할: command ID, 멱등 처리와 공통 명령 보조 로직을 제공한다.
- 핵심 export: `mafiaProcessed`, `recordMafiaCommand`
- 이 파일이 직접 참조:
- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)
- 이 파일을 직접 참조:
- [functions/src/mafia/day.ts](../../functions/src/mafia/day.ts)<br>- [functions/src/mafia/night.ts](../../functions/src/mafia/night.ts)<br>- [functions/src/mafia/role-reveal.ts](../../functions/src/mafia/role-reveal.ts)<br>- [functions/src/mafia/vote.ts](../../functions/src/mafia/vote.ts)

#### F50. [`functions/src/mafia/day.ts`](../../functions/src/mafia/day.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_mafia_end_discussion`, `game_mafia_timeout_day`
- 이 파일이 직접 참조:
- [functions/src/mafia/commands.ts](../../functions/src/mafia/commands.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F51. [`functions/src/mafia/end-game.ts`](../../functions/src/mafia/end-game.ts)

- 역할: 게임 또는 특수 단계를 종료하고 결과 상태를 확정한다.
- 핵심 export: `game_mafia_end_game`, `game_mafia_leave_game`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/state.ts](../../functions/src/game-interruption/state.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F52. [`functions/src/mafia/exclude-player.ts`](../../functions/src/mafia/exclude-player.ts)

- 역할: 게임 중 참가자 퇴장·제외를 서버 상태에 안전하게 반영한다.
- 핵심 export: `excludeMafiaPlayer`, `finishMafiaForInsufficientPlayers`
- 이 파일이 직접 참조:
- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/test/mafia-game.test.mjs](../../functions/test/mafia-game.test.mjs)

#### F53. [`functions/src/mafia/game.ts`](../../functions/src/mafia/game.ts)

- 역할: 해당 게임의 공통 상태 계산과 상태 전이 보조 로직을 제공한다.
- 핵심 export: `createMafiaPlayers`, `orderedPlayers`, `alivePlayers`, `mafiaCompositionToUse`, `assignMafiaRoles`, `createInitialMafiaGame`, `bumpNightActionCue`, `canActInNightStage`, `nextMafiaNightStage`, `beginMafiaNightStage`, `advanceMafiaNightStage`, `beginMafiaNight`, `beginMafiaDay`, `endMafiaDayByVote`, `beginMafiaVoting`, `isMafiaVoteBanned`, `mafiaInvestigationVerdict`, `mafiaRoleDisplayName`, `recordImmediateInvestigation`, `finalizeMafiaInvestigations`, `resolveMafiaNight`, `mafiaAbilityUsesLeft`, `resolveMafiaVoting`, `killMafiaPlayer`, `MafiaOutcome`, `checkMafiaWinner`, `finishMafiaGame`, `mafiaAnnouncementEndsGame`, `advanceMafiaAfterDeaths`
- 이 파일이 직접 참조:
- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)
- 이 파일을 직접 참조:
- [functions/src/mafia/day.ts](../../functions/src/mafia/day.ts)<br>- [functions/src/mafia/end-game.ts](../../functions/src/mafia/end-game.ts)<br>- [functions/src/mafia/exclude-player.ts](../../functions/src/mafia/exclude-player.ts)<br>- [functions/src/mafia/morning.ts](../../functions/src/mafia/morning.ts)<br>- [functions/src/mafia/night.ts](../../functions/src/mafia/night.ts)<br>- [functions/src/mafia/role-reveal.ts](../../functions/src/mafia/role-reveal.ts)<br>- [functions/src/mafia/start-game.ts](../../functions/src/mafia/start-game.ts)<br>- [functions/src/mafia/vote.ts](../../functions/src/mafia/vote.ts)<br>- [functions/test/mafia-game.test.mjs](../../functions/test/mafia-game.test.mjs)<br>- [functions/test/mafia-night-stage.test.mjs](../../functions/test/mafia-night-stage.test.mjs)<br>- [functions/test/mafia-role-abilities.test.mjs](../../functions/test/mafia-role-abilities.test.mjs)

#### F54. [`functions/src/mafia/morning.ts`](../../functions/src/mafia/morning.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_mafia_complete_morning`
- 이 파일이 직접 참조:
- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F55. [`functions/src/mafia/night.ts`](../../functions/src/mafia/night.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_mafia_submit_night_action`, `game_mafia_timeout_night`
- 이 파일이 직접 참조:
- [functions/src/mafia/commands.ts](../../functions/src/mafia/commands.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F56. [`functions/src/mafia/role-reveal.ts`](../../functions/src/mafia/role-reveal.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_mafia_confirm_role`, `game_mafia_complete_role_reveal`
- 이 파일이 직접 참조:
- [functions/src/mafia/commands.ts](../../functions/src/mafia/commands.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F57. [`functions/src/mafia/roles.ts`](../../functions/src/mafia/roles.ts)

- 역할: roles에 해당하는 서버 게임 규칙과 상태 전이를 담당한다.
- 핵심 export: `MafiaServerRole`, `MAFIA_ROLES`, `MAFIA_COMPOSITION`, `MAFIA_MIN_PLAYERS`, `MAFIA_MAX_PLAYERS`, `mafiaRole`, `actsAtNight`, `actsInBlockStage`, `mafiaCompositionFor`
- 이 파일이 직접 참조:
- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)
- 이 파일을 직접 참조:
- [functions/src/mafia/end-game.ts](../../functions/src/mafia/end-game.ts)<br>- [functions/src/mafia/exclude-player.ts](../../functions/src/mafia/exclude-player.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/night.ts](../../functions/src/mafia/night.ts)<br>- [functions/src/mafia/start-game.ts](../../functions/src/mafia/start-game.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)<br>- [functions/test/mafia-game.test.mjs](../../functions/test/mafia-game.test.mjs)<br>- [functions/test/mafia-role-parity.test.mjs](../../functions/test/mafia-role-parity.test.mjs)

#### F58. [`functions/src/mafia/start-game.ts`](../../functions/src/mafia/start-game.ts)

- 역할: 서버 transaction 안에서 게임 시작 조건을 검증하고 초기 상태를 만든다.
- 핵심 export: `game_mafia_start_game`
- 이 파일이 직접 참조:
- [functions/src/common/start-game-transaction.ts](../../functions/src/common/start-game-transaction.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

#### F59. [`functions/src/mafia/types.ts`](../../functions/src/mafia/types.ts)

- 역할: 서버 게임 상태와 명령 payload 타입을 정의한다.
- 핵심 export: `MAFIA_ROLE_REVEAL_MS`, `MAFIA_NIGHT_PRIORITY_MS`, `MAFIA_NIGHT_ATTACK_MS`, `MAFIA_NIGHT_SUPPORT_MS`, `MAFIA_NIGHT_WAIT_MS`, `MAFIA_NIGHT_MS`, `MafiaNightStageId`, `MafiaDayEndReasonId`, `MAFIA_DAY_SKIP_NOTICE_MS`, `mafiaDiscussionMs`, `MAFIA_VOTE_MS`, `MafiaFactionId`, `MafiaNightPhaseId`, `MafiaNightActionId`, `MafiaNightTargetScopeId`, `MafiaWinConditionId`, `MafiaInvestigationAppearanceId`, `MafiaPhase`, `MafiaPublicPlayer`, `MafiaMorningResult`, `MafiaVoteResult`, `MafiaNightActionCue`, `MafiaPublicState`, `MafiaInvestigationRecord`, `MafiaPrivatePlayer`, `MafiaProcessedCommand`, `MafiaServerState`, `MafiaGameState`, `MafiaRoom`
- 이 파일이 직접 참조:
- [functions/src/game-interruption/types.ts](../../functions/src/game-interruption/types.ts)
- 이 파일을 직접 참조:
- [functions/src/game-interruption/expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)<br>- [functions/src/game-interruption/finish-now-resolution.ts](../../functions/src/game-interruption/finish-now-resolution.ts)<br>- [functions/src/game-interruption/functions.ts](../../functions/src/game-interruption/functions.ts)<br>- [functions/src/mafia/commands.ts](../../functions/src/mafia/commands.ts)<br>- [functions/src/mafia/day.ts](../../functions/src/mafia/day.ts)<br>- [functions/src/mafia/end-game.ts](../../functions/src/mafia/end-game.ts)<br>- [functions/src/mafia/exclude-player.ts](../../functions/src/mafia/exclude-player.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/morning.ts](../../functions/src/mafia/morning.ts)<br>- [functions/src/mafia/night.ts](../../functions/src/mafia/night.ts)<br>- [functions/src/mafia/role-reveal.ts](../../functions/src/mafia/role-reveal.ts)<br>- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/start-game.ts](../../functions/src/mafia/start-game.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)<br>- [functions/src/mafia/vote.ts](../../functions/src/mafia/vote.ts)<br>- [functions/test/mafia-discussion-parity.test.mjs](../../functions/test/mafia-discussion-parity.test.mjs)<br>- [functions/test/mafia-night-stage.test.mjs](../../functions/test/mafia-night-stage.test.mjs)

#### F60. [`functions/src/mafia/validation.ts`](../../functions/src/mafia/validation.ts)

- 역할: 서버가 상태·입력·권한을 검사하는 검증 함수 모음이다.
- 핵심 export: `MAFIA_REGION`, `mafiaUid`, `mafiaRoomCode`, `mafiaCommandId`, `mafiaTargetUid`, `mafiaComposition`, `requireMafiaGame`, `assertMafiaController`, `assertMafiaPhase`, `assertMafiaAlive`
- 이 파일이 직접 참조:
- [functions/src/mafia/roles.ts](../../functions/src/mafia/roles.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/room/controller-session.ts](../../functions/src/room/controller-session.ts)
- 이 파일을 직접 참조:
- [functions/src/mafia/day.ts](../../functions/src/mafia/day.ts)<br>- [functions/src/mafia/end-game.ts](../../functions/src/mafia/end-game.ts)<br>- [functions/src/mafia/morning.ts](../../functions/src/mafia/morning.ts)<br>- [functions/src/mafia/night.ts](../../functions/src/mafia/night.ts)<br>- [functions/src/mafia/role-reveal.ts](../../functions/src/mafia/role-reveal.ts)<br>- [functions/src/mafia/start-game.ts](../../functions/src/mafia/start-game.ts)<br>- [functions/src/mafia/vote.ts](../../functions/src/mafia/vote.ts)<br>- [functions/test/mafia-game.test.mjs](../../functions/test/mafia-game.test.mjs)

#### F61. [`functions/src/mafia/vote.ts`](../../functions/src/mafia/vote.ts)

- 역할: 플레이어 행동을 검증하고 authoritative 게임 상태를 갱신하는 callable 구현이다.
- 핵심 export: `game_mafia_submit_vote`, `game_mafia_timeout_vote`, `game_mafia_complete_vote_result`
- 이 파일이 직접 참조:
- [functions/src/mafia/commands.ts](../../functions/src/mafia/commands.ts)<br>- [functions/src/mafia/game.ts](../../functions/src/mafia/game.ts)<br>- [functions/src/mafia/types.ts](../../functions/src/mafia/types.ts)<br>- [functions/src/mafia/validation.ts](../../functions/src/mafia/validation.ts)
- 이 파일을 직접 참조:
- [functions/src/index.ts](../../functions/src/index.ts)

## 8. 테스트와 비코드 파일을 보는 기준

### Flutter 테스트

- 게임/에셋/진행 테스트는 `test/`에서 파일명에 `game`, `asset`, `liars_poker`, `final_call`, `mafia`, `interruption`이 들어간 파일을 먼저 본다.
- 파일별 역참조 목록에 테스트가 표시되면 그 테스트가 해당 production 파일의 직접 회귀 계약이다.
- 패키지 경계는 `tool/check_package_boundaries.py`와 `tool/check_package_boundaries_test.py`가 검사한다.

### Functions 테스트

- `functions/test/final-call-game.test.mjs`
- `functions/test/liars-poker-common.test.mjs`, `liars-poker-forced-timeout.test.mjs`, `liars-poker-turn-order.test.mjs`
- `functions/test/mafia-*.mjs`
- `functions/test/game-interruption*.mjs`, `start-game-transaction.test.mjs`

### assets와 생성 파일

- 실제 이미지·음원은 각 `packages/<game>/assets/`가 소유한다.
- `pubspec.yaml`의 `flutter.assets`가 번들 포함 범위를 정한다.
- `lib/gen/assets.gen.dart`는 FlutterGen 결과이므로 직접 고치지 않는다.
- 각 게임의 `lib/game_assets.dart`는 생성된 `AssetGenImage`를 공통 `GameImage`로 바꾸면서 package 이름을 보존한다.
- 다운로드 에셋은 `game_kit/core/assets/`의 manifest/source/cache/store와 루트 `lib/game_assets/` 배선이 처리한다.
