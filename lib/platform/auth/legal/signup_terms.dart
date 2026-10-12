// [signup_terms.dart] 는 회원가입 약관 동의의 버전·동의 내용·문서 본문을 모아 둔 파일이다.
//
// - [Platform] : 회원가입(이메일·Google·Apple·게스트 공통)
// - [Legal] : 이용약관·개인정보 처리방침과 동의 기록
//
// 즉, 약관을 고칠 때 버전과 본문을 한곳에서 바꾸기 위해 필요한 파일이다.

import 'dart:convert';

import 'package:game_kit/localization/game_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 회원가입 때 보여 주는 약관 묶음의 버전입니다.
///
/// 서버 `SIGNUP_TERMS_VERSION`(functions/src/auth/onboarding-types.ts)과 같아야
/// 합니다. 약관 본문을 고치면 두 값을 함께 올립니다.
abstract final class SignupTermsVersion {
  static const current = '2026-10-12';
}

/// 회원가입 약관 동의 내용입니다.
class SignupConsents {
  const SignupConsents({
    this.age14 = false,
    this.terms = false,
    this.privacy = false,
    this.marketing = false,
  });

  /// 만 14세 이상입니다(필수).
  final bool age14;

  /// 이용약관에 동의했습니다(필수).
  final bool terms;

  /// 개인정보 수집·이용에 동의했습니다(필수).
  final bool privacy;

  /// 새 게임·이벤트 소식을 받습니다(선택).
  final bool marketing;

  bool get requiredAgreed => age14 && terms && privacy;
  bool get allAgreed => requiredAgreed && marketing;

  /// 아직 동의하지 않은 필수 항목 수입니다.
  int get requiredLeft => [age14, terms, privacy].where((on) => !on).length;

  SignupConsents copyWith({
    bool? age14,
    bool? terms,
    bool? privacy,
    bool? marketing,
  }) => SignupConsents(
    age14: age14 ?? this.age14,
    terms: terms ?? this.terms,
    privacy: privacy ?? this.privacy,
    marketing: marketing ?? this.marketing,
  );

  /// 서버 `completeOnboardingProfile`에 보내는 값입니다.
  Map<String, Object> toJson() => {
    'version': SignupTermsVersion.current,
    'age14': age14,
    'terms': terms,
    'privacy': privacy,
    'marketing': marketing,
  };
}

/// 가입을 마칠 때까지 동의 내용을 기기에 잠시 보관합니다.
///
/// 새 이메일 가입은 약관 동의 → 이메일·비밀번호 계정 생성 → 메일 인증 → 프로필
/// 순서이며, 이전 링크 가입도 이어갈 수 있습니다. 그 사이 앱이 다시 시작될 수
/// 있으므로 서버에는 가입을 마칠 때 함께
/// 보내 기록하고, 그 뒤 지웁니다. 약관 버전이 바뀌면 다시 동의받습니다.
class SignupConsentStore {
  static const _key = 'auth.signupConsents';

  Future<void> save(SignupConsents consents) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(consents.toJson()));
  }

  /// 지금 버전에 필수 항목까지 동의한 기록만 돌려줍니다.
  Future<SignupConsents?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['version'] != SignupTermsVersion.current) {
        return null;
      }
      final consents = SignupConsents(
        age14: json['age14'] == true,
        terms: json['terms'] == true,
        privacy: json['privacy'] == true,
        marketing: json['marketing'] == true,
      );
      return consents.requiredAgreed ? consents : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}

/// 약관 화면에서 펼쳐 보는 문서입니다.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.effectiveDate,
    required this.sections,
    this.intro,
    this.isDraft = false,
  });

  final String title;
  final String effectiveDate;
  final String? intro;
  final List<(String, String)> sections;

  /// 법률 검토 전 초안이면 화면에 '초안' 표시를 붙입니다.
  final bool isDraft;
}

