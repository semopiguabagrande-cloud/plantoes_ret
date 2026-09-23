import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ===================================================
  // GOOGLE APPS SCRIPT
  // ===================================================

static const String baseUrl =
  'https://script.google.com/macros/s/AKfycbwtvlBfdqbpDZKwS5PQOAdBJWC7GVNjkKhoFylG8PPE-p2ZKt0gJhjdiDL3-PF2lJrhsQ/exec';
  static const Duration timeout = Duration(seconds: 30);

 // Identificação do cliente Flutter para validação no servidor.
static const String versaoAplicativo = '2.0.0+2';

static String get identificacaoCliente {
  final cliente = kIsWeb ? 'flutter_web' : 'flutter_app';

  return '&cliente=$cliente'
      '&versao=${Uri.encodeComponent(versaoAplicativo)}';
}

  // ===================================================
  // CHAVES DA SESSÃƒO SALVA
  // ===================================================

  static const String _chaveCodigo = 'sessao_codigo';

  static const String _chaveSessionId = 'sessao_session_id';

  // ===================================================
  // CONTROLE DA SESSÃƒO EM MEMÃ“RIA
  // ===================================================

  static String? _codigoSessao;
  static String? _sessionId;

  static String? get codigoSessao => _codigoSessao;

  static String? get sessionId => _sessionId;

  static bool get possuiSessao =>
      _codigoSessao != null &&
      _codigoSessao!.isNotEmpty &&
      _sessionId != null &&
      _sessionId!.isNotEmpty;

  // ===================================================
  // INICIALIZAR / RECUPERAR SESSÃƒO LOCAL
  // ===================================================

  static Future<void> inicializarSessao() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final codigo = prefs.getString(_chaveCodigo);

      final sessao = prefs.getString(_chaveSessionId);

      if (codigo != null &&
          codigo.isNotEmpty &&
          sessao != null &&
          sessao.isNotEmpty) {
        _codigoSessao = codigo;
        _sessionId = sessao;
      }
    } catch (e) {
      debugPrint('Inicializar sessÃ£o: erro: $e');

      _codigoSessao = null;
      _sessionId = null;
    }
  }

  // ===================================================
  // SALVAR SESSÃƒO LOCALMENTE
  // ===================================================

  static Future<void> _salvarSessaoLocal() async {
    if (!possuiSessao) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_chaveCodigo, _codigoSessao!);

      await prefs.setString(_chaveSessionId, _sessionId!);
    } catch (e) {
      // A sessÃ£o continua funcionando em memÃ³ria.
      debugPrint('Salvar sessÃ£o local: erro: $e');
    }
  }

  // ===================================================
  // APAGAR SESSÃƒO LOCAL
  // ===================================================

  static Future<void> limparSessao() async {
    _codigoSessao = null;
    _sessionId = null;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_chaveCodigo);

      await prefs.remove(_chaveSessionId);
    } catch (e) {
      debugPrint('Limpar sessÃ£o: erro: $e');
    }
  }

  // ===================================================
  // LOGIN
  // ===================================================

  static Future<Map<String, dynamic>> buscarAgente(String codigo) async {
    try {
      final codigoNormalizado = codigo.trim();

      if (codigoNormalizado.isEmpty) {
        return {'success': false, 'mensagem': 'CÃ³digo nÃ£o informado.'};
      }

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=agente'
        '&codigo=${Uri.encodeComponent(codigoNormalizado)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}'
        '$identificacaoCliente',
      );

      final response = await http.get(url).timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro de conexÃ£o.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta invÃ¡lida do servidor.');
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // LOGIN AUTORIZADO
      // =================================================

      if (resultado['success'] == true) {
        final novaSessao = resultado['sessionId'];

        // =================================================
        // SALVA SESSÃƒO DO AGENTE
        // =================================================

        if (novaSessao != null && novaSessao.toString().trim().isNotEmpty) {
          _codigoSessao = codigoNormalizado;

          _sessionId = novaSessao.toString();

          await _salvarSessaoLocal();
        }

        // =================================================
        // TODO USUÃRIO PRECISA DE SESSION ID
        // INCLUSIVE ADMIN
        // =================================================

        final tipo = resultado['tipo']?.toString().trim().toUpperCase() ?? '';

        // =================================================
        // SESSION ID Ã‰ OBRIGATÃ“RIO
        // TANTO PARA AGENTE QUANTO PARA ADMIN
        // =================================================

        if (novaSessao == null || novaSessao.toString().trim().isEmpty) {
          return {
            'success': false,
            'mensagem': 'O servidor nÃ£o forneceu uma sessÃ£o vÃ¡lida.',
          };
        }

        // =================================================
        // GARANTE QUE A SESSÃƒO FICOU SALVA
        // =================================================

        _codigoSessao = codigoNormalizado;

        _sessionId = novaSessao.toString();

        await _salvarSessaoLocal();

        debugPrint('Login $tipo autorizado.');

        debugPrint('Session ID: $_sessionId');
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexÃ£o esgotado.');
    } catch (e) {
      throw Exception('Erro ao buscar agente.\n$e');
    }
  }

  // ===================================================
  // RECUPERAR SESSÃƒO
  // ===================================================

  static Future<Map<String, dynamic>> recuperarSessao() async {
    try {
      // =================================================
      // CARREGA A SESSÃƒO SALVA
      // =================================================

      await inicializarSessao();

      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem': 'Nenhuma sessÃ£o salva neste dispositivo.',
        };
      }

      // =================================================
      // GUARDA OS DADOS DA SESSÃƒO
      // =================================================

      final codigo = _codigoSessao!;

      final sessao = _sessionId!;

      // =================================================
      // VERIFICA DIRETAMENTE NO SERVIDOR
      //
      // NÃƒO usa heartbeat aqui.
      // =================================================

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=recuperarSessao'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(sessao)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}'
        '$identificacaoCliente',
      );

      final response = await http.get(url).timeout(timeout);

      // =================================================
      // ERRO HTTP
      //
      // NÃƒO APAGA A SESSÃƒO.
      // =================================================

      if (response.statusCode != 200) {
        return {
          'success': false,
          'erroConexao': true,
          'mensagem': 'NÃ£o foi possÃ­vel verificar a sessÃ£o.',
        };
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        return {
          'success': false,
          'erroConexao': true,
          'mensagem': 'Resposta invÃ¡lida do servidor.',
        };
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SESSÃƒO VÃLIDA
      // =================================================

      if (resultado['success'] == true &&
          resultado['sessaoRecuperada'] == true) {
        _codigoSessao = codigo;

        _sessionId = sessao;

        await _salvarSessaoLocal();

        resultado['sessionId'] = sessao;

        resultado['sessaoRecuperada'] = true;

        return resultado;
      }

      // =================================================
      // SERVIDOR CONFIRMOU EXPLICITAMENTE
      // QUE A SESSÃƒO NÃƒO EXISTE
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();

        return resultado;
      }

      // =================================================
      // RESPOSTA INESPERADA
      //
      // NÃƒO APAGA A SESSÃƒO.
      // =================================================

      return {...resultado, 'success': false, 'erroConexao': false};
    } on TimeoutException {
      return {
        'success': false,
        'erroConexao': true,
        'mensagem':
            'Tempo de conexÃ£o esgotado. '
            'A sessÃ£o local foi preservada.',
      };
    } catch (e) {
      debugPrint('Recuperar sessÃ£o: erro: $e');

      return {
        'success': false,
        'erroConexao': true,
        'mensagem': 'NÃ£o foi possÃ­vel verificar a sessÃ£o.',
      };
    }
  }

    // ===================================================
  // BUSCAR VAGAS
  // ===================================================

  static Future<List<dynamic>> buscarVagas({
    required String ano,
    required String mes,
  }) async {
    try {
      // =================================================
      // VERIFICA SE EXISTE SESSÃƒO
      // =================================================

      if (!possuiSessao) {
        throw Exception(
          'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',
        );
      }

      // =================================================
      // MONTA URL
      // =================================================

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=vagas'
        '&ano=${Uri.encodeComponent(ano)}'
        '&mes=${Uri.encodeComponent(mes)}'
        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}'
        '$identificacaoCliente',
      );

      final url = Uri.parse(
        parametros.toString(),
      );

      // =================================================
      // DEBUG
      // =================================================

      debugPrint(
        '========================================',
      );

      debugPrint(
        'BUSCANDO VAGAS',
      );

      debugPrint(
        'CÃ³digo: $_codigoSessao',
      );

      debugPrint(
        'Session ID: $_sessionId',
      );

      // =================================================
      // CONSULTA SERVIDOR
      // =================================================

      final response =
          await http
              .get(url)
              .timeout(timeout);

      debugPrint(
        'Vagas HTTP: ${response.statusCode}',
      );

      debugPrint(
        'Vagas resposta: ${response.body}',
      );

      // =================================================
      // ERRO HTTP
      // =================================================

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar vagas.',
        );
      }

      // =================================================
      // DECODIFICA
      // =================================================

      final body =
          jsonDecode(response.body);

      // =================================================
      // RESPOSTA NORMAL
      // =================================================

      if (body is List) {
        return List<dynamic>.from(
          body,
        );
      }

      // =================================================
      // RESPOSTA DO SERVIDOR EM MAP
      // =================================================

      if (body is Map) {
        final resultado =
            Map<String, dynamic>.from(
          body,
        );

        // ===============================================
        // SOMENTE AQUI CONSIDERAMOS
        // QUE O SERVIDOR CONFIRMOU EXPIRAÃ‡ÃƒO
        // ===============================================

        if (
          resultado['sessaoExpirada'] ==
          true
        ) {
          await limparSessao();

          throw Exception(
            resultado['mensagem']
                    ?.toString() ??
                'SessÃ£o invÃ¡lida ou encerrada.',
          );
        }

        // ===============================================
        // OUTRO ERRO DO SERVIDOR
        //
        // NÃƒO APAGA A SESSÃƒO
        // ===============================================

        throw Exception(
          resultado['mensagem']
                  ?.toString() ??
              'Erro ao buscar vagas.',
        );
      }

      // =================================================
      // RESPOSTA INVÃLIDA
      // =================================================

      throw Exception(
        'Resposta invÃ¡lida ao buscar vagas.',
      );

    } on TimeoutException {
      // =================================================
      // TIMEOUT
      //
      // NÃƒO APAGA SESSÃƒO
      // =================================================

      throw Exception(
        'Tempo de conexÃ£o esgotado.',
      );

    } catch (e) {
      debugPrint(
        'Buscar vagas: erro: $e',
      );

      throw Exception(
        'Erro ao buscar vagas.\n$e',
      );
    }
  }

  // ===================================================
  // SALVAR INSCRIÃ‡ÃƒO
  // ===================================================

  static Future<Map<String, dynamic>> salvarInscricao({
    required String ano,
    required String mes,
    required String codigo,
    required String matricula,
    required String nome,
    required List<Map<String, dynamic>> datas,
  }) async {
    try {
      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem': 'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',
        };
      }

      final jsonDatas = jsonEncode(datas);

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=salvarInscricao'
        '&ano=${Uri.encodeComponent(ano)}'
        '&mes=${Uri.encodeComponent(mes)}'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&matricula=${Uri.encodeComponent(matricula)}'
        '&nome=${Uri.encodeComponent(nome)}'
        '&datas=${Uri.encodeComponent(jsonDatas)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}$identificacaoCliente');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao salvar inscriÃ§Ã£o.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta invÃ¡lida ao salvar inscriÃ§Ã£o.');
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SOMENTE APAGA SE SERVIDOR CONFIRMAR EXPIRAÃ‡ÃƒO
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexÃ£o esgotado.');
    } catch (e) {
      throw Exception('Erro ao salvar inscriÃ§Ã£o.\n$e');
    }
  }

  // ===================================================
  // CANCELAR INSCRIÃ‡ÃƒO
  // ===================================================

  static Future<Map<String, dynamic>> cancelarInscricao({
    required String codigo,
    required List<Map<String, dynamic>> datas,
  }) async {
    try {
      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem': 'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',
        };
      }

      final jsonDatas = jsonEncode(datas);

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=cancelarInscricao'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&datas=${Uri.encodeComponent(jsonDatas)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}$identificacaoCliente');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao cancelar inscriÃ§Ã£o.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta invÃ¡lida ao cancelar inscriÃ§Ã£o.');
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SOMENTE APAGA SE SERVIDOR CONFIRMAR EXPIRAÃ‡ÃƒO
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexÃ£o esgotado.');
    } catch (e) {
      throw Exception('Erro ao cancelar inscriÃ§Ã£o.\n$e');
    }
  }

  // ===================================================
  // MINHAS INSCRIÃ‡Ã•ES
  // ===================================================

  static Future<List<Map<String, dynamic>>> buscarMinhasInscricoes(
    String codigo,
  ) async {
    try {
      if (!possuiSessao) {
        return [];
      }

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=minhas'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}$identificacaoCliente');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar inscriÃ§Ãµes.');
      }

      final body = jsonDecode(response.body);

      // =================================================
      // RESPOSTA EM MAP = POSSÃVEL ERRO DO SERVIDOR
      // =================================================

      if (body is Map) {
        final resultado = Map<String, dynamic>.from(body);

        if (resultado['sessaoExpirada'] == true) {
          await limparSessao();
        }

        throw Exception(resultado['mensagem'] ?? 'Erro ao buscar inscriÃ§Ãµes.');
      }

      if (body is! List) {
        throw Exception('Resposta invÃ¡lida ao buscar inscriÃ§Ãµes.');
      }

      final dados = List<dynamic>.from(body);

      return dados.map((e) => Map<String, dynamic>.from(e)).toList();
    } on TimeoutException {
      throw Exception('Tempo de conexÃ£o esgotado.');
    } catch (e) {
      throw Exception('Erro ao buscar inscriÃ§Ãµes.\n$e');
    }
  }

  // ===================================================
  // DADOS INICIAIS
  // ===================================================

  static Future<Map<String, dynamic>> buscarInicial({
    required String codigo,
  }) async {
    try {
      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem': 'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',
        };
      }

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=inicial'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}$identificacaoCliente');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar dados iniciais.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta invÃ¡lida ao buscar dados iniciais.');
      }

      final resultado = Map<String, dynamic>.from(body);

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexÃ£o esgotado.');
    } catch (e) {
      throw Exception('Erro ao buscar dados iniciais.\n$e');
    }
  }

  // ===================================================
