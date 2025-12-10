import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/emotion/weather_service.dart';

/// Beautiful weather card for journal entries
class JournalWeatherCard extends StatelessWidget {
  final WeatherCondition weather;
  final bool compact;

  const JournalWeatherCard({
    super.key,
    required this.weather,
    this.compact = false,
  });

  String get _clothingSuggestion {
    final temp = weather.temperature.round();
    final condition = weather.condition;
    
    // Temperature-based suggestions
    if (temp >= 80) {
      if (condition == WeatherType.rain || condition == WeatherType.thunderstorm) {
        return "Light clothes + rain jacket";
      }
      return "Light, breathable clothes";
    } else if (temp >= 70) {
      if (condition == WeatherType.rain || condition == WeatherType.thunderstorm) {
        return "T-shirt + light rain jacket";
      }
      return "T-shirt & shorts/jeans";
    } else if (temp >= 60) {
      if (condition == WeatherType.rain || condition == WeatherType.thunderstorm) {
        return "Long sleeves + waterproof jacket";
      }
      return "Long sleeves + light jacket";
    } else if (temp >= 50) {
      if (condition == WeatherType.rain || condition == WeatherType.thunderstorm) {
        return "Sweater + waterproof coat";
      }
      return "Sweater or light jacket";
    } else if (temp >= 40) {
      if (condition == WeatherType.rain || condition == WeatherType.thunderstorm) {
        return "Warm coat + umbrella";
      }
      return "Warm jacket + layers";
    } else {
      if (condition == WeatherType.snow) {
        return "Heavy coat, gloves, warm hat";
      }
      return "Heavy winter coat + layers";
    }
  }

  String get _weatherEmoji {
    switch (weather.condition) {
      case WeatherType.clear:
        return "☀️";
      case WeatherType.partlyCloudy:
        return "⛅";
      case WeatherType.cloudy:
        return "☁️";
      case WeatherType.rain:
        return "🌧️";
      case WeatherType.thunderstorm:
        return "⛈️";
      case WeatherType.snow:
        return "❄️";
      case WeatherType.fog:
        return "🌫️";
      default:
        return "🌤️";
    }
  }

  Color get _weatherColor {
    switch (weather.condition) {
      case WeatherType.clear:
        return Colors.orange;
      case WeatherType.partlyCloudy:
        return Colors.amber;
      case WeatherType.cloudy:
        return Colors.grey;
      case WeatherType.rain:
      case WeatherType.thunderstorm:
        return Colors.blue;
      case WeatherType.snow:
        return Colors.lightBlue.shade100;
      case WeatherType.fog:
        return Colors.blueGrey;
      default:
        return Colors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _weatherColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _weatherColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_weatherEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${weather.temperature.round()}°F',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  weather.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Full card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _weatherColor.withOpacity(0.2),
            _weatherColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _weatherColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Weather emoji
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _weatherColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_weatherEmoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          // Weather info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${weather.temperature.round()}°F',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (weather.tempHigh != null && weather.tempLow != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'H: ${weather.tempHigh!.round()}° L: ${weather.tempLow!.round()}°',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  weather.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                // "What to wear" suggestion
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _weatherColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👕', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _clothingSuggestion,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _weatherColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