/// 모시겜 이용약관입니다.
///
/// ⚠️ 법률 검토 전 초안입니다. 검토를 마치면 [LegalDocument.isDraft]를
/// false로 바꾸고, 본문이 바뀌었다면 [SignupTermsVersion.current]와 서버 버전을
/// 함께 올립니다.
const _termsOfServiceKo = LegalDocument(
  title: '모시겜 이용약관',
  effectiveDate: '2026-10-12',
  isDraft: true,
  intro:
      '따스한동네(이하 ‘운영자’)가 제공하는 모바일 애플리케이션 ‘모시겜’(이하 ‘서비스’)을 '
      '이용하는 데 필요한 기본 약속입니다.',
  sections: [
    (
      '제1조 목적',
      '이 약관은 운영자와 이용자 사이의 서비스 이용 조건과 절차, 권리·의무 및 책임 사항을 '
          '정합니다.',
    ),
    (
      '제2조 정의',
      '• 서비스: 태블릿과 휴대폰을 함께 써서 여러 사람이 즐기는 파티 게임 앱 ‘모시겜’과 관련 기능\n'
          '• 이용자: 이 약관에 동의하고 서비스에 가입한 사람\n'
          '• 방: 게임을 함께하기 위해 태블릿에서 만들고 휴대폰으로 참여하는 공간',
    ),
    (
      '제3조 약관의 효력과 변경',
      '이 약관은 가입 화면에서 동의한 때부터 효력이 생깁니다. 운영자는 관련 법령을 어기지 '
          '않는 범위에서 약관을 바꿀 수 있으며, 바뀌는 내용과 시행일을 시행 7일 전(이용자에게 '
          '불리한 경우 30일 전)부터 앱 또는 홈페이지에 알립니다. 바뀐 약관에 동의하지 않으면 '
          '탈퇴할 수 있습니다.',
    ),
    (
      '제4조 회원가입',
      '만 14세 이상인 사람은 이메일, Google 또는 Apple 계정으로 가입할 수 있습니다. '
          '다른 사람의 정보를 쓰거나 사실과 다른 정보로 가입하면 이용이 제한될 수 있습니다.',
    ),
    (
      '제5조 계정 관리',
      '이용자는 자신의 계정과 비밀번호를 스스로 관리해야 하며, 다른 사람에게 빌려주거나 '
          '넘길 수 없습니다. 계정이 도용된 것을 알게 되면 바로 운영자에게 알려 주세요.',
    ),
    (
      '제6조 서비스 제공',
      '운영자는 게임 방 만들기·참여, 게임 진행, 프로필 표시 등 서비스를 제공합니다. '
          '점검, 장애, 통신 사정 등으로 서비스가 잠시 멈출 수 있으며, 미리 알릴 수 있는 경우 '
          '앱에서 안내합니다.',
    ),
    (
      '제7조 이용자의 의무',
      '이용자는 다음 행동을 해서는 안 됩니다.\n'
          '• 다른 사람을 불쾌하게 하거나 욕설·혐오·차별적인 닉네임과 사진을 쓰는 행위\n'
          '• 서비스의 정상적인 운영을 방해하거나 버그·비정상적인 방법을 이용하는 행위\n'
          '• 앱을 무단으로 복제·변경·배포하거나 역설계하는 행위\n'
          '• 법령이나 공공질서에 어긋나는 행위',
    ),
    (
      '제8조 이용 제한',
      '이용자가 제7조를 어기면 운영자는 경고, 일시 정지, 탈퇴 처리 등으로 이용을 제한할 수 '
          '있습니다. 이용자는 제한에 대해 문의처로 이의를 제기할 수 있습니다.',
    ),
    (
      '제9조 유료 서비스',
      '유료 게임이나 아이템을 제공하는 경우 가격·결제·환불 조건을 구매 화면에 따로 알리며, '
          '결제와 환불은 각 앱 마켓(App Store, Google Play)의 정책을 따릅니다.',
    ),
    (
      '제10조 탈퇴',
      '이용자는 언제든 앱의 프로필 화면에서 탈퇴할 수 있습니다. 탈퇴하면 계정과 프로필 '
          '정보는 개인정보 처리방침에 따라 삭제됩니다.',
    ),
    (
      '제11조 책임의 제한',
      '운영자는 천재지변, 이용자의 기기·통신 환경, 이용자의 잘못 등 운영자에게 책임이 없는 '
          '사유로 생긴 손해에 대해서는 책임지지 않습니다. 다만 운영자의 고의나 중대한 과실로 '
          '생긴 손해는 예외로 합니다.',
    ),
    (
      '제12조 분쟁 해결',
      '서비스 이용과 관련한 분쟁은 운영자와 이용자가 성실히 협의해 해결합니다. 소송이 '
          '필요한 경우 민사소송법에 따른 관할 법원을 따릅니다.\n'
          '문의: warmhandongne@gmail.com',
    ),
  ],
);

