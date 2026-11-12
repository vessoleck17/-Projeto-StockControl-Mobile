
/// Configurações centrais da API do StockControl Mobile.
class AppConfig {
  /// Desativa os dados demonstrativos.
  static const bool demoMode = false;

  /// Endereço da API.
  ///
  /// Padrão: localhost na porta 5080.
  /// Pode ser alterado sem editar o arquivo usando --dart-define.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );
}
