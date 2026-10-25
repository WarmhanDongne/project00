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
  });

  /// 만 14세 이상입니다(필수).
  final bool age14;

  /// 이용약관에 동의했습니다(필수).
  final bool terms;

  /// 개인정보 수집·이용에 동의했습니다(필수).
  final bool privacy;

  bool get requiredAgreed => age14 && terms && privacy;

  /// 아직 동의하지 않은 필수 항목 수입니다.
  int get requiredLeft => [age14, terms, privacy].where((on) => !on).length;

  SignupConsents copyWith({bool? age14, bool? terms, bool? privacy}) =>
      SignupConsents(
        age14: age14 ?? this.age14,
        terms: terms ?? this.terms,
        privacy: privacy ?? this.privacy,
      );

  /// 서버 `completeOnboardingProfile`에 보내는 값입니다.
  Map<String, Object> toJson() => {
    'version': SignupTermsVersion.current,
    'age14': age14,
    'terms': terms,
    'privacy': privacy,
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
/// 원본은 노션에 게시한 이용약관이며 한국어 본문은 그대로 옮겼습니다. 다른 언어는
/// 번역본입니다. 본문을 고치면 노션과 함께 고치고, 동의를 다시 받아야 하면
/// [SignupTermsVersion.current]와 서버 버전을 함께 올립니다.
const _termsOfServiceKo = LegalDocument(
  title: '모시겜 이용약관',
  effectiveDate: '2026-10-25',
  sections: [
    (
      '제1조 (목적)',
      '이 약관은 따스한동네(이하 "운영자")가 제공하는 모바일 애플리케이션 "모시겜: 모이면 시작하는 게임" 및 관련 서비스(이하 "서비스")의 이용과 관련하여 운영자와 이용자의 권리, 의무, 책임 및 기타 필요한 사항을 정하는 것을 목적으로 합니다.',
    ),
    (
      '제2조 (용어의 정의)',
      '1. "이용자"란 이 약관에 따라 서비스를 이용하는 회원과 게스트를 말합니다.\n'
          '2. "회원"이란 이메일, Google 계정 또는 Apple 계정으로 가입하여 계정을 만든 이용자를 말합니다.\n'
          '3. "게스트"란 이메일이나 Google·Apple 계정 없이 [게스트로 시작하기]를 선택해, 운영자가 자동으로 만든 닉네임과 임시 계정으로 서비스를 이용하는 이용자를 말합니다.\n'
          '4. "방"이란 태블릿 등 호스트 기기에서 생성되고, 참가자가 방 코드 또는 QR 코드로 입장하여 함께 게임을 진행하는 실시간 게임 공간을 말합니다.\n'
          '5. "호스트"란 방을 생성하고 관리하는 이용자를, "참가자"란 방에 입장한 이용자를 말합니다.\n'
          '6. "게시물"이란 이용자가 서비스에 등록하는 닉네임과 프로필 사진을 말합니다.',
    ),
    (
      '제3조 (약관의 게시와 개정)',
      '1. 운영자는 이 약관을 이용자가 쉽게 확인할 수 있도록 서비스 내 또는 연결 화면에 게시합니다.\n'
          '2. 운영자는 「약관의 규제에 관한 법률」 등 관련 법령을 위반하지 않는 범위에서 이 약관을 개정할 수 있습니다.\n'
          '3. 약관을 개정하는 경우 개정 내용과 적용일을 적용일 7일 전부터 서비스 내에 공지합니다. 이용자에게 불리한 변경은 적용일 30일 전부터 공지하고, 회원에게는 가입한 이메일 등으로 개별 통지합니다.\n'
          '4. 운영자가 제3항에 따라 공지·통지하면서 적용일까지 거부 의사를 밝히지 않으면 승인한 것으로 본다는 뜻을 명확하게 알렸는데도 회원이 명시적으로 거부하지 않은 경우, 개정 약관에 동의한 것으로 봅니다.\n'
          '5. 회원은 개정 약관에 동의하지 않으면 이용계약을 해지(회원 탈퇴)할 수 있습니다.',
    ),
    (
      '제4조 (약관 외 준칙)',
      '이 약관에서 정하지 않은 사항은 「약관의 규제에 관한 법률」, 「정보통신망 이용촉진 및 정보보호 등에 관한 법률」, 「개인정보 보호법」, 「게임산업진흥에 관한 법률」 등 관련 법령과 상관례에 따릅니다.',
    ),
    (
      '제5조 (이용계약의 성립)',
      '1. 회원 이용계약은 가입을 원하는 사람이 이 약관과 개인정보처리방침에 동의하고 가입을 신청한 뒤, 운영자가 이를 승낙함으로써 성립합니다.\n'
          '2. 가입 방법은 이메일 인증 후 비밀번호 설정, Google 계정 로그인, Apple 계정 로그인입니다. 게스트 이용계약은 게스트로 시작할 때 이 약관과 개인정보처리방침에 동의함으로써 성립합니다.\n'
          '3. 운영자는 다음에 해당하는 신청은 승낙하지 않거나 사후에 계약을 해지할 수 있습니다.\n'
          '  1) 타인의 명의나 계정을 도용한 경우\n'
          '  2) 제7조의 이용 연령에 해당하지 않는 경우\n'
          '  3) 이전에 제19조에 따라 이용계약이 해지된 적이 있는 경우. 단, 운영자가 재가입을 승낙한 경우는 제외합니다.',
    ),
    (
      '제6조 (가입 동의와 확인)',
      '1. 서비스는 회원 또는 게스트로 시작한 이용자만 이용할 수 있습니다.\n'
          '2. 가입을 신청하거나 게스트로 시작하는 사람은 이 약관과 개인정보 수집·이용에 동의하고, 만 14세 이상임을 확인해야 합니다.',
    ),
    (
      '제7조 (이용 연령)',
      '1. 회원가입과 게스트 이용은 만 14세 이상만 할 수 있습니다.\n'
          '2. 만 14세 미만인 사람이 가입하거나 게스트로 이용한 사실이 확인되면 운영자는 해당 계정과 개인정보를 지체 없이 삭제합니다.',
    ),
    ('제8조 (회원정보의 변경)', '회원은 서비스 내 설정 화면에서 닉네임과 프로필 사진을 언제든 변경할 수 있습니다.'),
    (
      '제9조 (계정 관리의 책임)',
      '1. 회원은 자신의 계정, 비밀번호 및 연동한 Google·Apple 계정을 스스로 관리하며, 제3자가 이용하게 해서는 안 됩니다.\n'
          '2. 계정이 도용되거나 제3자가 사용하고 있음을 알게 된 경우 즉시 운영자에게 알려야 합니다.\n'
          '3. 운영자는 자신의 고의 또는 과실이 없는 한, 회원이 계정 관리를 소홀히 하여 발생한 손해에 대하여 책임을 지지 않습니다.\n'
          '4. 게스트 계정은 이메일이나 소셜 계정과 연결되지 않으므로, 게스트가 로그아웃하거나 앱 데이터를 지우거나 앱을 삭제하면 같은 계정으로 다시 접속할 수 없고 운영자도 이를 복구할 수 없습니다.',
    ),
    (
      '제10조 (회원 탈퇴)',
      '1. 회원은 언제든지 서비스 내 [내 프로필 > 회원탈퇴] 메뉴에서 탈퇴할 수 있으며, 앱을 이용할 수 없는 경우 warmhandongne@gmail.com으로 요청할 수 있습니다.\n'
          '2. 탈퇴하면 회원이 호스트로 있는 방이 종료되고, 회원 계정·프로필 정보·프로필 사진이 삭제되며 복구할 수 없습니다. 단, 관련 법령에 따라 보관이 필요한 정보는 해당 기간 동안 보관합니다.\n'
          '3. Apple 계정으로 가입한 회원은 탈퇴 시 Apple 계정 재인증을 거치며, 연동이 해제됩니다.\n'
          '4. 게스트도 같은 메뉴에서 탈퇴할 수 있으며, 탈퇴하면 게스트 계정과 관련 정보가 같은 방식으로 삭제됩니다.',
    ),
    (
      '제11조 (서비스의 내용)',
      '1. 서비스는 한 자리에 모인 이용자들이 호스트 기기(태블릿 등)와 각자의 휴대폰으로 함께 즐기는 파티 게임을 제공합니다.\n'
          '2. 운영자가 제공하는 게임은 서비스 내에 표시된 목록을 따르며, 운영자는 제13조에 따라 게임을 추가하거나 변경할 수 있습니다.\n'
          '3. 게임 진행과 승패 판정은 운영자의 서버가 처리하며, 서버의 처리 결과를 기준으로 합니다.',
    ),
    (
      '제12조 (방의 생성과 참여)',
      '1. 호스트는 방을 만들고 방 코드 또는 QR 코드를 참가자에게 알려 방에 초대합니다. 방 코드를 아는 사람은 누구나 입장할 수 있으므로, 호스트는 코드를 함께 할 사람에게만 알려야 합니다.\n'
          '2. 한 방의 최대 인원은 12명이며, 게임별로 참가 인원이 따로 정해질 수 있습니다.\n'
          '3. 호스트는 게임 시작 전 대기방에서 참가자를 내보낼 수 있습니다. 이는 해당 방에만 적용되며, 운영자의 이용 제한(제19조)과는 별개입니다.\n'
          '4. 대기방에서 연결이 5분 이상 끊긴 참가자는 자동으로 방에서 나가게 됩니다. 게임 중 연결이 끊기면 서비스가 정한 유예 시간 안에 다시 접속할 수 있습니다.\n'
          '5. 게임이 끝난 방의 정보는 일정 시간이 지나면 자동으로 삭제되며, 게임 기록은 별도로 보관되지 않습니다.',
    ),
    (
      '제13조 (서비스의 변경과 중단)',
      '1. 서비스는 연중무휴 제공하는 것을 원칙으로 하나, 점검·장애·통신 두절이나 외부 서비스(제22조)의 장애가 있으면 일시 중단될 수 있습니다.\n'
          '2. 운영자는 게임의 추가·변경·종료 등 서비스 내용을 변경할 수 있으며, 중요한 변경은 사전에 서비스 내에 공지합니다.\n'
          '3. 운영자가 서비스 전체를 종료하는 경우 종료일 30일 전까지 서비스 내에 공지합니다.',
    ),
    (
      '제14조 (이용요금)',
      '1. 서비스는 현재 무료로 제공되며, 앱 내 결제 기능이 없습니다.\n'
          '2. 운영자가 유료 서비스를 도입하는 경우 요금, 결제 방법, 청약철회와 환불 기준을 제3조의 절차에 따라 미리 알리며, 이용자가 따로 구매하지 않는 한 요금이 부과되지 않습니다.\n'
          '3. 서비스 이용에 따른 데이터 통신료는 이용자가 가입한 통신사의 요금제에 따릅니다.',
    ),
    (
      '제15조 (앱 업데이트)',
      '1. 운영자는 기능 개선, 오류 수정, 보안을 위해 앱을 업데이트할 수 있으며, 일부 수정사항은 앱 실행 시 자동으로 받아 적용될 수 있습니다.\n'
          '2. 이용자가 필수 업데이트를 설치하지 않으면 일부 기능이 제한될 수 있습니다.\n'
          '3. 기기의 루팅·탈옥 등 운영체제를 임의로 변경한 환경에서는 서비스가 정상 작동하지 않을 수 있습니다.',
    ),
    (
      '제16조 (운영자의 의무)',
      '1. 운영자는 관련 법령과 이 약관을 지키며, 안정적으로 서비스를 제공하기 위해 노력합니다.\n'
          '2. 운영자는 개인정보처리방침을 공개하고 이를 따릅니다.\n'
          '3. 운영자는 이용자의 문의와 불만이 정당하다고 판단되면 지체 없이 처리하고, 처리에 시간이 걸리면 그 사유와 일정을 알립니다.',
    ),
    (
      '제17조 (이용자의 의무)',
      '이용자는 다음 행위를 해서는 안 됩니다.\n'
          '1. 타인의 계정을 도용하거나 타인을 사칭하는 행위\n'
          '2. 서비스를 복제·변경·역설계·디컴파일하거나, 비정상적인 방법(변조된 앱, 자동화 프로그램 등)으로 서버에 접속하는 행위. 단, 법령이 허용하는 범위는 제외합니다.\n'
          '3. 서비스의 오류를 악용하거나 과도한 요청으로 서버 운영을 방해하는 행위\n'
          '4. 다른 사람의 방에 무단으로 입장하여 게임을 방해하는 행위\n'
          '5. 욕설, 비하, 음란·폭력적 표현, 차별·혐오 표현, 타인의 개인정보를 담은 닉네임이나 프로필 사진을 사용하는 행위\n'
          '6. 타인의 저작권·초상권 등 권리를 침해하는 사진을 올리는 행위\n'
          '7. 게임 결과를 도박·사행 행위에 이용하는 행위\n'
          '8. 벌칙(패널티 룰렛 등)을 이유로 다른 사람에게 음주, 신체적 위험, 수치심을 주는 행동을 강요하는 행위\n'
          '9. 운영자의 상표·로고를 무단으로 사용하거나 운영자를 사칭하는 행위\n'
          '10. 그 밖에 관련 법령에 위반되는 행위',
    ),
    (
      '제18조 (게시물)',
      '1. 게시물의 권리와 책임은 이를 등록한 이용자에게 있습니다.\n'
          '2. 닉네임은 같은 방의 참가자와 호스트 기기 화면에 표시되며, 프로필 사진은 다른 이용자에게 표시되지 않습니다.\n'
          '3. 이용자는 운영자가 서비스를 제공하는 데 필요한 범위(저장, 화면 표시, 크기 조정 등)에서 게시물을 이용하는 것을 허락합니다. 운영자는 이를 다른 목적으로 사용하거나 제3자에게 제공하지 않습니다.\n'
          '4. 운영자는 게시물이 제17조에 해당하면 사전 통지 없이 삭제하거나 기본값으로 바꿀 수 있으며, 조치 후 그 사실과 사유를 알립니다.\n'
          '5. 권리를 침해당한 사람은 warmhandongne@gmail.com으로 신고할 수 있으며, 운영자는 「정보통신망 이용촉진 및 정보보호 등에 관한 법률」에 따라 임시조치 등을 취합니다.',
    ),
    (
      '제19조 (이용 제한)',
      '1. 운영자는 이용자가 제17조를 위반하면 위반의 정도에 따라 경고, 일시 이용 정지, 이용계약 해지 순으로 이용을 제한할 수 있습니다.\n'
          '2. 다음의 경우에는 단계를 거치지 않고 즉시 이용계약을 해지할 수 있습니다.\n'
          '  1) 타인의 계정을 도용한 경우\n'
          '  2) 서비스를 변조하거나 서버에 중대한 장애를 일으킨 경우\n'
          '  3) 게임을 도박·사행 행위에 이용한 경우\n'
          '  4) 그 밖에 법령을 중대하게 위반한 경우\n'
          '3. 운영자는 이용을 제한할 때 그 사유와 기간을 회원의 이메일로 알립니다. 이메일이 없는 게스트에게는 서비스 내 화면으로 알립니다.\n'
          '4. 이용자는 이용 제한에 이의가 있으면 통지를 받은 날부터 14일 안에 warmhandongne@gmail.com으로 이의를 신청할 수 있으며, 운영자는 이를 검토해 결과를 알립니다.',
    ),
    (
      '제20조 (개인정보 보호)',
      '운영자는 이용자의 개인정보를 「개인정보 보호법」 등 관련 법령과 별도의 개인정보처리방침에 따라 보호합니다. 수집 항목, 이용 목적, 보관 기간, 위탁 및 국외 이전에 관한 사항은 개인정보처리방침에서 정합니다.',
    ),
    (
      '제21조 (지식재산권)',
      '1. 서비스와 그에 포함된 프로그램, 디자인, 캐릭터 아이콘, 게임 규칙 표현, 상표·로고에 대한 권리는 운영자 또는 정당한 권리자에게 있습니다.\n'
          '2. 운영자는 이용자에게 서비스를 개인적·비상업적으로 이용할 수 있는 양도 불가능한 권한만을 부여합니다.\n'
          '3. 이용자는 운영자의 사전 동의 없이 서비스의 콘텐츠를 복제·배포·방송하거나 영리 목적으로 이용할 수 없습니다.',
    ),
    (
      '제22조 (외부 서비스)',
      '1. 서비스는 다음 외부 서비스를 이용합니다. 각 서비스의 이용에는 해당 제공자의 약관과 개인정보처리방침이 함께 적용될 수 있습니다.\n'
          '  • Google Firebase (인증, 데이터 저장, 서버 기능, 앱 무결성 확인, 오류 보고)\n'
          '  • Google 로그인, Apple 로그인\n'
          '  • Shorebird (앱 수정사항 배포)\n'
          '2. 운영자는 외부 서비스의 장애나 정책 변경으로 서비스 이용에 문제가 생기면 이를 알리고 복구를 위해 노력합니다.',
    ),
    (
      '제23조 (손해배상과 면책)',
      '1. 운영자 또는 이용자가 이 약관을 위반하여 상대방에게 손해를 입히면 그 손해를 배상해야 합니다.\n'
          '2. 운영자는 다음의 경우 책임을 지지 않습니다. 단, 운영자의 고의 또는 중대한 과실이 있는 경우는 제외합니다.\n'
          '  1) 천재지변 등 불가항력으로 서비스를 제공할 수 없는 경우\n'
          '  2) 이용자의 기기, 통신 환경, 배터리 부족 등 이용자 쪽 사정으로 서비스를 이용하지 못한 경우\n'
          '  3) 이용자가 서비스 밖에서 자율적으로 한 벌칙 수행, 내기 등 이용자 사이에서 일어난 분쟁과 손해\n'
          '  4) 이용자가 방 코드를 공개하여 원치 않는 사람이 입장한 경우\n'
          '3. 서비스는 무료로 제공되므로, 운영자는 법령에 특별한 규정이 없는 한 무료 서비스 이용과 관련하여 고의 또는 중대한 과실이 없는 손해를 배상하지 않습니다.',
    ),
    (
      '제24조 (준거법과 관할)',
      '1. 이 약관과 서비스 이용에는 대한민국 법을 적용합니다.\n'
          '2. 운영자와 이용자 사이의 분쟁에 관한 소송은 「민사소송법」에 따른 관할 법원에 제기합니다.',
    ),
    (
      '제25조 (문의처)',
      '서비스와 이 약관에 관한 문의는 아래로 해 주세요.\n'
          '• 운영자: 따스한동네 / 대표자: 윤유원\n'
          '• 사업자등록번호: 해당 없음\n'
          '• 주소: 경상북도 포항시 북구 한동로 558 한동대학교\n'
          '• 이메일: warmhandongne@gmail.com',
    ),
    ('부칙', '이 약관은 2026년 10월 25일부터 시행합니다.'),
  ],
);

/// 모시겜 개인정보 처리방침입니다.
///
/// 원본은 노션에 게시한 개인정보처리방침입니다. 홈페이지 공개본
/// (`public/privacy/index.html`)도 같은 내용이어야 하니 함께 고칩니다.
const _privacyPolicyKo = LegalDocument(
  title: '모시겜 개인정보 처리방침',
  effectiveDate: '2026-10-12',
  intro:
      '따스한동네(이하 "운영자")는 "모시겜: 모이면 시작하는 게임" 서비스(이하 "서비스")를 제공하면서 「개인정보 보호법」 등 관련 법령에 따라 이용자의 개인정보를 보호하고, 이와 관련한 고충을 신속하게 처리하기 위해 다음과 같이 개인정보처리방침을 정합니다.',
  sections: [
    (
      '1. 수집하는 개인정보 항목과 수집 방법',
      '서비스는 회원가입을 하거나 게스트로 시작한 이용자만 사용할 수 있으며, 서비스 제공에 필요한 최소한의 개인정보만 수집합니다.\n'
          '• 회원가입·로그인: 이메일 주소, 비밀번호(이메일 가입 시), 소셜 로그인 제공자(Google·Apple)와 계정 식별값 (가입 시 이용자가 직접 입력하거나 Google·Apple 로그인으로 제공)\n'
          '• 게스트 시작: 임시 계정 식별값, 자동으로 만든 닉네임(예: 게스트a1b2c3). 이메일·비밀번호·소셜 계정 정보는 수집하지 않습니다. ([게스트로 시작하기]를 선택하면 자동 생성)\n'
          '• 소셜 로그인 프로필: Google 계정 이름과 프로필 사진 주소(URL), Apple 계정 이름(이용자가 제공한 경우). 닉네임과 프로필 사진의 처음 값으로 쓰이며, 이용자가 바꿀 수 있습니다. (Google·Apple 로그인 시 해당 사업자로부터 제공)\n'
          '• 약관 동의 기록: 만 14세 이상 확인, 이용약관·개인정보 수집·이용 동의 여부, 동의한 약관 버전과 동의 시각 (가입 시 이용자가 직접 선택)\n'
          '• 프로필: 닉네임, 프로필 사진(선택), 보유 게임 정보 (이용자가 직접 입력·선택)\n'
          '• 게임 이용(방): 방 코드, 방에서 사용하는 닉네임과 캐릭터 아이콘, 접속 상태와 마지막 접속 시각, 게임 진행 정보 (서비스 이용 중 자동 생성)\n'
          '• 오류·장애 대응: 오류 보고서(앱 오류 정보, 기기 모델과 운영체제 버전, 회원 식별값), 서버 처리 기록(회원 식별값, 방 코드, 처리 결과) (서비스 이용 중 자동 생성·수집)\n'
          '• 앱 무결성 확인: 앱 변조 여부와 기기 무결성을 확인하기 위한 신호 (Google Firebase App Check가 자동으로 확인)\n'
          '기기에는 방에 다시 접속하기 위한 식별 정보, 이메일 인증 대기 정보, 언어·사운드 설정이 저장됩니다. 이 정보는 이용자의 기기에만 저장되며 운영자의 서버로 전송되지 않습니다.\n'
          '서비스는 위치정보를 수집하지 않고, 광고나 맞춤형 서비스를 위한 행태정보를 수집하지 않습니다.',
    ),
    (
      '2. 개인정보의 이용 목적',
      '1. 회원가입 의사 확인, 본인 식별·인증, 회원 관리\n'
          '2. 방 생성·입장과 게임 진행 등 서비스 제공\n'
          '3. 같은 방 참가자에게 닉네임을 표시하는 등 게임 이용 환경 제공\n'
          '4. 오류 분석과 서비스 안정화, 앱 변조·비정상 접속 방지\n'
          '5. 이용자의 문의·민원 처리, 약관 위반 행위에 대한 조치와 공지·통지',
    ),
    (
      '3. 개인정보의 보유 및 이용 기간',
      '운영자는 개인정보의 수집·이용 목적을 달성하면 지체 없이 파기합니다. 보유 기간은 다음과 같습니다.\n'
          '• 회원 정보(이메일, 닉네임, 프로필 사진 등): 회원 탈퇴 시까지. 탈퇴하면 즉시 삭제합니다.\n'
          '• 게스트 정보(임시 계정 식별값, 자동 닉네임, 동의 기록): 게스트가 탈퇴할 때까지. 탈퇴하면 즉시 삭제합니다. 로그아웃하거나 앱을 삭제하면 게스트가 다시 접속할 수 없으므로, 정보를 지우려면 로그아웃 전에 탈퇴해 주세요. 그 밖의 삭제 요청은 11.의 연락처로 받습니다.\n'
          '• 가입 미완료 정보(가입 진행 상태): 가입을 완료하지 않은 경우 가입 진행 상태 정보(회원 식별값, 로그인 방식, 진행 상태)를 보관하며, 이용자가 삭제를 요청하면 지체 없이 삭제합니다.\n'
          '• 방과 게임 진행 정보: 호스트가 방을 닫으면 약 1분 뒤, 게임이 끝났거나 연결이 끊긴 방은 마지막 활동 후 15분이 지나면 자동 삭제합니다. 게임 기록은 별도로 보관하지 않습니다.\n'
          '• 오류 보고서·서버 처리 기록: 제공 서비스의 기본 보관 기간 동안만 보관합니다(Firebase Crashlytics 약 90일, Google Cloud Logging 기본 30일).\n'
          '관련 법령에 따라 보관해야 하는 정보는 해당 법령이 정한 기간 동안 보관합니다.',
    ),
    (
      '4. 개인정보의 제3자 제공',
      '운영자는 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만 법령에 근거가 있거나 수사기관이 법령에 따른 절차로 요청하는 경우는 예외입니다.',
    ),
    (
      '5. 개인정보 처리 위탁 및 국외 이전',
      '서비스 제공을 위해 다음 업체의 서비스를 이용하며, 이 과정에서 개인정보가 처리되거나 국외로 이전될 수 있습니다.\n'
          '• Google LLC(Firebase: 인증, Firestore, Realtime Database, Storage, Cloud Functions, App Check, Crashlytics)\n'
          '  - 항목: 위 1.의 수집 항목 전체\n'
          '  - 목적: 회원 인증, 데이터 저장, 게임 서버 운영, 앱 무결성 확인, 오류 보고\n'
          '  - 국가: 싱가포르(Realtime Database), 미국(Storage, 인증, 오류 보고). Firestore와 서버 기능은 서울에 있습니다.\n'
          '  - 시기·방법: 서비스 이용 시 네트워크(암호화 통신)를 통해 수시 전송\n'
          '  - 기간: 위 3.의 보유 기간과 같음\n'
          '• Google LLC(Google 로그인), Apple Inc.(Apple 로그인)\n'
          '  - 항목: 소셜 로그인 인증 정보, 이메일 주소\n'
          '  - 목적: 소셜 로그인 인증\n'
          '  - 국가: 미국\n'
          '  - 시기·방법: 로그인 시 네트워크(암호화 통신)를 통해 전송\n'
          '  - 기간: 각 사의 정책에 따름\n'
          '• Shorebird\n'
          '  - 항목: 앱 버전 정보, 접속 IP 주소 등 앱 수정사항 확인에 필요한 기술 정보\n'
          '  - 목적: 앱 수정사항 배포\n'
          '  - 국가: 미국\n'
          '  - 시기·방법: 앱 실행 시 네트워크(암호화 통신)를 통해 전송\n'
          '  - 기간: 해당 업체의 정책에 따름\n'
          '이용자는 국외 이전을 거부할 수 있습니다. 다만 거부하면 회원가입과 서비스 이용이 어렵습니다. 국외 이전을 원하지 않으면 11.의 연락처로 문의해 주세요.',
    ),
    (
      '6. 개인정보의 파기 절차와 방법',
      '1. 파기 절차: 보유 기간이 지났거나 처리 목적을 달성한 개인정보는 지체 없이 파기합니다. 법령에 따라 보관해야 하는 정보는 별도로 분리해 보관한 뒤 기간이 끝나면 파기합니다.\n'
          '2. 파기 방법: 전자적 파일 형태의 정보는 복구할 수 없는 방법으로 삭제합니다.\n'
          '3. 회원이 탈퇴하면 회원 계정, 프로필 정보, 프로필 사진을 삭제하며, 회원이 호스트로 있는 방도 함께 종료합니다. Apple 계정으로 가입한 회원은 탈퇴 시 Apple 계정 재인증을 거쳐 연동이 해제됩니다.',
    ),
    (
      '7. 이용자의 권리와 행사 방법',
      '1. 이용자는 언제든지 자신의 개인정보를 열람·정정·삭제하거나 처리 정지를 요구하고, 개인정보 수집·이용 동의를 철회할 수 있습니다.\n'
          '2. 닉네임과 프로필 사진은 서비스 내 설정 화면에서 직접 바꿀 수 있고, 회원 탈퇴는 서비스 내 [내 프로필 > 회원탈퇴] 메뉴에서 할 수 있습니다. 게스트도 같은 메뉴에서 탈퇴할 수 있습니다.\n'
          '3. 앱을 이용할 수 없으면 계정 삭제 안내 페이지(https://project0000-ec01e.web.app/account-deletion/)에서 삭제 방법을 확인하고 요청할 수 있습니다.\n'
          '4. 그 밖의 요구는 11.의 연락처로 해 주세요. 운영자는 본인 확인 후 지체 없이 조치하고, 처리 결과를 알립니다.\n'
          '5. 법정대리인은 만 14세 미만 아동의 개인정보에 대해 위 권리를 행사할 수 있습니다.\n'
          '6. 개인정보 수집·이용 동의를 거부할 수 있으나, 필수 항목에 동의하지 않으면 회원가입과 서비스 이용이 제한됩니다.',
    ),
    (
      '8. 만 14세 미만 아동의 개인정보',
      '서비스는 만 14세 이상만 회원가입을 하거나 게스트로 시작할 수 있으며, 만 14세 미만 아동의 개인정보를 수집하지 않습니다. 만 14세 미만인 사람이 가입한 사실이 확인되면 해당 계정과 개인정보를 지체 없이 삭제합니다.',
    ),
    (
      '9. 개인정보 자동 수집 장치와 기기 권한',
      '1. 서비스는 모바일 앱이라 웹 쿠키를 사용하지 않습니다. 방 재접속 식별 정보와 설정은 기기 내부 저장소에 저장되며, 앱을 삭제하면 함께 삭제됩니다.\n'
          '2. 카메라: 방 입장 QR 코드를 인식할 때만 사용하며, 촬영한 영상은 저장하거나 서버로 전송하지 않습니다.\n'
          '3. 사진 라이브러리: 프로필 사진을 고를 때만 이용자가 선택한 사진에 접근합니다.\n'
          '4. 위치 정보에는 접근하지 않습니다.\n'
          '5. 이용자는 기기 설정에서 위 권한을 언제든지 허용하거나 거부할 수 있습니다. 거부하면 해당 기능(QR 입장, 프로필 사진 설정)은 이용할 수 없습니다.',
    ),
    (
      '10. 개인정보의 안전성 확보 조치',
      '1. 접근 통제: 데이터베이스와 저장소의 보안 규칙으로 본인의 정보에만 접근할 수 있도록 제한하고, 게임 규칙과 승패 판정은 서버에서 처리합니다.\n'
          '2. 전송 구간 보호: 서비스와 서버 사이의 통신은 암호화된 통신(HTTPS)을 사용합니다.\n'
          '3. 최소 수집: 서비스 제공에 필요한 정보만 수집하고, 결제 정보와 위치정보는 수집하지 않습니다.\n'
          '4. 접근 권한 관리: 개인정보를 처리하는 사람을 최소한으로 제한합니다.',
    ),
    (
      '11. 개인정보 보호책임자 및 문의처',
      '운영자는 개인정보 처리에 관한 업무를 총괄하고, 이용자의 문의와 불만을 처리하기 위해 아래와 같이 개인정보 보호책임자를 지정합니다.\n'
          '• 개인정보 보호책임자: 윤유원(대표자)\n'
          '• 이메일: warmhandongne@gmail.com\n'
          '• 주소: 경상북도 포항시 북구 한동로 558 한동대학교',
    ),
    (
      '12. 권익침해 구제 방법',
      '개인정보 침해에 대한 피해 구제와 상담이 필요하면 아래 기관에 문의할 수 있습니다.\n'
          '• 개인정보분쟁조정위원회: 1833-6972 (www.kopico.go.kr)\n'
          '• 개인정보침해신고센터: 118 (privacy.kisa.or.kr)\n'
          '• 대검찰청 사이버수사과: 1301 (www.spo.go.kr)\n'
          '• 경찰청 사이버수사국: 182 (ecrm.police.go.kr)',
    ),
    (
      '13. 개인정보처리방침의 변경',
      '이 방침을 바꾸는 경우 변경 내용과 시행일을 시행 7일 전부터 서비스 내에 공지합니다. 수집 항목이나 이용 목적이 달라지는 등 이용자에게 중요한 변경은 시행 30일 전부터 공지하고, 필요한 경우 다시 동의를 받습니다.',
    ),
    ('부칙', '이 방침은 2026년 10월 12일부터 시행합니다.'),
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
  effectiveDate: '2026-10-25',
  intro:
      'This is a translation. If it differs from the Korean version, the Korean version prevails.',
  sections: [
    (
      'Article 1 (Purpose)',
      'These terms set out the rights, obligations, responsibilities, and other matters between Warm Neighborhood (the "Operator") and users regarding the mobile application "Mosigame" and related services (the "Service").',
    ),
    (
      'Article 2 (Definitions)',
      '1. "User" means a member or guest who uses the Service under these terms.\n'
          '2. "Member" means a user who created an account with email, a Google account, or an Apple account.\n'
          '3. "Guest" means a user who chose [Start as guest] without email or a Google or Apple account and uses the Service with a temporary account and a nickname created automatically by the Operator.\n'
          '4. "Room" means a real-time game space created on a host device such as a tablet, which participants join with a room code or QR code to play together.\n'
          '5. "Host" means the user who creates and manages a room, and "participant" means a user who joins a room.\n'
          '6. "Posts" means the nickname and profile photo a user registers in the Service.',
    ),
    (
      'Article 3 (Posting and amendment)',
      '1. The Operator posts these terms in the Service or on a linked screen so users can easily find them.\n'
          '2. The Operator may amend these terms within the limits of applicable law, including the Act on the Regulation of Terms and Conditions.\n'
          '3. Amendments and their effective date are announced in the Service at least 7 days in advance. Changes unfavorable to users are announced at least 30 days in advance and sent individually to members by email or similar means.\n'
          '4. If the Operator clearly states in the notice under paragraph 3 that silence until the effective date will be treated as acceptance, and a member does not expressly object, the member is deemed to accept the amended terms.\n'
          '5. A member who does not accept the amended terms may terminate the agreement by closing the account.',
    ),
    (
      'Article 4 (Other rules)',
      'Matters not covered by these terms follow applicable Korean law, including the Act on the Regulation of Terms and Conditions, the Network Act, the Personal Information Protection Act, and the Game Industry Promotion Act, and general commercial practice.',
    ),
    (
      'Article 5 (Formation of the agreement)',
      '1. A membership agreement is formed when an applicant accepts these terms and the Privacy Policy, applies to sign up, and the Operator approves.\n'
          '2. Sign-up methods are setting a password after email verification, Google sign-in, and Apple sign-in. A guest agreement is formed when a guest accepts these terms and the Privacy Policy when starting as a guest.\n'
          '3. The Operator may refuse or later terminate an application if:\n'
          '  1) another person\'s name or account is used;\n'
          '  2) the applicant does not meet the age requirement in Article 7; or\n'
          '  3) the applicant\'s agreement was previously terminated under Article 19, unless the Operator approves re-registration.',
    ),
    (
      'Article 6 (Consent at sign-up)',
      '1. Only members and users who started as guests can use the Service.\n'
          '2. Anyone signing up or starting as a guest must accept these terms and the collection and use of personal information and confirm they are at least 14.',
    ),
    (
      'Article 7 (Age)',
      '1. Only people aged 14 or older may sign up or use the Service as a guest.\n'
          '2. If a person under 14 is found to have signed up or used the Service as a guest, the Operator promptly deletes the account and personal information.',
    ),
    (
      'Article 8 (Changing member information)',
      'Members may change their nickname and profile photo at any time in the settings screen.',
    ),
    (
      'Article 9 (Account responsibility)',
      '1. Members manage their own account, password, and linked Google or Apple account and must not let third parties use them.\n'
          '2. Members must notify the Operator immediately if they learn their account is stolen or used by someone else.\n'
          '3. Unless the Operator is at fault, it is not liable for damage caused by a member\'s careless account management.\n'
          '4. A guest account is not linked to email or a social account. If a guest signs out, clears app data, or deletes the app, the same account cannot be accessed again and the Operator cannot restore it.',
    ),
    (
      'Article 10 (Closing an account)',
      '1. Members may close their account at any time from [My profile > Delete account]. If the app cannot be used, they may request deletion at warmhandongne@gmail.com.\n'
          '2. Closing an account ends any room the member is hosting and permanently deletes the account, profile information, and profile photo. Information that must be kept by law is kept for the required period.\n'
          '3. Members who signed up with Apple re-authenticate with Apple when closing the account, and the link is removed.\n'
          '4. Guests may also close their account from the same menu, and their account and related information are deleted in the same way.',
    ),
    (
      'Article 11 (The Service)',
      '1. The Service provides party games played together by people in the same place, using a host device such as a tablet and their own phones.\n'
          '2. The games offered follow the list shown in the Service, and the Operator may add or change games under Article 13.\n'
          '3. Game progress and results are processed by the Operator\'s server, and the server\'s result is final.',
    ),
    (
      'Article 12 (Creating and joining rooms)',
      '1. The host creates a room and invites participants by sharing the room code or QR code. Anyone with the code can join, so hosts should share it only with people they want to play with.\n'
          '2. A room holds up to 12 people, and each game may set its own number of players.\n'
          '3. The host may remove participants from the waiting room before a game starts. This applies only to that room and is separate from the Operator\'s restrictions under Article 19.\n'
          '4. A participant disconnected from the waiting room for 5 minutes or more leaves the room automatically. A participant disconnected during a game may reconnect within the grace period set by the Service.\n'
          '5. Room information is deleted automatically some time after a game ends, and game records are not kept separately.',
    ),
    (
      'Article 13 (Changes and interruptions)',
      '1. The Service is provided around the clock in principle, but may be interrupted for maintenance, failures, network outages, or failures of external services (Article 22).\n'
          '2. The Operator may add, change, or end games and other features, and announces important changes in the Service in advance.\n'
          '3. If the Operator ends the whole Service, it announces this in the Service at least 30 days before.',
    ),
    (
      'Article 14 (Fees)',
      '1. The Service is currently free and has no in-app payments.\n'
          '2. If paid services are introduced, the Operator announces prices, payment methods, and withdrawal and refund rules in advance under Article 3. No charges apply unless the user makes a separate purchase.\n'
          '3. Data charges follow the user\'s mobile plan.',
    ),
    (
      'Article 15 (App updates)',
      '1. The Operator may update the app to improve features, fix errors, or improve security, and some fixes may be downloaded and applied automatically when the app starts.\n'
          '2. Some features may be limited if a required update is not installed.\n'
          '3. The Service may not work properly on rooted, jailbroken, or otherwise modified operating systems.',
    ),
    (
      'Article 16 (Operator obligations)',
      '1. The Operator complies with applicable law and these terms and strives to provide the Service reliably.\n'
          '2. The Operator publishes and follows its Privacy Policy.\n'
          '3. The Operator handles legitimate inquiries and complaints without delay and explains the reason and schedule if handling takes time.',
    ),
    (
      'Article 17 (User obligations)',
      'Users must not:\n'
          '1. use another person\'s account or impersonate others;\n'
          '2. copy, modify, reverse engineer, or decompile the Service, or access the server by abnormal means such as modified apps or automation tools, except as permitted by law;\n'
          '3. exploit errors or disrupt server operation with excessive requests;\n'
          '4. join other people\'s rooms without permission to disrupt their games;\n'
          '5. use nicknames or profile photos with profanity, insults, obscene or violent content, discrimination or hate, or other people\'s personal information;\n'
          '6. upload photos that infringe copyrights, portrait rights, or other rights;\n'
          '7. use game results for gambling;\n'
          '8. force others to drink, take physical risks, or do humiliating things as a penalty, such as a penalty roulette;\n'
          '9. use the Operator\'s trademarks or logos without permission or impersonate the Operator; or\n'
          '10. otherwise violate applicable law.',
    ),
    (
      'Article 18 (Posts)',
      '1. Rights and responsibility for posts belong to the user who registered them.\n'
          '2. Nicknames are shown to participants in the same room and on the host device. Profile photos are not shown to other users.\n'
          '3. Users allow the Operator to use posts as needed to provide the Service, such as storing, displaying, and resizing them. The Operator does not use them for other purposes or provide them to third parties.\n'
          '4. If a post falls under Article 17, the Operator may delete it or reset it to the default without prior notice, and will notify the user of the action and reason afterward.\n'
          '5. Anyone whose rights are infringed may report it to warmhandongne@gmail.com, and the Operator takes measures such as temporary blocking under the Network Act.',
    ),
    (
      'Article 19 (Restrictions)',
      '1. If a user violates Article 17, the Operator may restrict use by warning, temporary suspension, and termination, depending on the severity.\n'
          '2. The Operator may terminate the agreement immediately if the user:\n'
          '  1) used another person\'s account;\n'
          '  2) modified the Service or caused serious server failures;\n'
          '  3) used games for gambling; or\n'
          '  4) otherwise seriously violated the law.\n'
          '3. The Operator notifies members of the reason and period of a restriction by email. Guests without an email address are notified in the app.\n'
          '4. Users may appeal a restriction to warmhandongne@gmail.com within 14 days of the notice, and the Operator reviews it and responds.',
    ),
    (
      'Article 20 (Privacy)',
      'The Operator protects users\' personal information under the Personal Information Protection Act, other applicable law, and its separate Privacy Policy, which sets out the items collected, purposes, retention, processors, and international transfers.',
    ),
    (
      'Article 21 (Intellectual property)',
      '1. Rights to the Service and its software, design, character icons, game rule expressions, trademarks, and logos belong to the Operator or the rightful owners.\n'
          '2. The Operator grants users only a non-transferable right to use the Service for personal, non-commercial purposes.\n'
          '3. Users may not copy, distribute, broadcast, or commercially use content from the Service without the Operator\'s prior consent.',
    ),
    (
      'Article 22 (External services)',
      '1. The Service uses the following external services, whose own terms and privacy policies may also apply:\n'
          '  • Google Firebase (authentication, data storage, server functions, app integrity checks, crash reporting)\n'
          '  • Google sign-in, Apple sign-in\n'
          '  • Shorebird (app fix delivery)\n'
          '2. If a failure or policy change in an external service affects the Service, the Operator informs users and works to restore it.',
    ),
    (
      'Article 23 (Damages and disclaimers)',
      '1. If the Operator or a user violates these terms and causes damage to the other, they must compensate for it.\n'
          '2. The Operator is not liable in the following cases, except for intentional misconduct or gross negligence:\n'
          '  1) force majeure such as natural disasters;\n'
          '  2) the user cannot use the Service because of their own device, network, battery, or other circumstances;\n'
          '  3) disputes or damage between users from penalties, bets, or other activities they chose to do outside the Service; or\n'
          '  4) unwanted people join because a user made the room code public.\n'
          '3. Because the Service is free, the Operator does not compensate damage related to free use that is not caused by its intentional misconduct or gross negligence, unless the law provides otherwise.',
    ),
    (
      'Article 24 (Governing law and jurisdiction)',
      '1. These terms and the use of the Service are governed by the laws of the Republic of Korea.\n'
          '2. Lawsuits between the Operator and users are filed in the court with jurisdiction under the Korean Civil Procedure Act.',
    ),
    (
      'Article 25 (Contact)',
      'For questions about the Service or these terms:\n'
          '• Operator: Warm Neighborhood / Representative: Yoon Yuwon\n'
          '• Business registration number: none\n'
          '• Address: Handong Global University, 558 Handong-ro, Buk-gu, Pohang, Gyeongsangbuk-do, Korea\n'
          '• Email: warmhandongne@gmail.com',
    ),
    ('Addendum', 'These terms take effect on October 25, 2026.'),
  ],
);

const _termsOfServiceZhHans = LegalDocument(
  title: 'Mosigame 使用条款',
  effectiveDate: '2026-10-25',
  intro: '本文为译文。如与韩文版本不一致，以韩文版本为准。',
  sections: [
    (
      '第1条（目的）',
      '本条款规定温暖社区（以下简称“运营方”）提供的移动应用“Mosigame”及相关服务（以下简称“服务”）在使用过程中运营方与用户之间的权利、义务、责任及其他必要事项。',
    ),
    (
      '第2条（定义）',
      '1. “用户”是指依据本条款使用服务的会员和游客。\n'
          '2. “会员”是指使用电子邮箱、Google 账号或 Apple 账号注册并创建账号的用户。\n'
          '3. “游客”是指不使用电子邮箱或 Google、Apple 账号，选择［以游客身份开始］，使用运营方自动生成的昵称和临时账号使用服务的用户。\n'
          '4. “房间”是指在平板等主机设备上创建、参与者通过房间代码或二维码加入并共同进行游戏的实时游戏空间。\n'
          '5. “房主”是指创建并管理房间的用户，“参与者”是指加入房间的用户。\n'
          '6. “发布内容”是指用户在服务中登记的昵称和头像。',
    ),
    (
      '第3条（条款的公示与修改）',
      '1. 运营方在服务内或链接页面公示本条款，方便用户查看。\n'
          '2. 运营方可在不违反《条款规制法》等相关法律的范围内修改本条款。\n'
          '3. 修改条款时，运营方自生效日前7天起在服务内公告修改内容和生效日。对用户不利的变更自生效日前30天起公告，并通过注册邮箱等方式单独通知会员。\n'
          '4. 运营方依第3项公告或通知时，已明确告知“生效日前未表示拒绝即视为同意”，而会员未明确拒绝的，视为会员同意修改后的条款。\n'
          '5. 会员不同意修改后的条款时，可解除使用合同（删除账号）。',
    ),
    (
      '第4条（条款外规则）',
      '本条款未规定的事项，依照韩国《条款规制法》《信息通信网法》《个人信息保护法》《游戏产业振兴法》等相关法律及商业惯例处理。',
    ),
    (
      '第5条（使用合同的成立）',
      '1. 会员使用合同在申请人同意本条款和隐私政策并申请注册、运营方予以承诺时成立。\n'
          '2. 注册方式包括邮箱验证后设置密码、Google 账号登录和 Apple 账号登录。游客使用合同在用户以游客身份开始并同意本条款和隐私政策时成立。\n'
          '3. 有下列情形之一的，运营方可不予承诺或事后解除合同：\n'
          '  1) 冒用他人名义或账号的；\n'
          '  2) 不符合第7条使用年龄的；\n'
          '  3) 曾依第19条被解除使用合同的，但运营方同意重新注册的除外。',
    ),
    (
      '第6条（注册同意与确认）',
      '1. 只有会员或以游客身份开始的用户可以使用服务。\n'
          '2. 申请注册或以游客身份开始的人，须同意本条款及个人信息的收集和使用，并确认已年满14周岁。',
    ),
    (
      '第7条（使用年龄）',
      '1. 仅年满14周岁者可以注册会员或以游客身份使用。\n'
          '2. 发现未满14周岁者注册或以游客身份使用的，运营方将立即删除该账号及个人信息。',
    ),
    ('第8条（会员信息变更）', '会员可随时在设置页面修改昵称和头像。'),
    (
      '第9条（账号管理责任）',
      '1. 会员应自行管理自己的账号、密码及关联的 Google、Apple 账号，不得让第三方使用。\n'
          '2. 发现账号被盗用或被第三方使用时，应立即通知运营方。\n'
          '3. 除运营方存在故意或过失外，运营方对会员疏于管理账号造成的损失不承担责任。\n'
          '4. 游客账号未与邮箱或社交账号关联。游客退出登录、清除应用数据或删除应用后，将无法再次登录同一账号，运营方也无法恢复。',
    ),
    (
      '第10条（删除账号）',
      '1. 会员可随时在服务内［我的资料 > 删除账号］菜单删除账号；无法使用应用时，可发送邮件至 warmhandongne@gmail.com 申请。\n'
          '2. 删除账号后，会员担任房主的房间将结束，会员账号、资料信息和头像将被删除且无法恢复。但依法需要保存的信息将在规定期间内保存。\n'
          '3. 使用 Apple 账号注册的会员删除账号时需重新验证 Apple 账号，并解除关联。\n'
          '4. 游客也可在同一菜单删除账号，游客账号及相关信息将以相同方式删除。',
    ),
    (
      '第11条（服务内容）',
      '1. 服务提供聚在一起的用户使用主机设备（平板等）和各自手机共同游玩的派对游戏。\n'
          '2. 运营方提供的游戏以服务内显示的列表为准，运营方可依第13条新增或变更游戏。\n'
          '3. 游戏进行和胜负判定由运营方服务器处理，以服务器的处理结果为准。',
    ),
    (
      '第12条（房间的创建与加入）',
      '1. 房主创建房间，并将房间代码或二维码告知参与者以邀请其加入。任何知道房间代码的人都可以加入，因此房主应只告知一起游戏的人。\n'
          '2. 每个房间最多12人，各游戏可另行规定参与人数。\n'
          '3. 房主可在游戏开始前将参与者移出等待房间。此措施仅适用于该房间，与运营方的使用限制（第19条）无关。\n'
          '4. 在等待房间断线5分钟以上的参与者将自动离开房间。游戏中断线时，可在服务规定的宽限时间内重新连接。\n'
          '5. 游戏结束后，房间信息会在一定时间后自动删除，游戏记录不会另行保存。',
    ),
    (
      '第13条（服务的变更与中断）',
      '1. 服务原则上全年无休，但可能因维护、故障、通信中断或外部服务（第22条）故障而暂时中断。\n'
          '2. 运营方可新增、变更或结束游戏等服务内容，重要变更将提前在服务内公告。\n'
          '3. 运营方终止全部服务时，将至少提前30天在服务内公告。',
    ),
    (
      '第14条（使用费用）',
      '1. 服务目前免费提供，没有应用内付费功能。\n'
          '2. 运营方引入付费服务时，将依第3条程序提前告知价格、支付方式、撤回及退款标准。除非用户另行购买，否则不会收费。\n'
          '3. 使用服务产生的数据流量费用依用户所签约的通信套餐计算。',
    ),
    (
      '第15条（应用更新）',
      '1. 运营方可为改进功能、修复错误和保障安全而更新应用，部分修复可能在应用启动时自动下载并应用。\n'
          '2. 用户未安装必要更新时，部分功能可能受到限制。\n'
          '3. 在已 root、越狱等擅自修改操作系统的环境中，服务可能无法正常运行。',
    ),
    (
      '第16条（运营方的义务）',
      '1. 运营方遵守相关法律和本条款，努力稳定地提供服务。\n'
          '2. 运营方公开并遵守隐私政策。\n'
          '3. 运营方认为用户的咨询和投诉正当时将立即处理；处理需要时间时，将告知原因和日程。',
    ),
    (
      '第17条（用户的义务）',
      '用户不得有下列行为：\n'
          '1. 盗用他人账号或冒充他人；\n'
          '2. 复制、修改、逆向工程或反编译服务，或以非正常方式（篡改的应用、自动化程序等）访问服务器，但法律允许的范围除外；\n'
          '3. 利用服务错误或以过量请求妨碍服务器运行；\n'
          '4. 擅自进入他人房间妨碍游戏；\n'
          '5. 使用含辱骂、贬低、淫秽暴力、歧视仇恨内容或他人个人信息的昵称或头像；\n'
          '6. 上传侵犯他人著作权、肖像权等权利的照片；\n'
          '7. 将游戏结果用于赌博或投机行为；\n'
          '8. 以惩罚（惩罚转盘等）为由强迫他人饮酒、从事危险行为或做出令人羞耻的行为；\n'
          '9. 擅自使用运营方的商标、标志或冒充运营方；\n'
          '10. 其他违反相关法律的行为。',
    ),
    (
      '第18条（发布内容）',
      '1. 发布内容的权利和责任归登记该内容的用户所有。\n'
          '2. 昵称会显示给同一房间的参与者并显示在主机设备画面上，头像不会显示给其他用户。\n'
          '3. 用户允许运营方在提供服务所需范围内（保存、显示、调整大小等）使用发布内容。运营方不会将其用于其他目的或提供给第三方。\n'
          '4. 发布内容属于第17条情形时，运营方可不经事先通知予以删除或恢复为默认值，并在处理后告知事实和原因。\n'
          '5. 权利受到侵害者可发送邮件至 warmhandongne@gmail.com 举报，运营方将依《信息通信网法》采取临时措施等。',
    ),
    (
      '第19条（使用限制）',
      '1. 用户违反第17条时，运营方可视违反程度依次采取警告、暂停使用、解除使用合同等限制措施。\n'
          '2. 有下列情形之一的，运营方可不经上述步骤立即解除使用合同：\n'
          '  1) 盗用他人账号的；\n'
          '  2) 篡改服务或造成服务器严重故障的；\n'
          '  3) 将游戏用于赌博或投机行为的；\n'
          '  4) 其他严重违法的。\n'
          '3. 运营方限制使用时，将通过邮件告知会员原因和期间；对没有邮箱的游客，将在服务画面中告知。\n'
          '4. 用户对使用限制有异议的，可在收到通知之日起14天内发送邮件至 warmhandongne@gmail.com 提出异议，运营方将审核并告知结果。',
    ),
    (
      '第20条（个人信息保护）',
      '运营方依照《个人信息保护法》等相关法律及另行制定的隐私政策保护用户的个人信息。收集项目、使用目的、保存期间、委托处理及境外传输等事项由隐私政策规定。',
    ),
    (
      '第21条（知识产权）',
      '1. 服务及其包含的程序、设计、角色图标、游戏规则表述、商标和标志的权利归运营方或合法权利人所有。\n'
          '2. 运营方仅授予用户以个人、非商业目的使用服务的不可转让的权利。\n'
          '3. 未经运营方事先同意，用户不得复制、传播、播放服务内容或将其用于营利目的。',
    ),
    (
      '第22条（外部服务）',
      '1. 服务使用下列外部服务，使用时可能同时适用各提供方的条款和隐私政策：\n'
          '  • Google Firebase（认证、数据存储、服务器功能、应用完整性检查、错误报告）\n'
          '  • Google 登录、Apple 登录\n'
          '  • Shorebird（应用修复发布）\n'
          '2. 因外部服务故障或政策变更影响服务使用时，运营方将告知用户并努力恢复。',
    ),
    (
      '第23条（损害赔偿与免责）',
      '1. 运营方或用户违反本条款给对方造成损害的，应赔偿该损害。\n'
          '2. 有下列情形之一的，运营方不承担责任，但运营方存在故意或重大过失的除外：\n'
          '  1) 因自然灾害等不可抗力无法提供服务的；\n'
          '  2) 因用户的设备、网络环境、电量不足等用户方原因无法使用服务的；\n'
          '  3) 用户在服务之外自行进行的惩罚、打赌等用户之间发生的纠纷和损失；\n'
          '  4) 用户公开房间代码导致不希望的人加入的。\n'
          '3. 由于服务免费提供，除法律另有特别规定外，运营方对与免费服务使用相关、且非因其故意或重大过失造成的损害不予赔偿。',
    ),
    (
      '第24条（准据法与管辖）',
      '1. 本条款及服务的使用适用大韩民国法律。\n'
          '2. 运营方与用户之间的纠纷诉讼，向依韩国《民事诉讼法》具有管辖权的法院提起。',
    ),
    (
      '第25条（联系方式）',
      '关于服务和本条款的咨询，请通过以下方式联系：\n'
          '• 运营方：温暖社区 / 代表：尹裕元\n'
          '• 营业执照号码：无\n'
          '• 地址：韩国庆尚北道浦项市北区韩东路558 韩东大学\n'
          '• 邮箱：warmhandongne@gmail.com',
    ),
    ('附则', '本条款自2026年10月25日起施行。'),
  ],
);

const _termsOfServiceZhHant = LegalDocument(
  title: 'Mosigame 使用條款',
  effectiveDate: '2026-10-25',
  intro: '本文為譯文。如與韓文版本不一致，以韓文版本為準。',
  sections: [
    (
      '第1條（目的）',
      '本條款規定溫暖社區（以下簡稱「營運方」）提供的行動應用程式「Mosigame」及相關服務（以下簡稱「服務」）在使用過程中營運方與使用者之間的權利、義務、責任及其他必要事項。',
    ),
    (
      '第2條（定義）',
      '1. 「使用者」是指依據本條款使用服務的會員和遊客。\n'
          '2. 「會員」是指使用電子郵件信箱、Google 帳號或 Apple 帳號註冊並建立帳號的使用者。\n'
          '3. 「遊客」是指不使用電子郵件信箱或 Google、Apple 帳號，選擇［以遊客身份開始］，使用營運方自動生成的暱稱和臨時帳號使用服務的使用者。\n'
          '4. 「房間」是指在平板等主機裝置上建立、參與者透過房間代碼或QR Code加入並共同進行遊戲的即時遊戲空間。\n'
          '5. 「房主」是指建立並管理房間的使用者，「參與者」是指加入房間的使用者。\n'
          '6. 「發布內容」是指使用者在服務中登記的暱稱和頭像。',
    ),
    (
      '第3條（條款的公示與修改）',
      '1. 營運方在服務內或連結頁面公示本條款，方便使用者檢視。\n'
          '2. 營運方可在不違反《條款規制法》等相關法律的範圍內修改本條款。\n'
          '3. 修改條款時，營運方自生效日前7天起在服務內公告修改內容和生效日。對使用者不利的變更自生效日前30天起公告，並透過註冊電子郵件信箱等方式單獨通知會員。\n'
          '4. 營運方依第3項公告或通知時，已明確告知「生效日前未表示拒絕即視為同意」，而會員未明確拒絕的，視為會員同意修改後的條款。\n'
          '5. 會員不同意修改後的條款時，可解除使用合同（刪除帳號）。',
    ),
    (
      '第4條（條款外規則）',
      '本條款未規定的事項，依照韓國《條款規制法》《資訊通訊網法》《個人資訊保護法》《遊戲產業振興法》等相關法律及商業慣例處理。',
    ),
    (
      '第5條（使用合同的成立）',
      '1. 會員使用合同在申請人同意本條款和隱私權政策並申請註冊、營運方予以承諾時成立。\n'
          '2. 註冊方式包括電子郵件信箱驗證後設定密碼、Google 帳號登入和 Apple 帳號登入。遊客使用合同在使用者以遊客身份開始並同意本條款和隱私權政策時成立。\n'
          '3. 有下列情形之一的，營運方可不予承諾或事後解除合同：\n'
          '  1) 冒用他人名義或帳號的；\n'
          '  2) 不符合第7條使用年齡的；\n'
          '  3) 曾依第19條被解除使用合同的，但營運方同意重新註冊的除外。',
    ),
    (
      '第6條（註冊同意與確認）',
      '1. 只有會員或以遊客身份開始的使用者可以使用服務。\n'
          '2. 申請註冊或以遊客身份開始的人，須同意本條款及個人資訊的收集和使用，並確認已年滿14週歲。',
    ),
    (
      '第7條（使用年齡）',
      '1. 僅年滿14週歲者可以註冊會員或以遊客身份使用。\n'
          '2. 發現未滿14週歲者註冊或以遊客身份使用的，營運方將立即刪除該帳號及個人資訊。',
    ),
    ('第8條（會員資訊變更）', '會員可隨時在設定頁面修改暱稱和頭像。'),
    (
      '第9條（帳號管理責任）',
      '1. 會員應自行管理自己的帳號、密碼及關聯的 Google、Apple 帳號，不得讓第三方使用。\n'
          '2. 發現帳號被盜用或被第三方使用時，應立即通知營運方。\n'
          '3. 除營運方存在故意或過失外，營運方對會員疏於管理帳號造成的損失不承擔責任。\n'
          '4. 遊客帳號未與電子郵件信箱或社交帳號關聯。遊客退出登入、清除應用資料或刪除應用後，將無法再次登入同一帳號，營運方也無法恢復。',
    ),
    (
      '第10條（刪除帳號）',
      '1. 會員可隨時在服務內［我的資料 > 刪除帳號］選單刪除帳號；無法使用應用時，可傳送郵件至 warmhandongne@gmail.com 申請。\n'
          '2. 刪除帳號後，會員擔任房主的房間將結束，會員帳號、資料資訊和頭像將被刪除且無法恢復。但依法需要儲存的資訊將在規定期間內儲存。\n'
          '3. 使用 Apple 帳號註冊的會員刪除帳號時需重新驗證 Apple 帳號，並解除關聯。\n'
          '4. 遊客也可在同一選單刪除帳號，遊客帳號及相關資訊將以相同方式刪除。',
    ),
    (
      '第11條（服務內容）',
      '1. 服務提供聚在一起的使用者使用主機裝置（平板等）和各自手機共同遊玩的派對遊戲。\n'
          '2. 營運方提供的遊戲以服務內顯示的列表為準，營運方可依第13條新增或變更遊戲。\n'
          '3. 遊戲進行和勝負判定由營運方伺服器處理，以伺服器的處理結果為準。',
    ),
    (
      '第12條（房間的建立與加入）',
      '1. 房主建立房間，並將房間代碼或QR Code告知參與者以邀請其加入。任何知道房間代碼的人都可以加入，因此房主應只告知一起遊戲的人。\n'
          '2. 每個房間最多12人，各遊戲可另行規定參與人數。\n'
          '3. 房主可在遊戲開始前將參與者移出等待房間。此措施僅適用於該房間，與營運方的使用限制（第19條）無關。\n'
          '4. 在等待房間斷線5分鐘以上的參與者將自動離開房間。遊戲中斷線時，可在服務規定的寬限時間內重新連線。\n'
          '5. 遊戲結束後，房間資訊會在一定時間後自動刪除，遊戲記錄不會另行儲存。',
    ),
    (
      '第13條（服務的變更與中斷）',
      '1. 服務原則上全年無休，但可能因維護、故障、通訊中斷或外部服務（第22條）故障而暫時中斷。\n'
          '2. 營運方可新增、變更或結束遊戲等服務內容，重要變更將提前在服務內公告。\n'
          '3. 營運方終止全部服務時，將至少提前30天在服務內公告。',
    ),
    (
      '第14條（使用費用）',
      '1. 服務目前免費提供，沒有應用內付費功能。\n'
          '2. 營運方引入付費服務時，將依第3條程式提前告知價格、支付方式、撤回及退款標準。除非使用者另行購買，否則不會收費。\n'
          '3. 使用服務產生的資料流量費用依使用者所簽約的通訊套餐計算。',
    ),
    (
      '第15條（應用更新）',
      '1. 營運方可為改進功能、修復錯誤和保障安全而更新應用，部分修復可能在應用啟動時自動下載並應用。\n'
          '2. 使用者未安裝必要更新時，部分功能可能受到限制。\n'
          '3. 在已 root、越獄等擅自修改作業系統的環境中，服務可能無法正常執行。',
    ),
    (
      '第16條（營運方的義務）',
      '1. 營運方遵守相關法律和本條款，努力穩定地提供服務。\n'
          '2. 營運方公開並遵守隱私權政策。\n'
          '3. 營運方認為使用者的諮詢和投訴正當時將立即處理；處理需要時間時，將告知原因和日程。',
    ),
    (
      '第17條（使用者的義務）',
      '使用者不得有下列行為：\n'
          '1. 盜用他人帳號或冒充他人；\n'
          '2. 複製、修改、逆向工程或反編譯服務，或以非正常方式（篡改的應用、自動化程式等）存取伺服器，但法律允許的範圍除外；\n'
          '3. 利用服務錯誤或以過量請求妨礙伺服器執行；\n'
          '4. 擅自進入他人房間妨礙遊戲；\n'
          '5. 使用含辱罵、貶低、淫穢暴力、歧視仇恨內容或他人個人資訊的暱稱或頭像；\n'
          '6. 上傳侵犯他人著作權、肖像權等權利的照片；\n'
          '7. 將遊戲結果用於賭博或投機行為；\n'
          '8. 以懲罰（懲罰轉盤等）為由強迫他人飲酒、從事危險行為或做出令人羞恥的行為；\n'
          '9. 擅自使用營運方的商標、標誌或冒充營運方；\n'
          '10. 其他違反相關法律的行為。',
    ),
    (
      '第18條（發布內容）',
      '1. 發布內容的權利和責任歸登記該內容的使用者所有。\n'
          '2. 暱稱會顯示給同一房間的參與者並顯示在主機裝置畫面上，頭像不會顯示給其他使用者。\n'
          '3. 使用者允許營運方在提供服務所需範圍內（儲存、顯示、調整大小等）使用發布內容。營運方不會將其用於其他目的或提供給第三方。\n'
          '4. 發布內容屬於第17條情形時，營運方可不經事先通知予以刪除或恢復為預設值，並在處理後告知事實和原因。\n'
          '5. 權利受到侵害者可傳送郵件至 warmhandongne@gmail.com 舉報，營運方將依《資訊通訊網法》採取臨時措施等。',
    ),
    (
      '第19條（使用限制）',
      '1. 使用者違反第17條時，營運方可視違反程度依次採取警告、暫停使用、解除使用合同等限制措施。\n'
          '2. 有下列情形之一的，營運方可不經上述步驟立即解除使用合同：\n'
          '  1) 盜用他人帳號的；\n'
          '  2) 篡改服務或造成伺服器嚴重故障的；\n'
          '  3) 將遊戲用於賭博或投機行為的；\n'
          '  4) 其他嚴重違法的。\n'
          '3. 營運方限制使用時，將透過郵件告知會員原因和期間；對沒有電子郵件信箱的遊客，將在服務畫面中告知。\n'
          '4. 使用者對使用限制有異議的，可在收到通知之日起14天內傳送郵件至 warmhandongne@gmail.com 提出異議，營運方將稽核並告知結果。',
    ),
    (
      '第20條（個人資訊保護）',
      '營運方依照《個人資訊保護法》等相關法律及另行制定的隱私權政策保護使用者的個人資訊。收集項目、使用目的、儲存期間、委託處理及境外傳輸等事項由隱私權政策規定。',
    ),
    (
      '第21條（智慧財產權）',
      '1. 服務及其包含的程式、設計、角色圖示、遊戲規則表述、商標和標誌的權利歸營運方或合法權利人所有。\n'
          '2. 營運方僅授予使用者以個人、非商業目的使用服務的不可轉讓的權利。\n'
          '3. 未經營運方事先同意，使用者不得複製、傳播、播放服務內容或將其用於營利目的。',
    ),
    (
      '第22條（外部服務）',
      '1. 服務使用下列外部服務，使用時可能同時適用各提供方的條款和隱私權政策：\n'
          '  • Google Firebase（認證、資料儲存、伺服器功能、應用完整性檢查、錯誤報告）\n'
          '  • Google 登入、Apple 登入\n'
          '  • Shorebird（應用修復釋出）\n'
          '2. 因外部服務故障或政策變更影響服務使用時，營運方將告知使用者並努力恢復。',
    ),
    (
      '第23條（損害賠償與免責）',
      '1. 營運方或使用者違反本條款給對方造成損害的，應賠償該損害。\n'
          '2. 有下列情形之一的，營運方不承擔責任，但營運方存在故意或重大過失的除外：\n'
          '  1) 因自然災害等不可抗力無法提供服務的；\n'
          '  2) 因使用者的裝置、網路環境、電量不足等使用者方原因無法使用服務的；\n'
          '  3) 使用者在服務之外自行進行的懲罰、打賭等使用者之間發生的糾紛和損失；\n'
          '  4) 使用者公開房間代碼導致不希望的人加入的。\n'
          '3. 由於服務免費提供，除法律另有特別規定外，營運方對與免費服務使用相關、且非因其故意或重大過失造成的損害不予賠償。',
    ),
    (
      '第24條（準據法與管轄）',
      '1. 本條款及服務的使用適用大韓民國法律。\n'
          '2. 營運方與使用者之間的糾紛訴訟，向依韓國《民事訴訟法》具有管轄權的法院提起。',
    ),
    (
      '第25條（聯絡方式）',
      '關於服務和本條款的諮詢，請透過以下方式聯絡：\n'
          '• 營運方：溫暖社區 / 代表：尹裕元\n'
          '• 營業執照號碼：無\n'
          '• 地址：韓國慶尚北道浦項市北區韓東路558 韓東大學\n'
          '• 電子郵件信箱：warmhandongne@gmail.com',
    ),
    ('附則', '本條款自2026年10月25日起施行。'),
  ],
);

const _privacyPolicyEn = LegalDocument(
  title: 'Mosigame Privacy Policy',
  effectiveDate: '2026-10-12',
  intro:
      'Warm Neighborhood (the "Operator") sets this Privacy Policy to protect users\' personal information under the Personal Information Protection Act and other applicable law while providing "Mosigame" (the "Service"), and to handle related complaints promptly.\n'
      'This is a translation. If it differs from the Korean version, the Korean version prevails.',
  sections: [
    (
      '1. Information collected and how',
      'Only members and users who started as guests can use the Service, and we collect only the minimum personal information needed to provide it.\n'
          '• Sign-up and sign-in: email address, password (email sign-up), social sign-in provider (Google or Apple) and account ID (entered by the user or provided through Google or Apple sign-in)\n'
          '• Guest start: temporary account ID and an automatically created nickname (for example, Guesta1b2c3). No email, password, or social account information is collected. (created automatically when [Start as guest] is chosen)\n'
          '• Social sign-in profile: Google account name and profile photo URL, Apple account name (if the user shares it). Used as the initial nickname and profile photo, which the user can change. (provided by Google or Apple at sign-in)\n'
          '• Consent records: confirmation of age 14 or older, consent to the Terms of Service and the collection and use of personal information, the terms version and time of consent (selected by the user at sign-up)\n'
          '• Profile: nickname, profile photo (optional), owned games (entered or selected by the user)\n'
          '• Game use (rooms): room code, nickname and character icon used in the room, connection status and last connection time, game progress (generated during use)\n'
          '• Error and outage handling: crash reports (app error information, device model and OS version, member ID) and server processing logs (member ID, room code, result) (generated or collected during use)\n'
          '• App integrity checks: signals used to check whether the app was modified and the device\'s integrity (checked automatically by Google Firebase App Check)\n'
          'The device stores information for reconnecting to rooms, pending email verification, and language and sound settings. This stays on the device and is not sent to the Operator\'s servers.\n'
          'The Service does not collect location information or behavioral information for advertising or personalization.',
    ),
    (
      '2. Purposes',
      '1. Confirming sign-up, identifying and authenticating users, and managing members\n'
          '2. Providing the Service, such as creating and joining rooms and running games\n'
          '3. Providing the game environment, such as showing nicknames to participants in the same room\n'
          '4. Analyzing errors, stabilizing the Service, and preventing modified apps and abnormal access\n'
          '5. Handling inquiries and complaints, acting on violations of the terms, and sending notices',
    ),
    (
      '3. Retention',
      'The Operator destroys personal information without delay once its purpose is achieved. Retention periods are:\n'
          '• Member information (email, nickname, profile photo, etc.): until the account is closed. Deleted immediately on closure.\n'
          '• Guest information (temporary account ID, automatic nickname, consent records): until the guest closes the account. Deleted immediately on closure. A guest cannot sign in again after signing out or deleting the app, so please close the account before signing out if you want the information deleted. Other deletion requests are handled through the contact in section 11.\n'
          '• Incomplete sign-up information: if sign-up is not completed, sign-up progress information (member ID, sign-in method, progress) is kept and deleted without delay on request.\n'
          '• Room and game progress: deleted automatically about 1 minute after the host closes the room, or 15 minutes after the last activity for rooms whose game ended or that were disconnected. Game records are not kept separately.\n'
          '• Crash reports and server logs: kept only for the providers\' default retention periods (Firebase Crashlytics about 90 days, Google Cloud Logging 30 days by default).\n'
          'Information that must be kept by law is kept for the period the law requires.',
    ),
    (
      '4. Provision to third parties',
      'The Operator does not provide users\' personal information to third parties, except where the law requires it or investigative agencies request it through legal procedures.',
    ),
    (
      '5. Processors and international transfers',
      'We use the following services to provide the Service, and personal information may be processed or transferred abroad in the process.\n'
          '• Google LLC (Firebase: Authentication, Firestore, Realtime Database, Storage, Cloud Functions, App Check, Crashlytics)\n'
          '  - Items: all items in section 1\n'
          '  - Purpose: authentication, data storage, game server operation, app integrity checks, crash reporting\n'
          '  - Country: Singapore (Realtime Database), United States (Storage, Authentication, crash reporting). Firestore and server functions are in Seoul.\n'
          '  - When and how: sent over encrypted network connections whenever the Service is used\n'
          '  - Period: same as section 3\n'
          '• Google LLC (Google sign-in), Apple Inc. (Apple sign-in)\n'
          '  - Items: social sign-in authentication information, email address\n'
          '  - Purpose: social sign-in\n'
          '  - Country: United States\n'
          '  - When and how: sent over encrypted network connections at sign-in\n'
          '  - Period: according to each company\'s policy\n'
          '• Shorebird\n'
          '  - Items: technical information needed to check for app fixes, such as app version and IP address\n'
          '  - Purpose: delivering app fixes\n'
          '  - Country: United States\n'
          '  - When and how: sent over encrypted network connections when the app starts\n'
          '  - Period: according to the company\'s policy\n'
          'You may refuse international transfers, but sign-up and use of the Service will then be difficult. Contact us through section 11 if you do not want your information transferred abroad.',
    ),
    (
      '6. Destruction',
      '1. Procedure: personal information whose retention period has passed or whose purpose is achieved is destroyed without delay. Information that must be kept by law is stored separately and destroyed when the period ends.\n'
          '2. Method: electronic files are deleted so they cannot be recovered.\n'
          '3. When a member closes the account, the account, profile information, and profile photo are deleted, and rooms the member hosts are ended. Members who signed up with Apple re-authenticate with Apple, and the link is removed.',
    ),
    (
      '7. Your rights',
      '1. You may at any time view, correct, or delete your personal information, request suspension of processing, and withdraw consent to collection and use.\n'
          '2. You can change your nickname and profile photo in the settings screen and close your account from [My profile > Delete account]. Guests can use the same menu.\n'
          '3. If you cannot use the app, see the account deletion page (https://project0000-ec01e.web.app/account-deletion/) for how to request deletion.\n'
          '4. Make other requests through the contact in section 11. The Operator verifies your identity, acts without delay, and tells you the result.\n'
          '5. A legal representative may exercise these rights for a child under 14.\n'
          '6. You may refuse consent to collection and use, but sign-up and use of the Service are limited without consent to the required items.',
    ),
    (
      '8. Children under 14',
      'Only people aged 14 or older may sign up or start as a guest, and we do not collect personal information from children under 14. If a person under 14 is found to have signed up, the account and personal information are deleted without delay.',
    ),
    (
      '9. Automatic collection and device permissions',
      '1. The Service is a mobile app and does not use web cookies. Room reconnection information and settings are stored on the device and deleted with the app.\n'
          '2. Camera: used only to scan a room QR code. Images are not stored or sent to a server.\n'
          '3. Photo library: accessed only for the photo you choose as your profile photo.\n'
          '4. Location is not accessed.\n'
          '5. You can allow or deny these permissions at any time in device settings. If denied, the related features (QR join, profile photo) cannot be used.',
    ),
    (
      '10. Security measures',
      '1. Access control: database and storage security rules limit access to your own information, and game rules and results are processed on the server.\n'
          '2. Transmission protection: communication between the Service and servers is encrypted (HTTPS).\n'
          '3. Minimal collection: only information needed for the Service is collected. Payment and location information is not collected.\n'
          '4. Access management: the number of people handling personal information is kept to a minimum.',
    ),
    (
      '11. Privacy officer and contact',
      'The Operator designates the following privacy officer to oversee personal information processing and handle inquiries and complaints.\n'
          '• Privacy officer: Yoon Yuwon (Representative)\n'
          '• Email: warmhandongne@gmail.com\n'
          '• Address: Handong Global University, 558 Handong-ro, Buk-gu, Pohang, Gyeongsangbuk-do, Korea',
    ),
    (
      '12. Remedies',
      'For relief or advice about privacy infringement, you may contact these Korean authorities:\n'
          '• Personal Information Dispute Mediation Committee: 1833-6972 (www.kopico.go.kr)\n'
          '• Personal Information Infringement Report Center: 118 (privacy.kisa.or.kr)\n'
          '• Supreme Prosecutors\' Office Cyber Investigation Division: 1301 (www.spo.go.kr)\n'
          '• Korean National Police Agency Cyber Bureau: 182 (ecrm.police.go.kr)',
    ),
    (
      '13. Changes to this policy',
      'Changes and their effective date are announced in the Service at least 7 days in advance. Important changes, such as new items collected or new purposes, are announced at least 30 days in advance, and consent is requested again when needed.',
    ),
    ('Addendum', 'This policy takes effect on October 12, 2026.'),
  ],
);

const _privacyPolicyZhHans = LegalDocument(
  title: 'Mosigame 隐私政策',
  effectiveDate: '2026-10-12',
  intro:
      '温暖社区（以下简称“运营方”）在提供“Mosigame”服务（以下简称“服务”）时，依照韩国《个人信息保护法》等相关法律保护用户的个人信息，并为迅速处理相关投诉，制定本隐私政策。\n'
      '本文为译文。如与韩文版本不一致，以韩文版本为准。',
  sections: [
    (
      '1. 收集的个人信息项目与收集方式',
      '只有注册会员或以游客身份开始的用户可以使用服务，服务仅收集提供服务所需的最少个人信息。\n'
          '• 注册与登录：电子邮箱、密码（邮箱注册时）、社交登录提供方（Google、Apple）及账号标识（注册时由用户输入或通过 Google、Apple 登录提供）\n'
          '• 游客开始：临时账号标识、自动生成的昵称（例：游客a1b2c3）。不收集邮箱、密码或社交账号信息。（选择［以游客身份开始］时自动生成）\n'
          '• 社交登录资料：Google 账号名称和头像地址（URL）、Apple 账号名称（用户提供时）。用作昵称和头像的初始值，用户可以修改。（Google、Apple 登录时由该公司提供）\n'
          '• 条款同意记录：年满14周岁确认、是否同意使用条款及个人信息的收集和使用、同意的条款版本及同意时间（注册时由用户选择）\n'
          '• 个人资料：昵称、头像（可选）、已拥有的游戏信息（由用户输入或选择）\n'
          '• 游戏使用（房间）：房间代码、房间内使用的昵称和角色图标、连接状态及最后连接时间、游戏进行信息（使用服务时自动生成）\n'
          '• 错误与故障处理：错误报告（应用错误信息、设备型号与操作系统版本、会员标识）、服务器处理记录（会员标识、房间代码、处理结果）（使用服务时自动生成或收集）\n'
          '• 应用完整性检查：用于检查应用是否被篡改及设备完整性的信号（由 Google Firebase App Check 自动检查）\n'
          '设备上会保存用于重新加入房间的识别信息、邮箱验证等待信息以及语言和声音设置。这些信息仅保存在用户设备上，不会发送到运营方服务器。\n'
          '服务不收集位置信息，也不收集用于广告或个性化服务的行为信息。',
    ),
    (
      '2. 个人信息的使用目的',
      '1. 确认注册意愿、识别与验证本人、管理会员\n'
          '2. 提供创建与加入房间、进行游戏等服务\n'
          '3. 提供游戏环境，例如向同一房间的参与者显示昵称\n'
          '4. 分析错误与稳定服务、防止应用篡改和异常访问\n'
          '5. 处理用户咨询与投诉、对违反条款的行为采取措施以及发送公告和通知',
    ),
    (
      '3. 个人信息的保存与使用期间',
      '运营方在达成个人信息收集和使用目的后立即销毁。保存期间如下：\n'
          '• 会员信息（邮箱、昵称、头像等）：保存至删除账号时。删除账号后立即删除。\n'
          '• 游客信息（临时账号标识、自动昵称、同意记录）：保存至游客删除账号时。删除账号后立即删除。游客退出登录或删除应用后将无法再次登录，如需删除信息，请在退出登录前删除账号。其他删除请求可通过第11项的联系方式提出。\n'
          '• 未完成注册的信息：未完成注册时，保存注册进度信息（会员标识、登录方式、进度状态），用户要求删除时立即删除。\n'
          '• 房间与游戏进行信息：房主关闭房间约1分钟后，或游戏已结束、连接已中断的房间在最后一次活动15分钟后自动删除。游戏记录不另行保存。\n'
          '• 错误报告与服务器处理记录：仅在服务提供方的默认保存期间内保存（Firebase Crashlytics 约90天，Google Cloud Logging 默认30天）。\n'
          '依法需要保存的信息，将在相关法律规定的期间内保存。',
    ),
    ('4. 向第三方提供个人信息', '运营方不向第三方提供用户的个人信息。但有法律依据或调查机关依法定程序要求时除外。'),
    (
      '5. 委托处理与境外传输',
      '为提供服务，我们使用下列公司的服务，在此过程中个人信息可能被处理或传输至境外。\n'
          '• Google LLC（Firebase：认证、Firestore、Realtime Database、Storage、Cloud Functions、App Check、Crashlytics）\n'
          '  - 项目：第1项所列全部收集项目\n'
          '  - 目的：会员认证、数据存储、游戏服务器运行、应用完整性检查、错误报告\n'
          '  - 国家：新加坡（Realtime Database）、美国（Storage、认证、错误报告）。Firestore 和服务器功能位于首尔。\n'
          '  - 时间与方式：使用服务时通过网络（加密通信）随时传输\n'
          '  - 期间：与第3项的保存期间相同\n'
          '• Google LLC（Google 登录）、Apple Inc.（Apple 登录）\n'
          '  - 项目：社交登录认证信息、电子邮箱\n'
          '  - 目的：社交登录认证\n'
          '  - 国家：美国\n'
          '  - 时间与方式：登录时通过网络（加密通信）传输\n'
          '  - 期间：依各公司的政策\n'
          '• Shorebird\n'
          '  - 项目：应用版本信息、IP 地址等检查应用修复所需的技术信息\n'
          '  - 目的：发布应用修复\n'
          '  - 国家：美国\n'
          '  - 时间与方式：启动应用时通过网络（加密通信）传输\n'
          '  - 期间：依该公司的政策\n'
          '用户可以拒绝境外传输，但拒绝后将难以注册和使用服务。如不希望境外传输，请通过第11项的联系方式咨询。',
    ),
    (
      '6. 个人信息的销毁程序与方法',
      '1. 销毁程序：超过保存期间或已达成处理目的的个人信息将立即销毁。依法需要保存的信息将另行分开保存，期满后销毁。\n'
          '2. 销毁方法：电子文件形式的信息以无法恢复的方式删除。\n'
          '3. 会员删除账号时，将删除会员账号、资料信息和头像，并结束会员担任房主的房间。使用 Apple 账号注册的会员删除账号时需重新验证 Apple 账号，并解除关联。',
    ),
    (
      '7. 用户的权利与行使方式',
      '1. 用户可随时查阅、更正、删除自己的个人信息或要求停止处理，并可撤回对个人信息收集和使用的同意。\n'
          '2. 昵称和头像可在设置页面直接修改，删除账号可在服务内［我的资料 > 删除账号］菜单进行。游客也可使用同一菜单。\n'
          '3. 无法使用应用时，可在账号删除说明页面（https://project0000-ec01e.web.app/account-deletion/）查看删除方法并提出申请。\n'
          '4. 其他请求请通过第11项的联系方式提出。运营方在确认本人身份后立即处理，并告知处理结果。\n'
          '5. 法定代理人可就未满14周岁儿童的个人信息行使上述权利。\n'
          '6. 用户可以拒绝同意个人信息的收集和使用，但不同意必选项目时，注册和使用服务将受到限制。',
    ),
    (
      '8. 未满14周岁儿童的个人信息',
      '仅年满14周岁者可以注册会员或以游客身份开始，服务不收集未满14周岁儿童的个人信息。发现未满14周岁者注册时，将立即删除该账号及个人信息。',
    ),
    (
      '9. 自动收集装置与设备权限',
      '1. 服务为移动应用，不使用网页 Cookie。房间重连识别信息和设置保存在设备内部存储中，删除应用时一并删除。\n'
          '2. 相机：仅在识别房间二维码时使用，不保存拍摄画面，也不发送至服务器。\n'
          '3. 相册：仅在选择头像时访问用户选择的照片。\n'
          '4. 不访问位置信息。\n'
          '5. 用户可随时在设备设置中允许或拒绝上述权限。拒绝后将无法使用相应功能（二维码加入、设置头像）。',
    ),
    (
      '10. 个人信息安全保障措施',
      '1. 访问控制：通过数据库和存储的安全规则，限制为仅能访问本人信息；游戏规则和胜负判定在服务器处理。\n'
          '2. 传输保护：服务与服务器之间的通信使用加密通信（HTTPS）。\n'
          '3. 最少收集：仅收集提供服务所需的信息，不收集支付信息和位置信息。\n'
          '4. 访问权限管理：将处理个人信息的人员限制在最少范围。',
    ),
    (
      '11. 个人信息保护负责人及联系方式',
      '运营方为统筹个人信息处理事务、处理用户咨询和投诉，指定以下个人信息保护负责人。\n'
          '• 个人信息保护负责人：尹裕元（代表）\n'
          '• 邮箱：warmhandongne@gmail.com\n'
          '• 地址：韩国庆尚北道浦项市北区韩东路558 韩东大学',
    ),
    (
      '12. 权益侵害救济方法',
      '如需个人信息侵害的救济或咨询，可联系以下韩国机构：\n'
          '• 个人信息纠纷调解委员会：1833-6972（www.kopico.go.kr）\n'
          '• 个人信息侵害举报中心：118（privacy.kisa.or.kr）\n'
          '• 大检察厅网络调查科：1301（www.spo.go.kr）\n'
          '• 警察厅网络调查局：182（ecrm.police.go.kr）',
    ),
    (
      '13. 隐私政策的变更',
      '变更本政策时，将自施行日前7天起在服务内公告变更内容和施行日。收集项目或使用目的发生变化等对用户重要的变更，将自施行日前30天起公告，必要时重新征得同意。',
    ),
    ('附则', '本政策自2026年10月12日起施行。'),
  ],
);

const _privacyPolicyZhHant = LegalDocument(
  title: 'Mosigame 隱私權政策',
  effectiveDate: '2026-10-12',
  intro:
      '溫暖社區（以下簡稱「營運方」）在提供「Mosigame」服務（以下簡稱「服務」）時，依照韓國《個人資訊保護法》等相關法律保護使用者的個人資訊，併為迅速處理相關投訴，制定本隱私權政策。\n'
      '本文為譯文。如與韓文版本不一致，以韓文版本為準。',
  sections: [
    (
      '1. 收集的個人資訊項目與收集方式',
      '只有註冊會員或以遊客身份開始的使用者可以使用服務，服務僅收集提供服務所需的最少個人資訊。\n'
          '• 註冊與登入：電子郵件信箱、密碼（電子郵件信箱註冊時）、社交登入提供方（Google、Apple）及帳號標識（註冊時由使用者輸入或透過 Google、Apple 登入提供）\n'
          '• 遊客開始：臨時帳號標識、自動生成的暱稱（例：遊客a1b2c3）。不收集電子郵件信箱、密碼或社交帳號資訊。（選擇［以遊客身份開始］時自動生成）\n'
          '• 社交登入資料：Google 帳號名稱和頭像地址（URL）、Apple 帳號名稱（使用者提供時）。用作暱稱和頭像的初始值，使用者可以修改。（Google、Apple 登入時由該公司提供）\n'
          '• 條款同意記錄：年滿14週歲確認、是否同意使用條款及個人資訊的收集和使用、同意的條款版本及同意時間（註冊時由使用者選擇）\n'
          '• 個人資料：暱稱、頭像（可選）、已擁有的遊戲資訊（由使用者輸入或選擇）\n'
          '• 遊戲使用（房間）：房間代碼、房間內使用的暱稱和角色圖示、連線狀態及最後連線時間、遊戲進行資訊（使用服務時自動生成）\n'
          '• 錯誤與故障處理：錯誤報告（應用錯誤資訊、裝置型號與作業系統版本、會員標識）、伺服器處理記錄（會員標識、房間代碼、處理結果）（使用服務時自動生成或收集）\n'
          '• 應用完整性檢查：用於檢查應用是否被篡改及裝置完整性的訊號（由 Google Firebase App Check 自動檢查）\n'
          '裝置上會儲存用於重新加入房間的識別資訊、電子郵件信箱驗證等待資訊以及語言和聲音設定。這些資訊僅儲存在使用者裝置上，不會傳送到營運方伺服器。\n'
          '服務不收集位置資訊，也不收集用於廣告或個性化服務的行為資訊。',
    ),
    (
      '2. 個人資訊的使用目的',
      '1. 確認註冊意願、識別與驗證本人、管理會員\n'
          '2. 提供建立與加入房間、進行遊戲等服務\n'
          '3. 提供遊戲環境，例如向同一房間的參與者顯示暱稱\n'
          '4. 分析錯誤與穩定服務、防止應用篡改和異常存取\n'
          '5. 處理使用者諮詢與投訴、對違反條款的行為採取措施以及傳送公告和通知',
    ),
    (
      '3. 個人資訊的儲存與使用期間',
      '營運方在達成個人資訊收集和使用目的後立即銷燬。儲存期間如下：\n'
          '• 會員資訊（電子郵件信箱、暱稱、頭像等）：儲存至刪除帳號時。刪除帳號後立即刪除。\n'
          '• 遊客資訊（臨時帳號標識、自動暱稱、同意記錄）：儲存至遊客刪除帳號時。刪除帳號後立即刪除。遊客退出登入或刪除應用後將無法再次登入，如需刪除資訊，請在退出登入前刪除帳號。其他刪除請求可透過第11項的聯絡方式提出。\n'
          '• 未完成註冊的資訊：未完成註冊時，儲存註冊進度資訊（會員標識、登入方式、進度狀態），使用者要求刪除時立即刪除。\n'
          '• 房間與遊戲進行資訊：房主關閉房間約1分鐘後，或遊戲已結束、連線已中斷的房間在最後一次活動15分鐘後自動刪除。遊戲記錄不另行儲存。\n'
          '• 錯誤報告與伺服器處理記錄：僅在服務提供方的預設儲存期間內儲存（Firebase Crashlytics 約90天，Google Cloud Logging 預設30天）。\n'
          '依法需要儲存的資訊，將在相關法律規定的期間內儲存。',
    ),
    ('4. 向第三方提供個人資訊', '營運方不向第三方提供使用者的個人資訊。但有法律依據或調查機關依法定程式要求時除外。'),
    (
      '5. 委託處理與境外傳輸',
      '為提供服務，我們使用下列公司的服務，在此過程中個人資訊可能被處理或傳輸至境外。\n'
          '• Google LLC（Firebase：認證、Firestore、Realtime Database、Storage、Cloud Functions、App Check、Crashlytics）\n'
          '  - 項目：第1項所列全部收集項目\n'
          '  - 目的：會員認證、資料儲存、遊戲伺服器執行、應用完整性檢查、錯誤報告\n'
          '  - 國家：新加坡（Realtime Database）、美國（Storage、認證、錯誤報告）。Firestore 和伺服器功能位於首爾。\n'
          '  - 時間與方式：使用服務時透過網路（加密通訊）隨時傳輸\n'
          '  - 期間：與第3項的儲存期間相同\n'
          '• Google LLC（Google 登入）、Apple Inc.（Apple 登入）\n'
          '  - 項目：社交登入認證資訊、電子郵件信箱\n'
          '  - 目的：社交登入認證\n'
          '  - 國家：美國\n'
          '  - 時間與方式：登入時透過網路（加密通訊）傳輸\n'
          '  - 期間：依各公司的政策\n'
          '• Shorebird\n'
          '  - 項目：應用版本資訊、IP 地址等檢查應用修復所需的技術資訊\n'
          '  - 目的：釋出應用修復\n'
          '  - 國家：美國\n'
          '  - 時間與方式：啟動應用時透過網路（加密通訊）傳輸\n'
          '  - 期間：依該公司的政策\n'
          '使用者可以拒絕境外傳輸，但拒絕後將難以註冊和使用服務。如不希望境外傳輸，請透過第11項的聯絡方式諮詢。',
    ),
    (
      '6. 個人資訊的銷燬程式與方法',
      '1. 銷燬程式：超過儲存期間或已達成處理目的的個人資訊將立即銷燬。依法需要儲存的資訊將另行分開儲存，期滿後銷燬。\n'
          '2. 銷燬方法：電子檔案形式的資訊以無法恢復的方式刪除。\n'
          '3. 會員刪除帳號時，將刪除會員帳號、資料資訊和頭像，並結束會員擔任房主的房間。使用 Apple 帳號註冊的會員刪除帳號時需重新驗證 Apple 帳號，並解除關聯。',
    ),
    (
      '7. 使用者的權利與行使方式',
      '1. 使用者可隨時查閱、更正、刪除自己的個人資訊或要求停止處理，並可撤回對個人資訊收集和使用的同意。\n'
          '2. 暱稱和頭像可在設定頁面直接修改，刪除帳號可在服務內［我的資料 > 刪除帳號］選單進行。遊客也可使用同一選單。\n'
          '3. 無法使用應用時，可在帳號刪除說明頁面（https://project0000-ec01e.web.app/account-deletion/）檢視刪除方法並提出申請。\n'
          '4. 其他請求請透過第11項的聯絡方式提出。營運方在確認本人身份後立即處理，並告知處理結果。\n'
          '5. 法定代理人可就未滿14週歲兒童的個人資訊行使上述權利。\n'
          '6. 使用者可以拒絕同意個人資訊的收集和使用，但不同意必選項目時，註冊和使用服務將受到限制。',
    ),
    (
      '8. 未滿14週歲兒童的個人資訊',
      '僅年滿14週歲者可以註冊會員或以遊客身份開始，服務不收集未滿14週歲兒童的個人資訊。發現未滿14週歲者註冊時，將立即刪除該帳號及個人資訊。',
    ),
    (
      '9. 自動收集裝置與裝置許可權',
      '1. 服務為行動應用程式，不使用網頁 Cookie。房間重連識別資訊和設定儲存在裝置內部儲存中，刪除應用時一併刪除。\n'
          '2. 相機：僅在識別房間QR Code時使用，不儲存拍攝畫面，也不傳送至伺服器。\n'
          '3. 相簿：僅在選擇頭像時存取使用者選擇的照片。\n'
          '4. 不存取位置資訊。\n'
          '5. 使用者可隨時在裝置設定中允許或拒絕上述許可權。拒絕後將無法使用相應功能（QR Code加入、設定頭像）。',
    ),
    (
      '10. 個人資訊保安保障措施',
      '1. 存取控制：透過資料庫和儲存的安全規則，限制為僅能存取本人資訊；遊戲規則和勝負判定在伺服器處理。\n'
          '2. 傳輸保護：服務與伺服器之間的通訊使用加密通訊（HTTPS）。\n'
          '3. 最少收集：僅收集提供服務所需的資訊，不收集支付資訊和位置資訊。\n'
          '4. 存取許可權管理：將處理個人資訊的人員限制在最少範圍。',
    ),
    (
      '11. 個人資訊保護負責人及聯絡方式',
      '營運方為統籌個人資訊處理事務、處理使用者諮詢和投訴，指定以下個人資訊保護負責人。\n'
          '• 個人資訊保護負責人：尹裕元（代表）\n'
          '• 電子郵件信箱：warmhandongne@gmail.com\n'
          '• 地址：韓國慶尚北道浦項市北區韓東路558 韓東大學',
    ),
    (
      '12. 權益侵害救濟方法',
      '如需個人資訊侵害的救濟或諮詢，可聯絡以下韓國機構：\n'
          '• 個人資訊糾紛調解委員會：1833-6972（www.kopico.go.kr）\n'
          '• 個人資訊侵害舉報中心：118（privacy.kisa.or.kr）\n'
          '• 大檢察廳網路調查科：1301（www.spo.go.kr）\n'
          '• 警察廳網路調查局：182（ecrm.police.go.kr）',
    ),
    (
      '13. 隱私權政策的變更',
      '變更本政策時，將自施行日前7天起在服務內公告變更內容和施行日。收集項目或使用目的發生變化等對使用者重要的變更，將自施行日前30天起公告，必要時重新徵得同意。',
    ),
    ('附則', '本政策自2026年10月12日起施行。'),
  ],
);