/// 모시겜 개인정보 처리방침입니다.
///
/// 홈페이지 공개본(`public/privacy/index.html`)과 같은 내용이어야 합니다.
/// 한쪽을 고치면 다른 쪽도 함께 고칩니다.
const _privacyPolicyKo = LegalDocument(
  title: '모시겜 개인정보 처리방침',
  effectiveDate: '2026-08-31',
  intro:
      '따스한동네(이하 ‘운영자’)는 모바일 애플리케이션 ‘모시겜’(이하 ‘서비스’)을 제공하면서 '
      '이용자의 개인정보를 소중히 다루며, 「개인정보 보호법」 등 관련 법령을 준수합니다.',
  sections: [
    (
      '1. 수집하는 개인정보 항목과 수집 방법',
      '서비스는 회원가입과 게임 진행에 필요한 최소한의 정보만 수집합니다.\n'
          '• 회원가입(필수): 이메일 주소, 닉네임, 계정 식별자(UID) — 직접 입력하거나 Google·Apple 계정에서 제공\n'
          '• 기존 가입 정보: 휴대전화번호, 마케팅 수신 동의 여부 — 해당 항목을 쓰던 기존 가입 흐름에서 직접 입력\n'
          '• 프로필(선택): 프로필 사진 — 기기의 사진 라이브러리에서 직접 선택해 업로드\n'
          '• 게임 이용: 방 참여 기록, 게임 진행 상태(역할·점수·순서 등) — 이용 과정에서 자동 생성\n'
          '• 오류 진단: 앱 비정상 종료 기록, 기기 모델·운영체제 버전, 앱 버전, 계정 식별자(UID) — 오류 발생 시 자동 수집(Firebase Crashlytics)\n'
          '카메라는 방 참여용 QR 코드를 인식하는 데에만 쓰이며 촬영 영상은 저장하거나 전송하지 '
          '않습니다. 사진 라이브러리는 프로필 사진으로 고른 이미지에만 접근합니다. 두 권한은 '
          '거부할 수 있고, 거부해도 해당 기능 외의 이용에는 제한이 없습니다.',
    ),
    (
      '2. 개인정보의 처리 목적',
      '• 회원 식별 및 관리 — 가입, 로그인, 본인 확인, 중복 가입 방지\n'
          '• 서비스 제공 — 게임 방 생성·참여, 참가자 간 닉네임·프로필 표시, 게임 진행 상태 동기화\n'
          '• 문의 대응 — 이용자 문의 확인 및 회신\n'
          '• 서비스 안정화 — 오류 원인 분석 및 품질 개선\n'
          '수집한 개인정보는 위 목적을 넘어 이용하지 않으며, 광고 목적의 이용이나 이용자 '
          '행동 추적(트래킹)은 하지 않습니다.',
    ),
    (
      '3. 보유 및 이용 기간, 파기',
      '개인정보는 회원 탈퇴 시 지체 없이 파기합니다. 앱 프로필 화면의 ‘회원탈퇴’를 실행하면 '
          '계정 정보와 프로필 사진이 삭제되며 복구할 수 없습니다. 진행 중인 방에 포함된 '
          '닉네임·게임 상태는 함께 게임하던 이용자의 진행 복구를 위해 해당 방이 종료되어 자동 '
          '정리될 때까지만 남을 수 있습니다. 관계 법령에 따라 보존이 필요한 정보는 해당 기간 '
          '동안 분리해 보관합니다. 오류 진단 기록은 UID와 연결될 수 있으며 Firebase '
          'Crashlytics의 보존 기간인 최대 90일 동안 보관한 뒤 삭제됩니다.',
    ),
    (
      '4. 제3자 제공 및 처리위탁',
      '운영자는 이용자의 개인정보를 제3자에게 판매하거나 제공하지 않습니다. 서비스 운영을 '
          '위해 아래와 같이 처리를 위탁합니다.\n'
          '• Google LLC(Firebase) — 인증, 데이터베이스, 파일 저장, 서버 기능 실행, 오류 수집 / 위탁 계약 종료 또는 회원 탈퇴 시까지\n'
          '• Apple Inc. — Apple 계정 로그인 처리 / 로그인 처리 시점에 한함\n'
          '• Shorebird — 앱 코드 업데이트 확인 및 전송 / 업데이트 제공에 필요한 기간',
    ),
    (
      '5. 개인정보의 국외 이전',
      '• 이전받는 자 — Google LLC\n'
          '• 이전 국가 — 싱가포르(게임 상태 데이터베이스), 미국(인증·파일 저장·오류 수집)\n'
          '• 이전 항목 — 서비스별 처리에 필요한 제1항의 정보\n'
          '• 이전 목적 및 기간 — 제2항의 서비스 제공 목적, 회원 탈퇴 시까지\n'
          '국외 이전을 거부할 수 있으나, 서비스의 핵심 기능이 해당 인프라에 의존하므로 이 경우 '
          '서비스 이용이 불가능합니다.',
    ),
    (
      '6. 이용자의 권리와 행사 방법',
      '• 열람·수정 — 앱 프로필 화면에서 닉네임과 프로필 사진을 확인하고 변경\n'
          '• 삭제(탈퇴) — 앱 프로필 화면의 ‘회원탈퇴’ 또는 계정 삭제 안내 페이지에서 요청\n'
          '• 처리 정지 — 아래 문의처로 요청\n'
          '법정대리인을 통한 권리 행사도 가능하며, 이 경우 위임 사실을 확인할 수 있는 서류를 '
          '요청할 수 있습니다.',
    ),
    (
      '7. 만 14세 미만 아동',
      '서비스는 만 14세 미만 아동의 회원가입을 받지 않습니다. 만 14세 미만 아동의 개인정보가 '
          '수집된 사실을 확인한 경우 지체 없이 해당 정보를 파기합니다.',
    ),
    (
      '8. 안전성 확보 조치',
      '• 모든 통신은 HTTPS/TLS로 암호화해 전송합니다.\n'
          '• 비밀번호는 운영자가 보관하지 않으며, 인증은 Google·Apple 및 Firebase Authentication이 처리합니다.\n'
          '• 데이터베이스에는 접근 권한 규칙을 적용해 본인 및 같은 게임 참여자에게 필요한 범위로만 조회를 허용합니다.\n'
          '• 게임 상태 변경은 서버에서만 수행되며 이용자 기기가 직접 데이터를 바꿀 수 없습니다.',
    ),
    (
      '9. 개인정보 보호책임자 및 문의처',
      '• 책임자: 기획자 윤유원\n'
          '• 이메일: warmhandongne@gmail.com\n'
          '개인정보 침해 신고·상담은 개인정보분쟁조정위원회(1833-6972), 개인정보침해신고센터(118), '
          '대검찰청 사이버수사과(1301), 경찰청 사이버범죄 신고시스템(182)에 문의할 수 있습니다.',
    ),
    (
      '10. 방침의 변경',
      '방침이 바뀌면 시행 7일 전부터 홈페이지에 알립니다. 이용자에게 불리한 중요한 변경은 '
          '시행 30일 전에 알립니다.',
    ),
  ],
);

