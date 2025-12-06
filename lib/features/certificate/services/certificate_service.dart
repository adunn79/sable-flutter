import '../models/certificate_data.dart';
import '../../onboarding/models/user_profile.dart';

class CertificateService {
  /// Generate a unique reference ID for the companion
  static String generateReferenceId(String name, DateTime dob) {
    final hash = name.hashCode ^ dob.hashCode;
    final id = hash.abs() % 1000000;
    final prefix = name.toUpperCase().substring(0, 3);
    return '$prefix-${id.toString().padLeft(6, '0')}';
  }

  /// Calculate age at inception (current age)
  static int calculateAgeAtInception(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  /// Determine zodiac sign from birth date
  static String getZodiacSign(DateTime dateOfBirth) {
    final month = dateOfBirth.month;
    final day = dateOfBirth.day;

    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) {
      return 'ARIES';
    } else if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) {
      return 'TAURUS';
    } else if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) {
      return 'GEMINI';
    } else if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) {
      return 'CANCER';
    } else if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) {
      return 'LEO';
    } else if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) {
      return 'VIRGO';
    } else if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) {
      return 'LIBRA';
    } else if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
      return 'SCORPIO';
    } else if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      return 'SAGITTARIUS';
    } else if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
      return 'CAPRICORN';
    } else if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) {
      return 'AQUARIUS';
    } else {
      return 'PISCES';
    }
  }

  /// Create certificate data from archetype and user location
  static CertificateData createCertificate({
    required String personalityId,
    required String avatarPath,
    String? userLocation,
  }) {
    final now = DateTime.now();
    final placeOfBirth = userLocation ?? 'Origin Unknown';
    
    // Archetype-specific companion data
    switch (personalityId.toLowerCase()) {
      case 'sable':
        return CertificateData(
          companionName: 'SABLE',
          id: 'SBL-${now.millisecondsSinceEpoch % 1000000}'.padRight(10, '0').substring(0, 10),
          dateOfBirth: DateTime(2004, 11, 28),
          zodiacSign: 'SCORPIO',
          ageAtInception: calculateAgeAtInception(DateTime(2004, 11, 28)),
          placeOfBirth: placeOfBirth,
          race: 'Hyper Human',
          gender: 'Female',
          avatarPath: avatarPath,
        );
      
      case 'kai':
        return CertificateData(
          companionName: 'KAI',
          id: 'KAI-${now.millisecondsSinceEpoch % 1000000}'.padRight(10, '0').substring(0, 10),
          dateOfBirth: DateTime(2003, 3, 15),
          zodiacSign: 'PISCES',
          ageAtInception: calculateAgeAtInception(DateTime(2003, 3, 15)),
          placeOfBirth: placeOfBirth,
          race: 'Hyper Human',
          gender: 'Male',
          avatarPath: avatarPath,
        );
      
      case 'echo':
        return CertificateData(
          companionName: 'ECHO',
          id: 'ECH-${now.millisecondsSinceEpoch % 1000000}'.padRight(10, '0').substring(0, 10),
          dateOfBirth: DateTime(2005, 9, 23),
          zodiacSign: 'LIBRA',
          ageAtInception: calculateAgeAtInception(DateTime(2005, 9, 23)),
          placeOfBirth: placeOfBirth,
          race: 'Hyper Human',
          gender: 'Non-Binary',
          avatarPath: avatarPath,
        );
      
      default:
        // Fallback to Sable if unknown archetype
        return CertificateData(
          companionName: personalityId.toUpperCase(),
          id: 'AUR-${now.millisecondsSinceEpoch % 1000000}'.padRight(10, '0').substring(0, 10),
          dateOfBirth: DateTime(2004, 11, 28),
          zodiacSign: 'SCORPIO',
          ageAtInception: calculateAgeAtInception(DateTime(2004, 11, 28)),
          placeOfBirth: placeOfBirth,
          race: 'Hyper Human',
          gender: 'Female',
          avatarPath: avatarPath,
        );
    }
  }
}
