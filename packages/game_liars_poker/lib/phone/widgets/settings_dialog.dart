// [settings_dialog.dart] 휴대폰 게임의 음악·효과음
// 설정을 변경할 수 있는 라이어스 포커 설정 다이얼로그 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/core/theme/game_shadow_colors.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

class PhoneSettingsDialog extends StatefulWidget {
  const PhoneSettingsDialog({super.key});

  @override
  State<PhoneSettingsDialog> createState() => _PhoneSettingsDialogState();
}

class _PhoneSettingsDialogState extends State<PhoneSettingsDialog> {
  bool _lockLandscape = false;
  bool _fullScreen = false;
  double _bgmVolume = 50.0;
  double _sfxVolume = 50.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.portrait) {
            return _buildPortrait();
          } else {
            return _buildLandscape();
          }
        },
      ),
    );
  }

  Widget _buildPortrait() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: GameShadowColors.strongest,
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            GameLocale.select(
              ko: '설정',
              en: 'Settings',
              zhHans: '设置',
              zhHant: '設定',
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          _buildScreenSection(),
          const SizedBox(height: 24),
          _buildSoundSection(),
          const SizedBox(height: 32),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildLandscape() {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: GameShadowColors.strongest,
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Side: Title
              Container(
                height: 120,
                padding: const EdgeInsets.only(right: 24, left: 8),
                alignment: Alignment.center,
                child: Text(
                  GameLocale.select(
                    ko: '설정',
                    en: 'Settings',
                    zhHans: '设置',
                    zhHant: '設定',
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 120,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Right Side: Settings
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildScreenSection()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildSoundSection()),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          GameLocale.select(
            ko: '화면',
            en: 'Display',
            zhHans: '显示',
            zhHant: '顯示',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildCheckbox(
          GameLocale.select(
            ko: '가로모드 고정',
            en: 'Lock landscape',
            zhHans: '锁定横屏',
            zhHant: '鎖定橫屏',
          ),
          _lockLandscape,
          (val) {
            setState(() => _lockLandscape = val ?? false);
          },
        ),
        _buildCheckbox(
          GameLocale.select(
            ko: '전체화면',
            en: 'Full screen',
            zhHans: '全屏',
            zhHant: '全螢幕',
          ),
          _fullScreen,
          (val) {
            setState(() => _fullScreen = val ?? false);
          },
        ),
      ],
    );
  }

  Widget _buildSoundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          GameLocale.select(ko: '소리', en: 'Sound', zhHans: '声音', zhHant: '聲音'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildVolumeSlider('BGM', _bgmVolume, (val) {
          setState(() => _bgmVolume = val);
        }),
        _buildVolumeSlider(
          GameLocale.select(
            ko: '효과음',
            en: 'Sound effects',
            zhHans: '音效',
            zhHant: '音效',
          ),
          _sfxVolume,
          (val) {
            setState(() => _sfxVolume = val);
          },
        ),
      ],
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          const Icon(Icons.volume_up_outlined, size: 20, color: Colors.black54),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.black,
                inactiveTrackColor: Colors.grey.shade300,
                thumbColor: Colors.black,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 100,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              value.toInt().toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E2E24), // 다크 그린/블랙 색상
          foregroundColor: Colors.white,
          elevation: 9,
          shadowColor: GameShadowColors.strongest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          GameLocale.select(ko: '닫기', en: 'Close', zhHans: '关闭', zhHant: '關閉'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