/// 현재 앱 언어로 표시하는 이용약관입니다.
LegalDocument get termsOfService => switch (_legalLanguage) {
  'ko' => _termsOfServiceKo,
  'zh-Hant' => _termsOfServiceZhHant,
  'zh-Hans' => _termsOfServiceZhHans,
  _ => _termsOfServiceEn,
};

/// 현재 앱 언어로 표시하는 개인정보 처리방침입니다.
LegalDocument get privacyPolicy => switch (_legalLanguage) {
  'ko' => _privacyPolicyKo,
  'zh-Hant' => _privacyPolicyZhHant,
  'zh-Hans' => _privacyPolicyZhHans,
  _ => _privacyPolicyEn,
};

String get _legalLanguage {
  if (GameLocale.isKorean) return 'ko';
  if (GameLocale.isEnglish) return 'en';
  if (GameLocale.current.languageCode == 'zh') {
    return GameLocale.isTraditionalChinese ? 'zh-Hant' : 'zh-Hans';
  }
  return 'en';
}

const _termsOfServiceEn = LegalDocument(
  title: 'Mosigame Terms of Service',
  effectiveDate: '2026-10-12',
  isDraft: true,
  intro:
      'These terms govern your use of Mosigame, a mobile application provided by Warm Neighborhood (the “Operator”).',
  sections: [
    (
      '1. Purpose',
      'These terms define the conditions and procedures for using the service and the rights, obligations, and responsibilities of the Operator and users.',
    ),
    (
      '2. Definitions',
      '• Service: Mosigame and related features for party games played together with tablets and phones\n• User: a person who accepts these terms and registers for the service\n• Room: a space created on a tablet that players join by phone',
    ),
    (
      '3. Effect and changes',
      'These terms take effect when you accept them during sign-up. The Operator may change them within applicable law and will announce changes at least 7 days in advance, or 30 days for changes unfavorable to users. You may close your account if you do not agree.',
    ),
    (
      '4. Registration',
      'Anyone age 14 or older may register using email, Google, or Apple. Use may be restricted if another person’s information or false information is used.',
    ),
    (
      '5. Account management',
      'You are responsible for your account and password and may not lend or transfer them. Notify the Operator promptly if you discover unauthorized use.',
    ),
    (
      '6. Service',
      'The Operator provides room creation and joining, game play, and profile display. Maintenance, outages, or network conditions may temporarily interrupt the service. Planned interruptions will be announced when possible.',
    ),
    (
      '7. User obligations',
      'You must not use abusive, hateful, or discriminatory names or images; disrupt normal operation or exploit bugs; copy, modify, distribute, or reverse engineer the app without permission; or violate law or public order.',
    ),
    (
      '8. Restrictions',
      'If you violate Section 7, the Operator may warn, suspend, or close your account. You may appeal through the contact address.',
    ),
    (
      '9. Paid services',
      'Prices, payment, and refund terms for paid games or items will be shown at purchase. Payments and refunds follow App Store or Google Play policies.',
    ),
    (
      '10. Account closure',
      'You may close your account from the profile screen at any time. Account and profile data will be deleted under the Privacy Policy.',
    ),
    (
      '11. Limitation of liability',
      'The Operator is not responsible for damage caused by events outside its control, including natural disasters, device or network conditions, or user fault. This does not apply to intentional misconduct or gross negligence by the Operator.',
    ),
    (
      '12. Disputes',
      'The Operator and user will first seek an amicable resolution. Any lawsuit will follow the court jurisdiction provided by Korean civil procedure law.\nContact: warmhandongne@gmail.com',
    ),
  ],
);

