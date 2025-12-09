import 'dart:math' as math;

/// Moon phases based on the lunar cycle
enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

/// Service for calculating moon phases
/// Uses the synodic month algorithm (no API needed)
class MoonPhaseService {
  /// Average length of a synodic month in days
  static const double _synodicMonth = 29.53058867;
  
  /// Known new moon reference date (January 6, 2000 at 18:14 UTC)
  static final DateTime _referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  /// Get the moon phase for a specific date
  static MoonPhase getPhaseForDate(DateTime date) {
    final daysSinceNew = _getDaysSinceNewMoon(date);
    final phaseIndex = ((daysSinceNew / _synodicMonth) * 8).floor() % 8;
    return MoonPhase.values[phaseIndex];
  }

  /// Get the percentage of moon illumination (0-100)
  static double getIlluminationPercent(DateTime date) {
    final daysSinceNew = _getDaysSinceNewMoon(date);
    final phaseAngle = (daysSinceNew / _synodicMonth) * 2 * math.pi;
    // Illumination follows a cosine curve
    return ((1 - math.cos(phaseAngle)) / 2) * 100;
  }

  /// Get emoji representation of the moon phase
  static String getPhaseEmoji(MoonPhase phase) {
    switch (phase) {
      case MoonPhase.newMoon: return '🌑';
      case MoonPhase.waxingCrescent: return '🌒';
      case MoonPhase.firstQuarter: return '🌓';
      case MoonPhase.waxingGibbous: return '🌔';
      case MoonPhase.fullMoon: return '🌕';
      case MoonPhase.waningGibbous: return '🌖';
      case MoonPhase.lastQuarter: return '🌗';
      case MoonPhase.waningCrescent: return '🌘';
    }
  }

  /// Get human-readable name of the phase
  static String getPhaseName(MoonPhase phase) {
    switch (phase) {
      case MoonPhase.newMoon: return 'New Moon';
      case MoonPhase.waxingCrescent: return 'Waxing Crescent';
      case MoonPhase.firstQuarter: return 'First Quarter';
      case MoonPhase.waxingGibbous: return 'Waxing Gibbous';
      case MoonPhase.fullMoon: return 'Full Moon';
      case MoonPhase.waningGibbous: return 'Waning Gibbous';
      case MoonPhase.lastQuarter: return 'Last Quarter';
      case MoonPhase.waningCrescent: return 'Waning Crescent';
    }
  }

  /// Get a brief description of the phase's significance
  static String getPhaseDescription(MoonPhase phase) {
    switch (phase) {
      case MoonPhase.newMoon: 
        return 'Time for new beginnings and setting intentions';
      case MoonPhase.waxingCrescent: 
        return 'Building momentum, taking action on goals';
      case MoonPhase.firstQuarter: 
        return 'Challenges and decisions, time to commit';
      case MoonPhase.waxingGibbous: 
        return 'Refining and adjusting, almost there';
      case MoonPhase.fullMoon: 
        return 'Peak energy, manifestation, and illumination';
      case MoonPhase.waningGibbous: 
        return 'Gratitude and sharing what you\'ve learned';
      case MoonPhase.lastQuarter: 
        return 'Release and letting go, forgiveness';
      case MoonPhase.waningCrescent: 
        return 'Rest, reflection, and surrender';
    }
  }

  /// Get days until the next occurrence of a specific phase
  static int daysUntilPhase(MoonPhase targetPhase) {
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.add(Duration(days: i));
      if (getPhaseForDate(date) == targetPhase) {
        return i;
      }
    }
    return -1;
  }

  /// Get the next full moon date
  static DateTime? getNextFullMoon() {
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.add(Duration(days: i));
      if (getPhaseForDate(date) == MoonPhase.fullMoon) {
        return date;
      }
    }
    return null;
  }

  /// Get formatted moon info for display
  static String getMoonInfo(DateTime date) {
    final phase = getPhaseForDate(date);
    final emoji = getPhaseEmoji(phase);
    final name = getPhaseName(phase);
    final illumination = getIlluminationPercent(date).round();
    return '$emoji $name ($illumination% illuminated)';
  }

  /// Calculate days since the reference new moon
  static double _getDaysSinceNewMoon(DateTime date) {
    final utcDate = date.toUtc();
    final difference = utcDate.difference(_referenceNewMoon);
    return difference.inSeconds / 86400.0;
  }

  /// Get moon summary for AI context
  static String getMoonSummary() {
    final now = DateTime.now();
    final phase = getPhaseForDate(now);
    final emoji = getPhaseEmoji(phase);
    final name = getPhaseName(phase);
    final description = getPhaseDescription(phase);
    
    final buffer = StringBuffer();
    buffer.writeln('[MOON PHASE]');
    buffer.writeln('$emoji $name');
    buffer.writeln('Significance: $description');
    
    final nextFull = getNextFullMoon();
    if (nextFull != null && phase != MoonPhase.fullMoon) {
      final daysUntil = nextFull.difference(now).inDays;
      buffer.writeln('Next full moon in $daysUntil days');
    }
    
    buffer.writeln('[END MOON PHASE]');
    return buffer.toString();
  }
}
