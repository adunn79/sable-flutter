import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/emotion/weather_service.dart';
import 'package:sable/core/emotion/location_service.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:sable/core/theme/aureal_theme.dart';

/// Global weather widget to display in app header
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherCondition? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final location = await LocationService.getCurrentLocationName(apiKey);
      if (location == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final weather = await WeatherService.getWeather(location);
      if (mounted) {
        setState(() {
          _weather = weather;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Weather widget error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getWeatherIcon(WeatherType type) {
    switch (type) {
      case WeatherType.sunny:
      case WeatherType.clear:
        return LucideIcons.sun;
      case WeatherType.partlyCloudy:
        return LucideIcons.cloudSun;
      case WeatherType.cloudy:
      case WeatherType.overcast:
        return LucideIcons.cloud;
      case WeatherType.rainy:
      case WeatherType.drizzle:
        return LucideIcons.cloudRain;
      case WeatherType.storm:
      case WeatherType.thunderstorm:
        return LucideIcons.cloudLightning;
      case WeatherType.snow:
        return LucideIcons.cloudSnow;
      case WeatherType.fog:
      case WeatherType.mist:
        return LucideIcons.cloudFog;
      default:
        return LucideIcons.cloud;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(width: 80, height: 50);
    }

    if (_weather == null) {
      return const SizedBox.shrink();
    }

    final temp = _weather!.temperature.round();
    final high = _weather!.tempHigh?.round();
    final low = _weather!.tempLow?.round();
    final desc = _weather!.description;

    return GestureDetector(
      onTap: () => _fetchWeather(), // Refresh on tap
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Temperature row with icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getWeatherIcon(_weather!.condition),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '$temp°',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Condition description
            Text(
              desc,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // High/Low
            if (high != null && low != null)
              Text(
                'H:$high° L:$low°',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