// RELATÃ“RIO ADMINISTRATIVO
// ===================================================

static Future<List<dynamic>> buscarInscricoesPDF() async {
  try {
    // =================================================
    // PRIMEIRO:
    // GARANTE QUE A SESSÃƒO SALVA FOI CARREGADA
    // =================================================

    await inicializarSessao();

    // =================================================
    // VERIFICA SE EXISTE SESSÃƒO
    // =================================================

    if (!possuiSessao) {
      throw Exception(
        'SessÃ£o do administrador nÃ£o encontrada. '
        'FaÃ§a login novamente.',
      );
    }

    // =================================================
    // GUARDA OS DADOS DA SESSÃƒO
    // =================================================

    final codigo = _codigoSessao!;
    final sessionId = _sessionId!;

    debugPrint('==========================================');
    debugPrint('RELATÃ“RIO ADMINISTRATIVO');
    debugPrint('CÃ³digo: $codigo');
    debugPrint('Session ID: $sessionId');
    debugPrint('==========================================');

    // =================================================
    // MONTA A URL
    // =================================================

    final url = Uri.parse(
      '$baseUrl'
      '?tipo=relatorio'
      '&codigo=${Uri.encodeComponent(codigo)}'
      '&sessionId=${Uri.encodeComponent(sessionId)}'
      '&t=${DateTime.now().millisecondsSinceEpoch}'
        '$identificacaoCliente',
    );

    debugPrint('Consultando relatÃ³rio...');
    debugPrint('URL: $url');

    // =================================================
    // CONSULTA O APPS SCRIPT
    // =================================================

    final response = await http
        .get(url)
        .timeout(timeout);

    debugPrint(
      'RelatÃ³rio HTTP: ${response.statusCode}',
    );

    debugPrint(
      'RelatÃ³rio resposta: ${response.body}',
    );

    // =================================================
    // ERRO HTTP
    // =================================================

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao buscar relatÃ³rio. '
        'CÃ³digo HTTP: ${response.statusCode}',
      );
    }

    // =================================================
    // DECODIFICA
    // =================================================

    final body = jsonDecode(response.body);

    // =================================================
    // RESPOSTA NORMAL = LISTA
    // =================================================

    if (body is List) {
      debugPrint(
        'RelatÃ³rio recebido com ${body.length} registros.',
      );

      return List<dynamic>.from(body);
    }

    // =================================================
    // RESPOSTA EM MAP
    // =================================================

    if (body is Map) {
      final resultado =
          Map<String, dynamic>.from(body);

      debugPrint(
        'RelatÃ³rio retornou MAP: $resultado',
      );

      // =================================================
      // SESSÃƒO EXPIRADA
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();

        throw Exception(
          resultado['mensagem']?.toString() ??
              'SessÃ£o do administrador invÃ¡lida ou encerrada.',
        );
      }

      // =================================================
      // PROCURA LISTA DENTRO DO MAP
      // =================================================

      const possiveisChaves = [
        'dados',
        'inscricoes',
        'lista',
        'resultado',
        'data',
      ];

      for (final chave in possiveisChaves) {
        final valor = resultado[chave];

        if (valor is List) {
          debugPrint(
            'RelatÃ³rio encontrado na chave: $chave',
          );

          return List<dynamic>.from(valor);
        }
      }

      // =================================================
      // ERRO DEVOLVIDO PELO SERVIDOR
      // =================================================

      final mensagem =
          resultado['mensagem'] ??
          resultado['erro'] ??
          resultado['error'];

      if (mensagem != null) {
        throw Exception(
          mensagem.toString(),
        );
      }

      // =================================================
      // RESPOSTA INESPERADA
      // =================================================

      throw Exception(
        'O servidor retornou uma resposta inesperada ao buscar o relatÃ³rio.',
      );
    }

    // =================================================
    // TIPO INVÃLIDO
    // =================================================

    throw Exception(
      'Resposta invÃ¡lida ao buscar relatÃ³rio.',
    );

  } on TimeoutException {
    throw Exception(
      'Tempo de conexÃ£o esgotado.',
    );

  } catch (e) {
    debugPrint(
      'ERRO RELATÃ“RIO: $e',
    );

    throw Exception(
      'Erro ao buscar relatÃ³rio.\n$e',
    );
  }
}
  
  // ===================================================
  // HEARTBEAT
  // ===================================================

  static Future<bool> heartbeat() async {
    if (!possuiSessao) {
      return false;
    }

    try {
      final url = Uri.parse(
        '$baseUrl'
        '?tipo=heartbeat'
        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}'
        '$identificacaoCliente',
      );

      final response = await http.get(url).timeout(timeout);

      // Em caso de falha de comunicação, preserva a sessão.
      if (response.statusCode != 200) {
        return true;
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        return true;
      }

      final resultado = Map<String, dynamic>.from(body);

      if (resultado['success'] == true) {
        return true;
      }

      // Só limpa a sessão se o servidor confirmar a expiração.
      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
        return false;
      }

      // Resposta indeterminada: preserva a sessão.
      return true;
    } catch (e) {
      debugPrint('Heartbeat: erro de conexão: $e');

      // Internet/timeout não deve apagar a sessão local.
      return true;
    }
  }

  // ===================================================
  // LOGOUT
  // ===================================================

  static Future<bool> logout() async {
    if (!possuiSessao) {
      await limparSessao();
      return true;
    }

    final codigo = _codigoSessao!;
    final sessao = _sessionId!;

    try {
      final url = Uri.parse(
        '$baseUrl'
        '?tipo=logout'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(sessao)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}'
        '$identificacaoCliente',
      );

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));

      // Não apaga a sessão se houver falha HTTP.
      if (response.statusCode != 200) {
        return false;
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        return false;
      }

      final resultado = Map<String, dynamic>.from(body);

      // Limpa a sessão somente após confirmação do servidor.
      if (resultado['success'] == true) {
        await limparSessao();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Logout: erro de conexão: $e');

      // Preserva a sessão local em caso de falha.
      return false;
    }
  }
}