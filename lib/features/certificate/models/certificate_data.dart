import 'package:intl/intl.dart';

class CertificateData {
  final String id;
  final DateTime dateOfBirth;
  final String zodiacSign;
  final int ageAtInception;
  final String placeOfBirth;
  final String race;
  final String gender;

  CertificateData({
    required this.id,
    required this.dateOfBirth,
    required this.zodiacSign,
    required this.ageAtInception,
    required this.placeOfBirth,
    required this.race,
    required this.gender,
    required this.avatarPath,
  });

  final String avatarPath;

  String get formattedDob => DateFormat('MMMM d, yyyy').format(dateOfBirth);
}