const _termsOfServiceZhHans = LegalDocument(
  title: 'Mosigame 使用条款',
  effectiveDate: '2026-10-12',
  isDraft: true,
  intro: '本条款规定用户使用“温暖社区”（以下简称“运营方”）提供的移动应用 Mosigame（以下简称“服务”）时应遵守的基本约定。',
  sections: [
    ('第1条 目的', '本条款规定运营方与用户之间的服务使用条件、程序、权利、义务及责任。'),
    (
      '第2条 定义',
      '• 服务：使用平板和手机供多人共同游玩的派对游戏应用 Mosigame 及相关功能\n• 用户：同意本条款并注册服务的人\n• 房间：在平板上创建、由手机加入以共同游戏的空间',
    ),
    (
      '第3条 生效与变更',
      '本条款自用户在注册页面同意时生效。运营方可在法律允许范围内修改条款，并至少提前7天公告；对用户不利的重要变更将提前30天公告。不同意时可注销账号。',
    ),
    ('第4条 注册', '年满14周岁者可使用电子邮箱、Google 或 Apple 账号注册。冒用他人信息或提交虚假信息时，使用可能受到限制。'),
    ('第5条 账号管理', '用户应自行管理账号和密码，不得出借或转让。发现账号被盗用时请立即通知运营方。'),
    ('第6条 服务提供', '运营方提供创建与加入房间、游戏进行、个人资料显示等功能。维护、故障或通信状况可能导致服务暂时中断；可预告时将提前通知。'),
    (
      '第7条 用户义务',
      '不得使用辱骂、仇恨或歧视性昵称和图片；不得妨碍服务运行或利用漏洞；不得擅自复制、修改、分发或逆向工程应用；不得违反法律或公共秩序。',
    ),
    ('第8条 使用限制', '违反第7条时，运营方可采取警告、暂停或注销等措施。用户可通过联系邮箱提出异议。'),
    (
      '第9条 付费服务',
      '付费游戏或道具的价格、支付与退款条件将在购买页面另行说明，并遵循 App Store 或 Google Play 的政策。',
    ),
    ('第10条 注销', '用户可随时在个人资料页面注销账号。账号和个人资料将依据隐私政策删除。'),
    (
      '第11条 责任限制',
      '对于自然灾害、用户设备或网络环境、用户过错等非运营方原因造成的损失，运营方不承担责任；运营方故意或重大过失造成的损失除外。',
    ),
    (
      '第12条 争议解决',
      '运营方与用户将先通过诚信协商解决争议。需要诉讼时，依韩国民事诉讼法确定管辖法院。\n联系邮箱：warmhandongne@gmail.com',
    ),
  ],
);

