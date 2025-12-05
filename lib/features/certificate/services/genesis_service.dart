import '../models/certificate_data.dart';
import 'certificate_service.dart';

class GenesisService {
  static Future<CertificateData> generateCertificate(
    String personalityId,
    String avatarPath,
  ) async {
    // Use CertificateService to generate avatar-specific certificate
    return CertificateService.createCertificate(
      personalityId: personalityId,
      avatarPath: avatarPath,
    );
  }
}
