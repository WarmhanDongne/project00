// [signup_terms.dart] 는 회원가입 약관 동의의 버전·동의 내용·문서 본문을 모아 둔 파일이다.
//
// - [Platform] : 회원가입(이메일·Google·Apple 공통)
// - [Legal] : 이용약관·개인정보 처리방침과 동의 기록
//
// 즉, 약관을 고칠 때 버전과 본문을 한곳에서 바꾸기 위해 필요한 파일이다.

import 'dart:convert';

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
/// 이메일 가입은 약관 동의 → 메일 링크(앱 밖) → 비밀번호 → 프로필 순서라
/// 그 사이 앱이 다시 시작될 수 있습니다. 서버에는 가입을 마칠 때 함께
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
const termsOfService = LegalDocument(
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
const privacyPolicy = LegalDocument(
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