const _termsOfServiceZhHant = LegalDocument(
  title: 'Mosigame 使用條款',
  effectiveDate: '2026-10-12',
  isDraft: true,
  intro: '本條款規定使用者使用「溫暖社區」（以下稱「營運方」）提供的行動應用程式 Mosigame（以下稱「服務」）時應遵守的基本約定。',
  sections: [
    ('第1條 目的', '本條款規定營運方與使用者之間的服務使用條件、程序、權利、義務及責任。'),
    (
      '第2條 定義',
      '• 服務：使用平板與手機供多人共同遊玩的派對遊戲 App Mosigame 及相關功能\n• 使用者：同意本條款並註冊服務的人\n• 房間：在平板上建立、由手機加入以共同遊戲的空間',
    ),
    (
      '第3條 生效與變更',
      '本條款自使用者在註冊頁面同意時生效。營運方可在法律允許範圍內修改條款，並至少提前7天公告；對使用者不利的重要變更將提前30天公告。不同意時可註銷帳號。',
    ),
    ('第4條 註冊', '年滿14歲者可使用電子郵件、Google 或 Apple 帳號註冊。冒用他人資訊或提交虛假資訊時，使用可能受到限制。'),
    ('第5條 帳號管理', '使用者應自行管理帳號和密碼，不得出借或轉讓。發現帳號遭盜用時請立即通知營運方。'),
    ('第6條 服務提供', '營運方提供建立與加入房間、遊戲進行、個人資料顯示等功能。維護、故障或通訊狀況可能導致服務暫時中斷；可預告時將提前通知。'),
    (
      '第7條 使用者義務',
      '不得使用辱罵、仇恨或歧視性暱稱和圖片；不得妨礙服務運作或利用漏洞；不得擅自複製、修改、散布或逆向工程 App；不得違反法律或公共秩序。',
    ),
    ('第8條 使用限制', '違反第7條時，營運方可採取警告、暫停或註銷等措施。使用者可透過聯絡信箱提出異議。'),
    (
      '第9條 付費服務',
      '付費遊戲或道具的價格、付款與退款條件將在購買頁面另行說明，並遵循 App Store 或 Google Play 的政策。',
    ),
    ('第10條 註銷', '使用者可隨時在個人資料頁面註銷帳號。帳號和個人資料將依據隱私權政策刪除。'),
    (
      '第11條 責任限制',
      '對於天然災害、使用者裝置或網路環境、使用者過錯等非營運方原因造成的損失，營運方不承擔責任；營運方故意或重大過失造成的損失除外。',
    ),
    (
      '第12條 爭議解決',
      '營運方與使用者將先透過誠信協商解決爭議。需要訴訟時，依韓國民事訴訟法確定管轄法院。\n聯絡信箱：warmhandongne@gmail.com',
    ),
  ],
);

