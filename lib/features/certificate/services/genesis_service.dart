import '../models/certificate_data.dart';
import 'certificate_service.dart';

class GenesisService {
  static Future<CertificateData> generateCertificate(
    String personalityId,
    String avatarPath, {
    String? userLocation,
  }) async {
    // Use CertificateService to generate archetype-specific certificate
    return CertificateService.createCertificate(
      personalityId: personalityId,
      avatarPath: avatarPath,
      userLocation: userLocation,
    );
  }
}
