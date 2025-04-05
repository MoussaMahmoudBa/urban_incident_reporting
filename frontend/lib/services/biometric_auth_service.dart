import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:developer';
import 'package:http/http.dart' as http; // Ajouté
import 'dart:convert'; // Ajouté
import '../services/auth_service.dart'; // Ajouté


class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isBiometricAvailable() async {
    try {
      if (kIsWeb) return false;
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      if (kDebugMode) {
        log('Mode debug: simulation de la biométrie');
        await Future.delayed(const Duration(seconds: 10));
        return true;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Vérifiez votre identité',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      log('Erreur biométrique (${e.code}): ${e.message}');
      return false;
    }
  }

  Future<String?> generateBiometricToken() async {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> storeBiometricToken(String token) async {
    await _storage.write(key: 'biometric_token', value: token);
  }

  Future<String?> getBiometricToken() async {
    return await _storage.read(key: 'biometric_token');
  }

  Future<void> registerBiometric() async {
    try {
      final token = await generateBiometricToken();
      await storeBiometricToken(token!);
      
      final accessToken = await AuthService.getAccessToken();
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}users/register-biometric/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'biometric_token': token}),
      );

      if (response.statusCode != 200) {
        throw Exception('Échec de l\'enregistrement biométrique');
      }
    } catch (e) {
      log('Erreur enregistrement biométrique: $e');
      rethrow;
    }
  }
}