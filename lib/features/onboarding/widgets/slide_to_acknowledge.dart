import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';

class SlideToAcknowledge extends StatefulWidget {
  final VoidCallback onAcknowledged;
  final bool isAcknowledged;

  const SlideToAcknowledge({
    super.key,
    required this.onAcknowledged,
    required this.isAcknowledged,
  });

  @override
  State<SlideToAcknowledge> createState() => _SlideToAcknowledgeState();
}

class _SlideToAcknowledgeState extends State<SlideToAcknowledge> {
  double _sliderValue = 0.0;
  bool _isCompleted = false;

  void _handleSliderChange(double value) {
    setState(() {
      _sliderValue = value;
      if (value >= 0.95 && !_isCompleted) {
        _isCompleted = true;
        widget.onAcknowledged();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AurealColors.carbon,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _isCompleted
              ? AurealColors.hyperGold
              : AurealColors.plasmaCyan.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, _sliderValue, _sliderValue, 1.0],
                colors: [
                  AurealColors.plasmaCyan.withOpacity(0.2),
                  AurealColors.plasmaCyan.withOpacity(0.2),
                  Colors.transparent,
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Slider
          Positioned.fill(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 60,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 25),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 30),
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: _isCompleted
                    ? AurealColors.hyperGold
                    : AurealColors.plasmaCyan,
                overlayColor: AurealColors.plasmaCyan.withOpacity(0.2),
              ),
              child: Slider(
                value: _sliderValue,
                onChanged: _isCompleted ? null : _handleSliderChange,
                min: 0.0,
                max: 1.0,
              ),
            ),
          ),

          // Label
          Positioned.fill(
            child: Center(
              child: IgnorePointer(
                child: Text(
                  _isCompleted ? 'ACKNOWLEDGED' : 'SLIDE TO ACKNOWLEDGE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isCompleted
                        ? AurealColors.hyperGold
                        : AurealColors.stardust.withOpacity(0.6),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
