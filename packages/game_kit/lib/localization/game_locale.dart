import 'dart:ui';

/// 게임 패키지가 앱의 표시 언어를 공유하기 위한 작은 locale bridge입니다.
///
/// 게임 패키지는 앱 루트의 생성된 ARB 클래스를 의존할 수 없으므로 앱 셸이 현재
/// locale을 설정하고, 각 게임의 copy 클래스가 [select]로 문구를 고릅니다.
abstract final class GameLocale {
  static Locale current = const Locale('ko');

  static bool get isKorean => current.languageCode == 'ko';
  static bool get isEnglish => current.languageCode == 'en';

  static bool get isTraditionalChinese {
    if (current.languageCode != 'zh') return false;
    final script = current.scriptCode?.toLowerCase();
    final country = current.countryCode?.toUpperCase();
    return script == 'hant' ||
        country == 'TW' ||
        country == 'HK' ||
        country == 'MO';
  }

  static String select({
    required String ko,
    required String en,
    required String zhHans,
    required String zhHant,
  }) => selectFor(current, ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

  static String selectFor(
    Locale locale, {
    required String ko,
    required String en,
    required String zhHans,
    required String zhHant,
  }) {
    if (locale.languageCode == 'ko') return ko;
    if (locale.languageCode == 'en') return en;
    if (locale.languageCode == 'zh') {
      final script = locale.scriptCode?.toLowerCase();
      final country = locale.countryCode?.toUpperCase();
      final traditional =
          script == 'hant' ||
          country == 'TW' ||
          country == 'HK' ||
          country == 'MO';
      return traditional ? zhHant : zhHans;
    }
    return en;
  }

  /// 짧은 공용 UI 문구를 현재 locale로 바꿉니다.
  ///
  /// 서버 오류 코드나 게임 상태 값은 이 메서드에 넣지 않고, 화면에 그리는
  /// 마지막 단계에서만 사용합니다. 등록되지 않은 값은 원문을 유지합니다.
  static String localize(String korean) {
    final values = _commonUiCopy[korean];
    if (values == null || isKorean) return korean;
    if (isEnglish) return values.$1;
    return isTraditionalChinese ? values.$3 : values.$2;
  }
}

extension GameLocaleString on String {
  String get localized => GameLocale.localize(this);
}

const _commonUiCopy = <String, (String, String, String)>{
  '뒤로': ('Back', '返回', '返回'),
  '뒤로가기': ('Back', '返回', '返回'),
  '돌아가기': ('Go back', '返回', '返回'),
  '닫기': ('Close', '关闭', '關閉'),
  '확인': ('Confirm', '确认', '確認'),
  '취소': ('Cancel', '取消', '取消'),
  '적용': ('Apply', '应用', '套用'),
  '다음': ('Next', '下一步', '下一步'),
  '이전': ('Previous', '上一步', '上一步'),
  '알겠어요': ('Got it', '知道了', '知道了'),
  '다시 시도': ('Try again', '重试', '重試'),
  '계속하기': ('Continue', '继续', '繼續'),
  '나가기': ('Leave', '离开', '離開'),
  '홈으로': ('Go home', '返回首页', '返回首頁'),
  '다시 연결하는 중': ('Reconnecting', '正在重新连接', '正在重新連線'),
  '자동으로 다시 연결하는 중': ('Reconnecting automatically', '正在自动重连', '正在自動重新連線'),
  '인터넷 연결을 기다리는 중': ('Waiting for internet', '等待网络连接', '等待網路連線'),
  '네트워크 연결 재시도': ('Retry network connection', '重试网络连接', '重試網路連線'),
  '더 놀래요': ('Keep playing', '继续玩', '繼續玩'),
  '나중에': ('Later', '稍后', '稍後'),
  '나': ('Me', '我', '我'),
  '참여자': ('Players', '参与者', '參與者'),
  '아직 참가자가 없습니다.': ('No players yet.', '暂无参与者。', '暫無參與者。'),
  '아직 참여자가 없습니다.': ('No players yet.', '暂无参与者。', '暫無參與者。'),
  '연결 끊김': ('Disconnected', '连接断开', '連線中斷'),
  '그룹 참여하기': ('Join room', '加入房间', '加入房間'),
  '입장하기': ('Enter', '进入', '進入'),
  '입장하는 중…': ('Entering…', '正在进入…', '正在進入…'),
  '수정': ('Done', '完成', '完成'),
  '캐릭터 선택': ('Choose a character', '选择角色', '選擇角色'),
  '랜덤 선택': ('Random', '随机选择', '隨機選擇'),
  '방 코드 입력': ('Enter room code', '输入房间码', '輸入房間碼'),
  '어느 방에 들어갈까요?': ('Which room will you join?', '要加入哪个房间？', '要加入哪個房間？'),
  '태블릿 화면에 보이는 다섯 글자예요': (
    'Enter the five characters shown on the tablet',
    '输入平板上显示的五个字符',
    '輸入平板上顯示的五個字元',
  ),
  '태블릿에 뜬 QR을 네모 안에 비춰 주세요': (
    'Place the tablet QR code inside the frame',
    '将平板上的二维码对准方框',
    '將平板上的 QR Code 對準方框',
  ),
  '또는 방 코드 입력': ('Or enter a room code', '或输入房间码', '或輸入房間碼'),
  'QR 옆 ROOM 아래 글자': (
    'Characters below ROOM next to the QR code',
    '二维码旁 ROOM 下方的字符',
    'QR Code 旁 ROOM 下方的字元',
  ),
  'QR로 찍기': ('Scan QR', '扫描二维码', '掃描 QR Code'),
  '칸을 누르면 키보드가 올라와요': (
    'Tap the boxes to open the keyboard',
    '点击方框打开键盘',
    '點擊方框開啟鍵盤',
  ),
  '입력 완료': ('Done', '输入完成', '輸入完成'),
  '그룹 나가기': ('Leave room', '离开房间', '離開房間'),
  '그룹 나가고 홈으로': ('Leave room and go home', '离开房间并返回首页', '離開房間並返回首頁'),
  '게임과 그룹 나가기': ('Leave game and room', '离开游戏和房间', '離開遊戲和房間'),
  '태블릿 연결 끊김': ('Tablet disconnected', '平板连接断开', '平板連線中斷'),
  '태블릿에 다시 연결하는 중': ('Reconnecting to the tablet', '正在重新连接平板', '正在重新連線平板'),
  '진행 중인 게임': ('Active game', '进行中的游戏', '進行中的遊戲'),
  '참여 중인 그룹': ('Joined room', '已加入的房间', '已加入的房間'),
  '게임 진행 중': ('Game in progress', '游戏进行中', '遊戲進行中'),
  '그룹 참여 중': ('Room joined', '已加入房间', '已加入房間'),
  '진행 중인 게임이 있어요': ('You have an active game', '你有进行中的游戏', '你有進行中的遊戲'),
  '참여 중인 그룹이 있어요': ('You are still in a room', '你仍在一个房间中', '你仍在一個房間中'),
  '그룹으로 돌아가시겠어요?': ('Return to the room?', '要返回房间吗？', '要返回房間嗎？'),
  '게임 다시 참여': ('Rejoin game', '重新加入游戏', '重新加入遊戲'),
  '그룹 다시 참여': ('Rejoin room', '重新加入房间', '重新加入房間'),
  '이렇게 플레이해요': ('How to play', '玩法说明', '玩法說明'),
  '태블릿을 테이블 가운데에': ('Place the tablet in the middle', '将平板放在桌子中央', '將平板放在桌子中央'),
  '태블릿은 가로로 놓아 주세요.': ('Place the tablet horizontally.', '请横放平板。', '請橫放平板。'),
  '휴대폰으로 참여 코드 입력': (
    'Enter the join code on each phone',
    '用手机输入加入码',
    '用手機輸入加入碼',
  ),
  '휴대폰은 각자 손에 들고 있어요.': (
    'Each player keeps their phone.',
    '每位玩家拿着自己的手机。',
    '每位玩家拿著自己的手機。',
  ),
  '태블릿을 둘러싸고 앉기': ('Sit around the tablet', '围坐在平板周围', '圍坐在平板周圍'),
  '자리는 화면에서 끌어 바꿀 수 있어요.': (
    'Drag players on screen to change seats.',
    '可在屏幕上拖动玩家调整座位。',
    '可在畫面上拖曳玩家調整座位。',
  ),
  '함께 보는 화면 + 나만 보는 화면': (
    'Shared screen + private screen',
    '共享画面 + 私人画面',
    '共享畫面 + 私人畫面',
  ),
  '휴대폰 화면은 옆 사람에게 보이지 않게!': (
    'Keep your phone hidden from nearby players!',
    '不要让旁边的人看到手机画面！',
    '不要讓旁邊的人看到手機畫面！',
  ),
  '게임 파일을 다운로드하지 못했습니다.': (
    'Could not download the game files.',
    '无法下载游戏文件。',
    '無法下載遊戲檔案。',
  ),
  '진행 중인 게임을 열려면 앱을 업데이트해 주세요.': (
    'Update the app to open the active game.',
    '请更新应用以打开进行中的游戏。',
    '請更新 App 以開啟進行中的遊戲。',
  ),
  '게임이 끝났어요': ('The game is over', '游戏结束了', '遊戲結束了'),
  '태블릿에서 게임을\n고르는 중이에요': (
    'Choosing a game\non the tablet',
    '正在平板上\n选择游戏',
    '正在平板上\n選擇遊戲',
  ),
  '태블릿에서 다음 게임을 고르는 중입니다': (
    'Choosing the next game on the tablet',
    '正在平板上选择下一款游戏',
    '正在平板上選擇下一款遊戲',
  ),
  '고르면 이 화면이 바로 바뀌어요': (
    'This screen updates as soon as a game is chosen',
    '选择后此画面会立即更新',
    '選擇後此畫面會立即更新',
  ),
  '그룹이 보유 중인 게임': ('Games owned by the room', '房间拥有的游戏', '房間擁有的遊戲'),
  '게임 규칙 열기': ('Open game rules', '打开游戏规则', '開啟遊戲規則'),
  '게임 설정 열기': ('Open game settings', '打开游戏设置', '開啟遊戲設定'),
  '게임 규칙': ('Game rules', '游戏规则', '遊戲規則'),
  '다 읽었어요': ('Done', '已读完', '已讀完'),
  '설정': ('Settings', '设置', '設定'),
  '게임 재시작': ('Restart game', '重新开始游戏', '重新開始遊戲'),
  '게임 종료': ('End game', '结束游戏', '結束遊戲'),
  '게임을 종료하지 못했습니다.': ('Could not end the game.', '无法结束游戏。', '無法結束遊戲。'),
  '게임을 열 수 없습니다.': ('Could not open the game.', '无法打开游戏。', '無法開啟遊戲。'),
  '인원 부족으로 게임을 종료합니다': (
    'The game is ending because there are too few players',
    '人数不足，游戏即将结束',
    '人數不足，遊戲即將結束',
  ),
  '계속 진행 동의를 얻지 못해 게임을 종료합니다': (
    'The game is ending because consent to continue was not received',
    '未获得继续游戏的同意，游戏即将结束',
    '未獲得繼續遊戲的同意，遊戲即將結束',
  ),
  '게임이 종료되었습니다.': ('The game has ended.', '游戏已结束。', '遊戲已結束。'),
  '게임에 참여하려면 사용자 인증이 필요합니다.': (
    'Sign-in is required to join the game.',
    '加入游戏需要用户认证。',
    '加入遊戲需要使用者驗證。',
  ),
  '게임에서 퇴장하지 못했습니다.': ('Could not leave the game.', '无法退出游戏。', '無法退出遊戲。'),
  '게임 준비를 기다리는 중...': (
    'Waiting for the game to be ready...',
    '正在等待游戏准备...',
    '正在等待遊戲準備...',
  ),
  '참가자가 변경되어 자리 배치를 다시 진행해주세요.': (
    'The player list changed. Please arrange the seats again.',
    '参与者已变更，请重新安排座位。',
    '參與者已變更，請重新安排座位。',
  ),
  '다시하기': ('Play again', '再玩一次', '再玩一次'),
  '한 판 더': ('Play again', '再玩一局', '再玩一局'),
  '로비로': ('Back to lobby', '返回大厅', '返回大廳'),
  '승리': ('Victory', '胜利', '勝利'),
  '패배': ('Defeat', '失败', '失敗'),
  '플레이어': ('Player', '玩家', '玩家'),
  '후보': ('Candidate', '候选人', '候選人'),
  '알 수 없음': ('Unknown', '未知', '未知'),
  '관전 중': ('Spectating', '观战中', '觀戰中'),
  '신분 정보': ('Role information', '身份信息', '身分資訊'),
  '모든 신분': ('All roles', '所有身份', '所有身分'),
  '내 신분 카드': ('My role card', '我的身份牌', '我的身分牌'),
  '내 신분 확인하기': ('View my role', '查看我的身份', '查看我的身分'),
  '눌러서 내 신분 보기': ('Tap to view your role', '点击查看自己的身份', '點擊查看自己的身分'),
  '당신의 신분': ('Your role', '你的身份', '你的身分'),
  '확인했습니다': ('I understand', '已确认', '已確認'),
  '다른 사람에게 보여주지 마세요': ('Do not show anyone else', '请勿向其他人展示', '請勿向其他人展示'),
  '살아 있는 사람에게 화면을 보여주지 마세요': (
    'Do not show this screen to living players',
    '请勿向存活玩家展示此画面',
    '請勿向存活玩家展示此畫面',
  ),
  '신분 공개': ('Reveal role', '公开身份', '公開身分'),
  '신분 공개까지': ('Until role reveal', '距离身份公开', '距離身分公開'),
  '처형 확정': ('Execution confirmed', '确认处决', '確認處決'),
  '처형': ('Executed', '处决', '處決'),
  '사망': ('Died', '死亡', '死亡'),
  '오늘의 처형': ('Today’s execution', '今日处决', '今日處決'),
  '처 형': ('EXECUTE', '处决', '處決'),
  '공 개': ('REVEAL', '公开', '公開'),
  '득표': ('Votes', '得票', '得票'),
  '기권': ('Abstain', '弃权', '棄權'),
  '개표': ('Counting votes', '计票', '計票'),
  '아침이 밝았다': ('Morning has come', '天亮了', '天亮了'),
  '어젯밤 사망': ('Died last night', '昨夜死亡', '昨夜死亡'),
  '잠시 후 토론을 시작합니다': ('Discussion begins shortly', '即将开始讨论', '即將開始討論'),
  '투표 중': ('Voting', '投票中', '投票中'),
  '투표 완료': ('Vote submitted', '投票完成', '投票完成'),
  '고민 중…': ('Thinking…', '思考中…', '思考中…'),
  '확인 완료': ('Confirmed', '已确认', '已確認'),
  '확인 중…': ('Checking…', '确认中…', '確認中…'),
  '신분 카드를 나눠드립니다': ('Dealing role cards', '正在发身份牌', '正在發身分牌'),
  '밤이 찾아왔다': ('Night has fallen', '夜幕降临', '夜幕降臨'),
  '밤이 지나가고 있습니다': ('The night is passing', '夜晚正在流逝', '夜晚正在流逝'),
  '취재 결과 발표': ('Reporter result', '记者调查结果', '記者調查結果'),
  '최후 변론': ('Final defense', '最终辩护', '最終辯護'),
  '처형 찬반 투표': ('Execution vote', '处决表决', '處決表決'),
  '마지막으로 변론해 주세요': ('Make your final defense', '请作最后辩护', '請作最後辯護'),
  '변론을 들어 주세요': ('Listen to the defense', '请听取辩护', '請聽取辯護'),
  '투표권자 과반수가 찬성하면 처형됩니다': (
    'Execution requires a majority of eligible voters',
    '超过半数有投票权者赞成即处决',
    '超過半數有投票權者贊成即處決',
  ),
  '투표를 기다리고 있습니다': ('Waiting for votes', '等待投票', '等待投票'),
  '처형 찬성': ('Approve execution', '赞成处决', '贊成處決'),
  '처형 반대': ('Reject execution', '反对处决', '反對處決'),
  '처형 부결': ('Execution rejected', '处决未通过', '處決未通過'),
  '처형 가결': ('Execution approved', '处决通过', '處決通過'),
  '연결 확인 중…': ('Checking connection…', '正在检查连接…', '正在檢查連線…'),
  '나만 볼 수 있는 정보': ('Private information', '仅自己可见的信息', '僅自己可見的資訊'),
  '개표합니다': ('Counting votes', '正在计票', '正在計票'),
  '누가 누구를 찍었는지는 비밀입니다': ('Each vote remains secret', '投票对象将保密', '投票對象將保密'),
  '아무도 처형되지 않았습니다.': ('Nobody was executed.', '无人被处决。', '無人被處決。'),
  '토론을 시작합니다': ('Discussion begins', '开始讨论', '開始討論'),
  '조사 결과': ('Investigation result', '调查结果', '調查結果'),
  '다른 플레이어의 행동을 기다리는 중…': (
    'Waiting for other players…',
    '正在等待其他玩家…',
    '正在等待其他玩家…',
  ),
  '선택 완료': ('Confirm selection', '确认选择', '確認選擇'),
  '이 결과는 나만 볼 수 있어요': (
    'Only you can see this result',
    '只有你能看到此结果',
    '只有你能看到此結果',
  ),
  '선택을 완료했습니다': ('Selection submitted', '选择已提交', '選擇已提交'),
  '곧 아침이 옵니다': ('Morning is almost here', '马上天亮', '馬上天亮'),
  '조용히 밤을 보내세요': ('Wait quietly through the night', '请安静等待天亮', '請安靜等待天亮'),
  '아침까지': ('Until morning', '距离天亮', '距離天亮'),
  '지목': ('Choose', '指定', '指定'),
  '누구를 지목했는지는 공개되지 않습니다': (
    'Your choice remains secret',
    '你的选择不会公开',
    '你的選擇不會公開',
  ),
  '연결됨': ('Connected', '已连接', '已連線'),
  '강퇴': ('Remove', '移除', '移除'),
  '전체': ('Master', '全部', '全部'),
  '효과': ('Effects', '音效', '音效'),
  '배경': ('Music', '背景音乐', '背景音樂'),
  '소리 다시 켜기': ('Turn sound on', '开启声音', '開啟聲音'),
  '모두 음소거': ('Mute all', '全部静音', '全部靜音'),
  '카드 확인': ('View cards', '查看卡牌', '查看卡牌'),
  '카드를 눌러 펼쳐 보세요': ('Tap the cards to open', '点击卡牌展开', '點擊卡牌展開'),
  '이 방에 대한 권한이 없습니다. 방 상태를 다시 확인해주세요.': (
    'You do not have access to this room. Check the room status.',
    '你没有此房间的访问权限。请检查房间状态。',
    '你沒有此房間的存取權限。請檢查房間狀態。',
  ),
  '방을 찾을 수 없습니다.': ('Room not found.', '找不到房间。', '找不到房間。'),
  '방 인원이 가득 찼습니다.': ('The room is full.', '房间已满。', '房間已滿。'),
  '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.': (
    'The request could not be completed. Try again shortly.',
    '无法处理请求。请稍后重试。',
    '無法處理要求。請稍後重試。',
  ),
  '게임을 시작하지 못했습니다. 연결을 확인하고 다시 눌러 주세요.': (
    'Could not start the game. Check the connection and try again.',
    '无法开始游戏。请检查连接后重试。',
    '無法開始遊戲。請檢查連線後重試。',
  ),
  '나가기를 처리하지 못했습니다. 다시 눌러 주세요.': (
    'Could not leave. Please try again.',
    '无法退出。请重试。',
    '無法退出。請重試。',
  ),
  '인터넷 연결 끊김': ('No internet connection', '网络连接断开', '網路連線中斷'),
  '인터넷 연결이 끊겼어요': ('Internet connection lost', '网络连接已断开', '網路連線已中斷'),
  '와이파이나 모바일 데이터를 확인해 주세요.': (
    'Check Wi-Fi or mobile data.',
    '请检查 Wi-Fi 或移动数据。',
    '請檢查 Wi-Fi 或行動數據。',
  ),
  '다시 연결하기': ('Reconnect', '重新连接', '重新連線'),
  '30초 더 기다리기': ('Wait 30 more seconds', '再等待 30 秒', '再等待 30 秒'),
  '제외하고 계속하기': ('Remove and continue', '移除后继续', '移除後繼續'),
  '종료 확인': ('Confirm end', '确认结束', '確認結束'),
  '계속 기다리기': ('Keep waiting', '继续等待', '繼續等待'),
  '대기실': ('Lobby', '大厅', '大廳'),
  '대기실로': ('Back to lobby', '返回大厅', '返回大廳'),
  '섞기': ('Shuffle', '随机排列', '隨機排列'),
  '이전 자리': ('Last seats', '上次座位', '上次座位'),
  '설정 완료': ('Finish setup', '完成设置', '完成設定'),
  '곧 나올 게임': ('Coming soon', '即将推出', '即將推出'),
  '새 게임 소식은 상점에서 확인해 주세요. 알림 신청은 준비 중이에요.': (
    'Check the store for new game announcements. Notifications are coming soon.',
    '请在商店查看新游戏消息，通知功能即将推出。',
    '請在商店查看新遊戲消息，通知功能即將推出。',
  ),
  '입고\n예정': ('COMING\nSOON', '即将\n上架', '即將\n上架'),
  '마피아': ('Mafia', '黑手党', '黑手黨'),
  '오늘 밤, 이 테이블 누군가는\n거짓말을 하고 있다.': (
    'Tonight, someone at this table\nis lying.',
    '今晚，这张桌上有人\n正在说谎。',
    '今晚，這張桌上有人\n正在說謊。',
  ),
  '밤에는 휴대폰으로 몰래 능력을 쓰고, 낮에는 토론한 뒤 비밀 투표로 한 명을 골라요. 사회는 태블릿이 봐요.': (
    'Use secret abilities on your phone at night, then discuss and vote in secret by day. The tablet runs the game.',
    '夜晚用手机秘密发动能力，白天讨论后秘密投票。平板负责主持游戏。',
    '夜晚用手機秘密發動能力，白天討論後秘密投票。平板負責主持遊戲。',
  ),
  '4–12명': ('4–12 players', '4–12人', '4–12人'),
  '역할 43종': ('43 roles', '43种身份', '43種身分'),
  '태블릿 사회자': ('Tablet host', '平板主持', '平板主持'),
  '예고편 음악은 준비 중이에요.': (
    'Trailer music is coming soon.',
    '预告片音乐即将推出。',
    '預告片音樂即將推出。',
  ),
  '밤에는 마피아가, 낮에는 시민이 움직여요. 태블릿이 사회자가 돼요.': (
    'Mafia acts at night and citizens act by day. The tablet hosts the game.',
    '黑手党夜间行动，市民白天行动，由平板主持游戏。',
    '黑手黨夜間行動，市民白天行動，由平板主持遊戲。',
  ),
  '구성품 · 역할 카드 43종': ('Contents · 43 role cards', '内容 · 43种身份牌', '內容 · 43種身分牌'),
  '시민': ('Citizen', '市民', '市民'),
  '경찰': ('Detective', '警察', '警察'),
  '의사': ('Doctor', '医生', '醫生'),
  '스파이': ('Spy', '间谍', '間諜'),
  '광대': ('Jester', '小丑', '小丑'),
  '시민 19 · 마피아 15 · 중립 9 · 비밀 투표 · 밤낮 진행': (
    '19 Citizen · 15 Mafia · 9 Neutral · Secret votes · Day and night',
    '市民19 · 黑手党15 · 中立9 · 秘密投票 · 昼夜进行',
    '市民19 · 黑手黨15 · 中立9 · 秘密投票 · 晝夜進行',
  ),
  '구매·복원 기능은 준비 중이에요': (
    'Purchase and restore are coming soon',
    '购买与恢复功能即将推出',
    '購買與恢復功能即將推出',
  ),
  '배경 음악 · 재생 중': ('Background music · Playing', '背景音乐 · 播放中', '背景音樂 · 播放中'),
  '배경 음악 · 준비 중': (
    'Background music · Coming soon',
    '背景音乐 · 即将推出',
    '背景音樂 · 即將推出',
  ),
  '밤의 골목 · 마피아 테마': ('Night Alley · Mafia theme', '夜巷 · 黑手党主题', '夜巷 · 黑手黨主題'),
  '밤이 되었습니다': ('Night has fallen', '夜幕降临', '夜幕降臨'),
  '"모두 고개를 숙여 주세요."': (
    '“Everyone, lower your heads.”',
    '“请所有人低下头。”',
    '「請所有人低下頭。」',
  ),
  '마피아 · 나만 보여요': ('Mafia · Private', '黑手党 · 仅自己可见', '黑手黨 · 僅自己可見'),
  '누구를 고를까요?': ('Who will you choose?', '选择谁？', '選擇誰？'),
  '"내 역할은 내 휴대폰에만."': (
    '“My role stays on my phone.”',
    '“我的身份只显示在我的手机上。”',
    '「我的身分只顯示在我的手機上。」',
  ),
  '아침이 밝았어요': ('Morning has come', '天亮了', '天亮了'),
  '"자, 누가 거짓말을 하고 있죠?"': ('“So, who is lying?”', '“那么，谁在说谎？”', '「那麼，誰在說謊？」'),
  '사라': ('Sarah', '莎拉', '莎拉'),
  '민준': ('Minjun', '敏俊', '敏俊'),
  '하린': ('Harin', '夏琳', '夏琳'),
  '지우': ('Jiwoo', '智友', '智友'),
  '도윤': ('Doyun', '道允', '道允'),
  '"과연, 하린은 마피아였을까요?"': (
    '“Was Harin really Mafia?”',
    '“夏琳真的是黑手党吗？”',
    '「夏琳真的是黑手黨嗎？」',
  ),
  '진행 중': ('In progress', '进行中', '進行中'),
  '로그인 상태 확인': ('Checking sign-in', '检查登录状态', '檢查登入狀態'),
  '이메일 링크 처리': ('Processing email link', '处理邮箱链接', '處理電子郵件連結'),
  '회원가입 상태 확인': ('Checking sign-up status', '检查注册状态', '檢查註冊狀態'),
  '계정 상태 복구': ('Restoring account status', '恢复账号状态', '恢復帳號狀態'),
  '로그아웃': ('Log out', '退出登录', '登出'),
  '이메일 인증': ('Verify email', '验证邮箱', '驗證電子郵件'),
  '비밀번호': ('Password', '密码', '密碼'),
  '프로필': ('Profile', '个人资料', '個人資料'),
  '이메일': ('Email', '邮箱', '電子郵件'),
  '도메인 목록': ('Domain list', '域名列表', '網域列表'),
  '직접 입력': ('Enter manually', '手动输入', '手動輸入'),
  '중단하기': ('Stop', '暂停', '暫停'),
  '약관 동의': ('Terms', '同意条款', '同意條款'),
  '계정 만들기': ('Create account', '创建账号', '建立帳號'),
  '전체 동의': ('Agree to all', '全部同意', '全部同意'),
  '필수': ('Required', '必选', '必選'),
  '선택': ('Optional', '可选', '選填'),
  '또는': ('or', '或', '或'),
  '규칙': ('Rules', '规则', '規則'),
  '내 자리': ('My seat', '我的座位', '我的座位'),
  '돌아오기를 기다리는 중': ('Waiting for return', '等待返回', '等待返回'),
  '게임에 다시 접속하는 중': ('Reconnecting to the game', '正在重新连接游戏', '正在重新連線遊戲'),
  '잠시만 기다려 주세요': ('Please wait a moment', '请稍候', '請稍候'),
  '업데이트를 받는 중': ('Downloading update', '正在下载更新', '正在下載更新'),
  '나중에 하기': ('Later', '稍后', '稍後'),
  '업데이트를 마쳤어요': ('Update downloaded', '更新下载完成', '更新下載完成'),
  '앱을 다시 켜면 적용됩니다': (
    'Restart the app to apply it',
    '重新启动应用后生效',
    '重新啟動 App 後生效',
  ),
  '서버 응답을 기다리고 있습니다…': ('Waiting for the server…', '正在等待服务器响应…', '正在等待伺服器回應…'),
  '게임을 잠시 멈췄어요. 연결과 화면 준비를 기다리고 있어요.': (
    'The game is paused while connection and screens recover.',
    '游戏已暂停，正在等待连接与画面恢复。',
    '遊戲已暫停，正在等待連線與畫面恢復。',
  ),
  '연결이 끊겼어요': ('Connection lost', '连接已断开', '連線已中斷'),
  '다시 연결하는 중…': ('Reconnecting…', '正在重新连接…', '正在重新連線…'),
  '다시 연결됐어요': ('Reconnected', '已重新连接', '已重新連線'),
  '구성품': ('Components', '组件', '配件'),
  '이렇게 해요': ('How to play', '玩法', '玩法'),
  '카드': ('Cards', '卡牌', '卡牌'),
  '인원별 카드': ('Cards by player count', '按人数配牌', '按人數配牌'),
  '벌칙 룰렛': ('Penalty roulette', '惩罚轮盘', '懲罰輪盤'),
  '버튼': ('Buttons', '按钮', '按鈕'),
  '카드 내기': ('Play cards', '出牌', '出牌'),
  '기준 카드(A·K·Q)라며 1~3장을 뒷면으로 내요.': (
    'Claim A, K, or Q and play 1–3 cards face down.',
    '声称是 A、K 或 Q，背面朝上打出 1–3 张牌。',
    '聲稱是 A、K 或 Q，背面朝上打出 1–3 張牌。',
  ),
  '거짓말 같으면 외쳐요. 틀린 쪽이 룰렛을 돌려요.': (
    'Call it when you suspect a lie. The wrong side spins the roulette.',
    '怀疑说谎时喊出来。判断错误的一方转轮盘。',
    '懷疑說謊時喊出來。判斷錯誤的一方轉輪盤。',
  ),
  '끝까지 생존': ('Survive to the end', '生存到最后', '生存到最後'),
  '룰렛은 갈수록 불리해져요. 마지막 한 명이 승리해요.': (
    'The roulette gets harsher. The last player wins.',
    '轮盘会越来越危险，最后一人获胜。',
    '輪盤會越來越危險，最後一人獲勝。',
  ),
  '숫자 카드': ('Number cards', '数字牌', '數字牌'),
  '팀': ('Teams', '队伍', '隊伍'),
  '팀 하트': ('Team hearts', '队伍爱心', '隊伍愛心'),
  '선언': ('Declaration', '宣言', '宣言'),
  '점수': ('Score', '分数', '分數'),
  '손패 4장에서 같은 색 합과 같은 숫자 합 중 큰 쪽이에요.': (
    'Your score is the higher of matching-color and matching-number sums across four cards.',
    '4 张手牌中，同色总和与同数字总和取较大值。',
    '4 張手牌中，同色總和與同數字總和取較大值。',
  ),
  '내 차례': ('Your turn', '你的回合', '你的回合'),
  '카드 1장을 가져와 손패와 바꾸거나 그대로 버려요.': (
    'Take one card, then swap it with your hand or discard it.',
    '拿一张牌，与手牌交换或直接弃掉。',
    '拿一張牌，與手牌交換或直接棄掉。',
  ),
  '자신 있으면 선언해요. 점수가 가장 낮은 사람이 하트를 잃어요.': (
    'Declare when confident. The lowest score loses a heart.',
    '有把握时宣布。分数最低者失去一颗爱心。',
    '有把握時宣布。分數最低者失去一顆愛心。',
  ),
  '밤': ('Night', '夜晚', '夜晚'),
  '신분별로 몰래 능력을 써요. 선택은 비공개예요.': (
    'Use role abilities secretly at night. Choices stay private.',
    '夜晚秘密使用身份能力，选择不会公开。',
    '夜晚秘密使用身分能力，選擇不會公開。',
  ),
  '낮': ('Day', '白天', '白天'),
  '토론한 뒤 비밀 투표로 한 명을 처형해요.': (
    'Discuss, then secretly vote to execute one player.',
    '讨论后秘密投票处决一人。',
    '討論後秘密投票處決一人。',
  ),
  '위협을 모두 없애면 시민, 수가 따라잡으면 마피아가 이겨요.': (
    'Citizens win by removing every threat; Mafia wins when their numbers catch up.',
    '清除所有威胁则市民获胜；黑手党人数追平时黑手党获胜。',
    '清除所有威脅則市民獲勝；黑手黨人數追平時黑手黨獲勝。',
  ),
  '시작 칩': ('Starting chips', '起始筹码', '起始籌碼'),
  '카드 조합': ('Make a hand', '组成牌型', '組成牌型'),
  '내 카드 2장과 공용 카드 5장으로 가장 강한 5장을 만들어요.': (
    'Make the best five-card hand from two hole cards and five community cards.',
    '用 2 张底牌和 5 张公共牌组成最强 5 张牌。',
    '用 2 張底牌和 5 張公共牌組成最強 5 張牌。',
  ),
  '베팅': ('Betting', '下注', '下注'),
  '라운드마다 폴드·콜·레이즈 등으로 팟을 겨뤄요.': (
    'Compete for the pot with folds, calls, and raises each street.',
    '每轮通过弃牌、跟注和加注争夺底池。',
    '每輪透過棄牌、跟注和加注爭奪底池。',
  ),
  '토너먼트': ('Tournament', '锦标赛', '錦標賽'),
  '블라인드가 5판마다 두 배가 돼요. 마지막 한 명이 승리해요.': (
    'Blinds double every five hands. The last player wins.',
    '盲注每 5 手翻倍，最后一人获胜。',
    '盲注每 5 手翻倍，最後一人獲勝。',
  ),
  '카드 뒷면': ('Card back', '卡牌背面', '卡牌背面'),
  '뒷면 카드': ('Face-down card', '背面朝上的牌', '背面朝上的牌'),
};
