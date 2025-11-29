import 'dart:math';
import '../models/certificate_data.dart';

class GenesisService {
  CertificateData generateCertificate({
    required String race,
    required String gender,
  }) {
    final now = DateTime.now();
    final dateOfBirth = DateTime(now.year - 21, now.month, now.day);
    
    return CertificateData(
      id: _generateId(),
      dateOfBirth: dateOfBirth,
      zodiacSign: _getZodiacSign(dateOfBirth),
      ageAtInception: 21,
      placeOfBirth: 'Neo-Kyoto, Sector 7',
      race: '$race (Synthetic Human)',
      gender: gender,
    );
  }

  String _generateId() {
    final random = Random();
    final idNumber = random.nextInt(900000) + 100000; // Generates 100000 to 999999
    return 'SBL-$idNumber';
  }

  String _getZodiacSign(DateTime date) {
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
