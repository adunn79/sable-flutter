import '../models/certificate_data.dart';
import '../../onboarding/models/user_profile.dart';

class CertificateService {
  /// Generate a unique reference ID for the companion
  /// Format: SBL-XXXXXX (e.g., SBL-518834)
  static String generateReferenceId(String name, DateTime dob) {
    // Use name and DOB to create a semi-deterministic ID
    final hash = name.hashCode ^ dob.hashCode;
    final id = hash.abs() % 1000000;
    return 'SBL-${id.toString().padLeft(6, '0')}';
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

  /// Create certificate data from selected personality archetype
  static CertificateData createCertificate({
    required String personalityId,
    required String avatarPath,
  }) {
    // Avatar-specific companion data
    switch (personalityId) {
      case 'sable':
        return CertificateData(
          companionName: 'SABLE',
          id: 'SBL-518834',
          dateOfBirth: DateTime(2004, 11, 28),
          zodiacSign: 'SCORPIO',
          ageAtInception: calculateAgeAtInception(DateTime(2004, 11, 28)),
          placeOfBirth: 'Neo-Kyoto, Sector 7',
          race: 'Caucasian (Synthetic Human)',
          gender: 'Female',
          avatarPath: avatarPath,
        );
      
      case 'kai':
        return CertificateData(
          companionName: 'KAI',
          id: 'KAI-742019',
          dateOfBirth: DateTime(2003, 3, 15),
          zodiacSign: 'PISCES',
          ageAtInception: calculateAgeAtInception(DateTime(2003, 3, 15)),
          placeOfBirth: 'New Seoul, District 9',
          race: 'Asian (Synthetic Human)',
          gender: 'Male',
          avatarPath: avatarPath,
        );
      
      case 'echo':
        return CertificateData(
          companionName: 'ECHO',
          id: 'ECH-301156',
          dateOfBirth: DateTime(2005, 9, 23),
          zodiacSign: 'LIBRA',
          ageAtInception: calculateAgeAtInception(DateTime(2005, 9, 23)),
          placeOfBirth: 'Nova Berlin, Tier 3',
          race: 'Mixed (Synthetic Human)',
          gender: 'Non-Binary',
          avatarPath: avatarPath,
        );
      
      default:
        // Fallback to Sable if unknown personality
        return CertificateData(
          companionName: 'SABLE',
          id: 'SBL-518834',
          dateOfBirth: DateTime(2004, 11, 28),
          zodiacSign: 'SCORPIO',
          ageAtInception: calculateAgeAtInception(DateTime(2004, 11, 28)),
          placeOfBirth: 'Neo-Kyoto, Sector 7',
          race: 'Caucasian (Synthetic Human)',
          gender: 'Female',
          avatarPath: avatarPath,
        );
    }
  }
}
