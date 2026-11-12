import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';
import 'session_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.sessionStore, http.Client? client})
    : _client = client ?? http.Client();

  final SessionStore sessionStore;
  final http.Client _client;

  /// Aceita HTTP para desenvolvimento local e HTTPS para produção.
  bool get isConfigured {
    final raw = AppConfig.apiBaseUrl.trim();
    final uri = Uri.tryParse(raw);

    if (uri == null || uri.host.isEmpty) return false;

    final validScheme = uri.scheme == 'http' || uri.scheme == 'https';
    final isPlaceholder = uri.host.toLowerCase().contains(
      'sua-api-publica-aqui',
    );

    return validScheme && !isPlaceholder;
  }

  /// Monta a URL completa do endpoint.
  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final base = AppConfig.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');

    final uri = Uri.parse('$base$path');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  /// Prepara os cabeçalhos das requisições.
  Future<Map<String, String>> _headers({bool authenticated = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await sessionStore.readToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Converte uma resposta JSON em objeto.
  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Resposta vazia ou não JSON.
    }

    return <String, dynamic>{};
  }

  /// Produz uma mensagem de erro compreensível.
  ApiException _responseError(http.Response response) {
    final body = _decodeObject(response);

    var message = (body['mensagem'] ?? body['message'] ?? body['title'])
        ?.toString();

    final errors = body['erros'] ?? body['errors'];

    if (errors is Map) {
      final details = <String>[];

      errors.forEach((field, messages) {
        if (messages is List) {
          details.add('$field: ${messages.join(', ')}');
        } else if (messages != null) {
          details.add('$field: $messages');
        }
      });

      if (details.isNotEmpty) {
        message =
            '${message ?? 'Dados inválidos.'}\n'
            '${details.join('\n')}';
      }
    }

    message ??= switch (response.statusCode) {
      401 => 'Credenciais inválidas ou sessão expirada.',
      403 => 'Seu perfil não tem permissão para esta ação.',
      404 => 'O registro solicitado não foi encontrado.',
      400 => 'A API não aceitou os dados enviados.',
      _ =>
        'Erro na comunicação com a API '
            '(${response.statusCode}).',
    };

    return ApiException(message, statusCode: response.statusCode);
  }

  /// Verifica se a resposta foi bem-sucedida.
  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response);
    }
  }

  /// Executa consultas GET que retornam listas.
  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    _checkConfiguration();

    final response = await _client.get(
      _uri(path, queryParameters: queryParameters),
      headers: await _headers(),
    );

    _checkResponse(response);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! List) {
      throw const ApiException(
        'A API retornou uma lista em formato inesperado.',
      );
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Executa consultas GET que retornam um objeto.
  Future<Map<String, dynamic>> _getObject(String path) async {
    _checkConfiguration();

    final response = await _client.get(_uri(path), headers: await _headers());

    _checkResponse(response);

    return _decodeObject(response);
  }

  /// Envia requisições POST, PUT e DELETE.
  Future<void> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    _checkConfiguration();

    final uri = _uri(path);
    final headers = await _headers();
    final encodedBody = body == null ? null : jsonEncode(body);

    late final http.Response response;

    switch (method.toUpperCase()) {
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encodedBody);
        break;

      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encodedBody);
        break;

      case 'DELETE':
        response = await _client.delete(
          uri,
          headers: headers,
          body: encodedBody,
        );
        break;

      default:
        throw ArgumentError('Método HTTP não suportado: $method');
    }

    _checkResponse(response);
  }

  /// Verifica se o endereço da API foi configurado.
  void _checkConfiguration() {
    if (!isConfigured) {
      throw const ApiException(
        'Configure o endereço da API em '
        'lib/config/app_config.dart.',
      );
    }
  }

  // ============================================================
  // AUTENTICAÇÃO
  // ============================================================

  /// Realiza login e salva o token JWT.
  Future<AppUser> login(String email, String password) async {
    _checkConfiguration();

    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: await _headers(authenticated: false),
      body: jsonEncode({'email': email.trim(), 'senha': password}),
    );

    _checkResponse(response);

    final json = _decodeObject(response);

    final token = json['token']?.toString();
    final expiresAt = json['expiraEm']?.toString();
    final userJson = json['usuario'];

    if (token == null ||
        token.isEmpty ||
        expiresAt == null ||
        expiresAt.isEmpty ||
        userJson is! Map) {
      throw const ApiException(
        'A resposta de login não corresponde ao formato do PIM-4.',
      );
    }

    await sessionStore.saveSession(token: token, expiresAtUtc: expiresAt);

    return AppUser.fromJson(Map<String, dynamic>.from(userJson));
  }

  /// Consulta o usuário associado ao token salvo.
  Future<AppUser> getCurrentUser() async {
    final json = await _getObject('/api/auth/eu');

    return AppUser.fromJson(json);
  }

  /// Encerra a sessão.
  Future<void> logout() async {
    await sessionStore.clearSession();
  }

  // ============================================================
  // PRODUTOS
  // ============================================================

  /// Consulta os produtos cadastrados.
  Future<List<Product>> getProducts({String? search}) async {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['busca'] = search.trim();
    }

    final rows = await _getList('/api/produtos', queryParameters: query);

    return rows.map(Product.fromJson).toList();
  }

  /// Consulta produtos modificados desde uma data.
  Future<List<Product>> getUpdatedProducts(DateTime updatedSince) async {
    final rows = await _getList(
      '/api/produtos',
      queryParameters: {
        'atualizadoDesde': updatedSince.toUtc().toIso8601String(),
      },
    );

    return rows.map(Product.fromJson).toList();
  }

  /// Busca um produto pelo código de barras.
  Future<Product> getProductByBarcode(String barcode) async {
    final json = await _getObject(
      '/api/produtos/codigo-barras/'
      '${Uri.encodeComponent(barcode)}',
    );

    return Product.fromJson(json);
  }

  /// Cadastra um produto na API.
  Future<void> createProduct({
    required String name,
    required int categoryId,
    required int supplierId,
    required double price,
    required int quantity,
    String barcode = '',
    int minimumStock = 0,
  }) async {
    await _send(
      'POST',
      '/api/produtos',
      body: {
        'nome': name.trim(),
        'codigoBarras': barcode.trim(),
        'preco': price,
        'estoqueMinimo': minimumStock,
        'categoriaId': categoryId,
        'fornecedorId': supplierId,
        'estoqueInicial': quantity,
        'ativo': true,
      },
    );
  }

  // ============================================================
  // CATEGORIAS E FORNECEDORES
  // ============================================================

  /// Consulta as categorias disponíveis.
  Future<List<CatalogOption>> getCategories() async {
    final rows = await _getList('/api/categorias');

    return rows.map(CatalogOption.fromJson).toList();
  }

  /// Consulta os fornecedores disponíveis.
  Future<List<CatalogOption>> getSuppliers() async {
    final rows = await _getList('/api/fornecedores');

    return rows.map(CatalogOption.fromJson).toList();
  }

  // ============================================================
  // MOVIMENTAÇÕES
  // ============================================================

  /// Consulta o histórico de movimentações.
  Future<List<Movement>> getMovements({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{};

    if (startDate != null) {
      query['dataInicio'] = _dateOnly(startDate);
    }

    if (endDate != null) {
      query['dataFim'] = _dateOnly(endDate);
    }

    final rows = await _getList('/api/movimentacoes', queryParameters: query);

    return rows.map(Movement.fromJson).toList();
  }

  /// Consulta as últimas movimentações.
  Future<List<Movement>> getRecentMovements({int quantity = 10}) async {
    final rows = await _getList(
      '/api/movimentacoes/ultimas',
      queryParameters: {'quantidade': quantity.toString()},
    );

    return rows.map(Movement.fromJson).toList();
  }

  /// Registra uma entrada ou saída de estoque.
  Future<void> createMovement({
    required int? productId,
    required bool isEntry,
    required int quantity,
    String? barcode,
    String? observation,
    String? paymentMethod,
  }) async {
    final body = <String, dynamic>{
      'tipo': isEntry ? 'ENTRADA' : 'SAIDA',
      'quantidade': quantity,
    };

    if (productId != null) {
      body['produtoId'] = productId;
    } else if (barcode != null && barcode.trim().isNotEmpty) {
      body['codigoBarras'] = barcode.trim();
    } else {
      throw const ApiException('Informe o produto ou o código de barras.');
    }

    final note = observation ?? paymentMethod;

    if (note != null && note.trim().isNotEmpty) {
      body['observacao'] = note.trim();
    }

    await _send('POST', '/api/movimentacoes', body: body);
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  /// Consulta os indicadores do dashboard.
  Future<DashboardSummary> getDashboardSummary() async {
    final json = await _getObject('/api/dashboard/resumo');

    return DashboardSummary.fromJson(json);
  }

  // ============================================================
  // UTILITÁRIOS
  // ============================================================

  /// Formata uma data no padrão YYYY-MM-DD.
  String _dateOnly(DateTime date) {
    final local = date.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
