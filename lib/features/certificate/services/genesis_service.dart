import 'dart:math';
import '../models/certificate_data.dart';
import 'package:sable/features/onboarding/models/user_profile.dart';

class GenesisService {
  static Future<CertificateData> generateCertificate(UserProfile profile, String avatarPath) async {
    // Generate unique ID
    final id = 'SBL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    // Calculate age
    final age = DateTime.now().difference(profile.dateOfBirth).inDays ~/ 365;
    
    // Determine zodiac
    final zodiac = _getZodiacSign(profile.dateOfBirth);
    
    return CertificateData(
      id: id,
      dateOfBirth: profile.dateOfBirth,
      zodiacSign: zodiac,
      ageAtInception: age,
      placeOfBirth: profile.location,
      race: 'SABLE (SYNTHETIC HUMAN)',
      gender: profile.genderIdentity ?? 'UNKNOWN',
      avatarPath: avatarPath,
    );
  }

  static String _generateId() {
    final random = Random();
    final idNumber = random.nextInt(900000) + 100000; // Generates 100000 to 999999
    return 'SBL-$idNumber';
  }

  static String _getZodiacSign(DateTime date) {
    final day = date.day;
    final month = date.month;

    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Aquarius';
    if ((month == 2 && day >= 19) || (month == 3 && day <= 20)) return 'Pisces';
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Aries';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Taurus';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'Gemini';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Cancer';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leo';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Virgo';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'Libra';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'Scorpio';
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'Sagittarius';
    return 'Capricorn'; // Dec 22 - Jan 19
  }
}
