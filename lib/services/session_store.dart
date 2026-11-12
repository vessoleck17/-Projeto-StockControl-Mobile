import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'stockcontrol.jwt';
  static const String _expiresAtKey = 'stockcontrol.expiresAtUtc';

  /// Salva o token e a data de expiração da sessão.
  Future<void> saveSession({
    required String token,
    required String expiresAtUtc,
  }) async {
    await _storage.write(key: _tokenKey, value: token);

    await _storage.write(key: _expiresAtKey, value: expiresAtUtc);
  }

  /// Recupera o token JWT armazenado.
  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Recupera a data de expiração da sessão.
  Future<String?> readExpiresAtUtc() async {
    return _storage.read(key: _expiresAtKey);
  }

  /// Verifica se há uma sessão com token ainda válido pelo prazo.
  ///
  /// Esta verificação considera a data de expiração. A API continua
  /// sendo responsável por validar a assinatura e as permissões do JWT.
  Future<bool> hasValidSession() async {
    final token = await readToken();
    final expiresAt = await readExpiresAtUtc();

    if (token == null || token.isEmpty || expiresAt == null) {
      return false;
    }

    final expirationDate = DateTime.tryParse(expiresAt);

    if (expirationDate == null) {
      return false;
    }

    return expirationDate.isAfter(DateTime.now().toUtc());
  }

  /// Remove os dados da sessão ao sair do aplicativo.
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
