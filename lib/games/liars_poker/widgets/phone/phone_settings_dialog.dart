import 'package:flutter/material.dart';

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
            color: Color(0x99000000),
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '설정',
            style: TextStyle(
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
            color: Color(0x99000000),
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
                child: const Text(
                  '설정',
                  style: TextStyle(
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
        const Text(
          '화면',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildCheckbox('가로모드 고정', _lockLandscape, (val) {
          setState(() => _lockLandscape = val ?? false);
        }),
        _buildCheckbox('전체화면', _fullScreen, (val) {
          setState(() => _fullScreen = val ?? false);
        }),
      ],
    );
  }

  Widget _buildSoundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '소리',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildVolumeSlider('BGM', _bgmVolume, (val) {
          setState(() => _bgmVolume = val);
        }),
        _buildVolumeSlider('효과음', _sfxVolume, (val) {
          setState(() => _sfxVolume = val);
        }),
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
          shadowColor: const Color(0x99000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          '닫기',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
