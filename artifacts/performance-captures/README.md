# 성능 측정 자료 보관

Release 전체 테스트의 로그·녹화 확보를 마친 뒤 Debug 측정으로 넘어간다.

자료는 이 폴더에 함께 보관해도 되지만 기존 파일을 덮어쓰지 않는다.
새 수집 자료는 다음 정보를 포함한 고유 이름으로 저장한다.

`{mode}-{test}-{game-or-na}-{device-or-bundle}-{yyyyMMdd-HHmmss-fff}-{unique-id}.{extension}`

- mode: `release` 또는 `debug`
- test: `lobby`, `game-start`, `card-submit`, `turn-transition`, 여러 항목을 연속 수집한 `game-session`
- game: 게임 식별자. 로비는 `na`
- device: `tablet`, `phone-A`, `phone-B`, 통합 보관본은 `bundle`
- 시각은 시간대와 함께 수집 manifest에도 기록한다. unique-id는 수집마다 새로 만든다.

동일 이름이 이미 존재하면 저장을 중단하고 새 이름을 만든다. 강제 덮어쓰기 옵션을
사용하지 않는다. 로그·수집 요약·해시 검증 기록은 동일 수집 ID로 연결한다.
동일 수집에 포함된 시작·제출·턴 전환은 원본을 보존하고 영상 대조 후 구간을 기록한다.
나중에 제공되는 영상도 수집 ID로 연결하며 원본을 덮어쓰지 않는다.

기존 `release-lobby-20261017-20261017-145302-380.zip`과 검증 JSON은 이름을 바꾸거나
덮어쓰지 않고 유지한다. 이 ZIP은 태블릿 1,936건과 휴대폰 A 3,160건의 정제 로그 및
수집 기록을 포함한다. 기존 manifest의 build 경로는 수집 당시 경로이며 ZIP 내부 파일은
파일명으로 찾을 수 있다.

기기 이벤트 원문·credential·token·비공개 게임 payload는 보관하지 않는다.
이 폴더는 로컬 보관본이며 외부 백업이나 Git 커밋 완료를 의미하지 않는다.