const _privacyPolicyEn = LegalDocument(
  title: 'Mosigame Privacy Policy',
  effectiveDate: '2026-08-31',
  intro:
      'Warm Neighborhood (the “Operator”) values your personal information and complies with applicable privacy laws when providing Mosigame.',
  sections: [
    (
      '1. Data collected and how',
      'We collect only data needed for registration and play.\n• Required at registration: email address, nickname, and UID, entered directly or provided by Google or Apple\n• Legacy registration: phone number and marketing consent where previously used\n• Optional profile: a photo selected from your library\n• Game use: room participation and game state such as roles, scores, and turn order, generated during use\n• Diagnostics: crash records, device model, OS and app version, and UID, collected by Firebase Crashlytics\nThe camera is used only to scan a room QR code; images are not stored or sent. Photo access is limited to the image you select. Denying either permission only disables that feature.',
    ),
    (
      '2. Purposes',
      'Data is used for account identification and management, room and game operation, profile display, support, error analysis, and quality improvement. It is not used for advertising or behavioral tracking.',
    ),
    (
      '3. Retention and deletion',
      'Personal data is deleted promptly when the account is closed. Nicknames and game state in an active room may remain until that room is automatically cleaned up for recovery. Records required by law are retained separately. Crash records linked to a UID may be kept for up to 90 days under Firebase Crashlytics retention.',
    ),
    (
      '4. Processors',
      'We do not sell personal data. Processing is entrusted to: Google LLC (Firebase) for authentication, databases, storage, server functions, and crash reporting; Apple Inc. for Apple sign-in; and Shorebird for checking and delivering app code updates.',
    ),
    (
      '5. International transfer',
      'Google LLC receives required service data in Singapore (game-state database) and the United States (authentication, file storage, and crash reporting) to provide the service until account closure. You may refuse, but core service features cannot then be provided.',
    ),
    (
      '6. Your rights',
      'View or edit nickname and profile photo in the profile screen; request deletion through account closure or the account deletion page; and request suspension of processing through the contact address. A legal representative may act with proof of authority.',
    ),
    (
      '7. Children under 14',
      'We do not accept registrations from children under 14. If such data is found, it will be deleted promptly.',
    ),
    (
      '8. Security',
      'Traffic is encrypted with HTTPS/TLS. The Operator does not store passwords; Google, Apple, and Firebase Authentication handle authentication. Database rules limit access, and game-state changes are performed only by the server.',
    ),
    (
      '9. Privacy contact',
      'Privacy officer: Planner Yoon Yuwon\nEmail: warmhandongne@gmail.com\nKorean privacy authorities may also receive reports or consultation requests.',
    ),
    (
      '10. Policy changes',
      'Changes are announced on the website at least 7 days before taking effect, or 30 days for significant changes unfavorable to users.',
    ),
  ],
);

const _privacyPolicyZhHans = LegalDocument(
  title: 'Mosigame 隐私政策',
  effectiveDate: '2026-08-31',
  intro: '“温暖社区”（以下简称“运营方”）在提供 Mosigame 时重视用户个人信息并遵守适用的隐私法律。',
  sections: [
    (
      '1. 收集项目与方式',
      '仅收集注册和游戏所需的最少信息。\n• 注册必填：电子邮箱、昵称、UID，由用户输入或由 Google、Apple 提供\n• 旧版注册：曾使用的手机号和营销接收同意\n• 可选资料：用户从相册选择的头像\n• 游戏使用：房间参与记录及角色、分数、顺序等游戏状态\n• 错误诊断：崩溃记录、设备型号、系统和应用版本、UID（Firebase Crashlytics）\n相机仅用于扫描房间二维码，不保存或传输画面；相册仅访问用户选择的图片。拒绝权限只会限制对应功能。',
    ),
    ('2. 处理目的', '用于账号识别与管理、房间和游戏运行、资料显示、咨询回复、错误分析与质量改善。不用于广告或行为追踪。'),
    (
      '3. 保存与删除',
      '注销时立即删除个人信息。进行中房间的昵称和游戏状态可能为恢复游戏保留至房间自动清理。法律要求的信息将另行保存。关联 UID 的崩溃记录最长保存90天。',
    ),
    (
      '4. 委托处理',
      '不出售个人信息。Google LLC（Firebase）处理认证、数据库、文件、服务器功能和错误收集；Apple Inc. 处理 Apple 登录；Shorebird 检查并传送应用代码更新。',
    ),
    (
      '5. 境外传输',
      '为提供服务，Google LLC 在新加坡处理游戏状态数据库，在美国处理认证、文件和错误信息，保存至注销。用户可拒绝，但将无法使用依赖该基础设施的核心功能。',
    ),
    (
      '6. 用户权利',
      '可在个人资料页查看或修改昵称和头像；可通过注销或账号删除页面要求删除；可通过联系邮箱要求停止处理。法定代理人可凭授权证明代为行使。',
    ),
    ('7. 未满14周岁儿童', '不接受未满14周岁儿童注册。发现相关信息时将立即删除。'),
    (
      '8. 安全措施',
      '通信使用 HTTPS/TLS 加密。运营方不保存密码，认证由 Google、Apple 和 Firebase Authentication 处理。数据库规则限制访问，游戏状态仅由服务器修改。',
    ),
    (
      '9. 隐私负责人',
      '负责人：策划人 尹裕元\n邮箱：warmhandongne@gmail.com\n也可向韩国相关隐私保护机构举报或咨询。',
    ),
    ('10. 政策变更', '变更至少提前7天在网站公告；对用户不利的重要变更提前30天公告。'),
  ],
);

const _privacyPolicyZhHant = LegalDocument(
  title: 'Mosigame 隱私權政策',
  effectiveDate: '2026-08-31',
  intro: '「溫暖社區」（以下稱「營運方」）在提供 Mosigame 時重視使用者個人資訊並遵守適用的隱私法律。',
  sections: [
    (
      '1. 蒐集項目與方式',
      '僅蒐集註冊和遊戲所需的最少資訊。\n• 註冊必填：電子郵件、暱稱、UID，由使用者輸入或由 Google、Apple 提供\n• 舊版註冊：曾使用的手機號碼和行銷接收同意\n• 選填資料：使用者從相簿選擇的頭像\n• 遊戲使用：房間參與記錄及角色、分數、順序等遊戲狀態\n• 錯誤診斷：當機記錄、裝置型號、系統和 App 版本、UID（Firebase Crashlytics）\n相機僅用於掃描房間 QR Code，不儲存或傳輸畫面；相簿僅存取使用者選擇的圖片。拒絕權限只會限制對應功能。',
    ),
    ('2. 處理目的', '用於帳號識別與管理、房間和遊戲運作、資料顯示、諮詢回覆、錯誤分析與品質改善。不用於廣告或行為追蹤。'),
    (
      '3. 保存與刪除',
      '註銷時立即刪除個人資訊。進行中房間的暱稱和遊戲狀態可能為恢復遊戲保留至房間自動清理。法律要求的資訊將另行保存。關聯 UID 的當機記錄最長保存90天。',
    ),
    (
      '4. 委託處理',
      '不出售個人資訊。Google LLC（Firebase）處理認證、資料庫、檔案、伺服器功能和錯誤蒐集；Apple Inc. 處理 Apple 登入；Shorebird 檢查並傳送 App 程式碼更新。',
    ),
    (
      '5. 境外傳輸',
      '為提供服務，Google LLC 在新加坡處理遊戲狀態資料庫，在美國處理認證、檔案和錯誤資訊，保存至註銷。使用者可拒絕，但將無法使用依賴該基礎設施的核心功能。',
    ),
    (
      '6. 使用者權利',
      '可在個人資料頁查看或修改暱稱和頭像；可透過註銷或帳號刪除頁面要求刪除；可透過聯絡信箱要求停止處理。法定代理人可憑授權證明代為行使。',
    ),
    ('7. 未滿14歲兒童', '不接受未滿14歲兒童註冊。發現相關資訊時將立即刪除。'),
    (
      '8. 安全措施',
      '通訊使用 HTTPS/TLS 加密。營運方不保存密碼，認證由 Google、Apple 和 Firebase Authentication 處理。資料庫規則限制存取，遊戲狀態僅由伺服器修改。',
    ),
    ('9. 隱私負責人', '負責人：企劃 尹裕元\n信箱：warmhandongne@gmail.com\n也可向韓國相關隱私保護機構檢舉或諮詢。'),
    ('10. 政策變更', '變更至少提前7天在網站公告；對使用者不利的重要變更提前30天公告。'),
  ],
);
