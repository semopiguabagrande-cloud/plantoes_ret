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

  // ===================================================
  // CHAVES DA SESSÃO SALVA
  // ===================================================

  static const String _chaveCodigo = 'sessao_codigo';

  static const String _chaveSessionId = 'sessao_session_id';

  // ===================================================
  // CONTROLE DA SESSÃO EM MEMÓRIA
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
  // INICIALIZAR / RECUPERAR SESSÃO LOCAL
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
      debugPrint('Inicializar sessão: erro: $e');

      _codigoSessao = null;
      _sessionId = null;
    }
  }

  // ===================================================
  // SALVAR SESSÃO LOCALMENTE
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
      // A sessão continua funcionando em memória.
      debugPrint('Salvar sessão local: erro: $e');
    }
  }

  // ===================================================
  // APAGAR SESSÃO LOCAL
  // ===================================================

  static Future<void> limparSessao() async {
    _codigoSessao = null;
    _sessionId = null;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_chaveCodigo);

      await prefs.remove(_chaveSessionId);
    } catch (e) {
      debugPrint('Limpar sessão: erro: $e');
    }
  }

  // ===================================================
  // LOGIN
  // ===================================================

  static Future<Map<String, dynamic>> buscarAgente(String codigo) async {
    try {
      final codigoNormalizado = codigo.trim();

      if (codigoNormalizado.isEmpty) {
        return {'success': false, 'mensagem': 'Código não informado.'};
      }

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=agente'
        '&codigo=${Uri.encodeComponent(codigoNormalizado)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(url).timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro de conexão.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta inválida do servidor.');
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // LOGIN AUTORIZADO
      // =================================================

      if (resultado['success'] == true) {
        final novaSessao = resultado['sessionId'];

        // =================================================
        // SALVA SESSÃO DO AGENTE
        // =================================================

        if (novaSessao != null && novaSessao.toString().trim().isNotEmpty) {
          _codigoSessao = codigoNormalizado;

          _sessionId = novaSessao.toString();

          await _salvarSessaoLocal();
        }

        // =================================================
        // TODO USUÁRIO PRECISA DE SESSION ID
        // INCLUSIVE ADMIN
        // =================================================

        final tipo = resultado['tipo']?.toString().trim().toUpperCase() ?? '';

        // =================================================
        // SESSION ID É OBRIGATÓRIO
        // TANTO PARA AGENTE QUANTO PARA ADMIN
        // =================================================

        if (novaSessao == null || novaSessao.toString().trim().isEmpty) {
          return {
            'success': false,
            'mensagem': 'O servidor não forneceu uma sessão válida.',
          };
        }

        // =================================================
        // GARANTE QUE A SESSÃO FICOU SALVA
        // =================================================

        _codigoSessao = codigoNormalizado;

        _sessionId = novaSessao.toString();

        await _salvarSessaoLocal();

        debugPrint('Login $tipo autorizado.');

        debugPrint('Session ID: $_sessionId');
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception('Erro ao buscar agente.\n$e');
    }
  }

  // ===================================================
  // RECUPERAR SESSÃO
  // ===================================================

  static Future<Map<String, dynamic>> recuperarSessao() async {
    try {
      // =================================================
      // CARREGA A SESSÃO SALVA
      // =================================================

      await inicializarSessao();

      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem': 'Nenhuma sessão salva neste dispositivo.',
        };
      }

      // =================================================
      // GUARDA OS DADOS DA SESSÃO
      // =================================================

      final codigo = _codigoSessao!;

      final sessao = _sessionId!;

      // =================================================
      // VERIFICA DIRETAMENTE NO SERVIDOR
      //
      // NÃO usa heartbeat aqui.
      // =================================================

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=recuperarSessao'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(sessao)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(url).timeout(timeout);

      // =================================================
      // ERRO HTTP
      //
      // NÃO APAGA A SESSÃO.
      // =================================================

      if (response.statusCode != 200) {
        return {
          'success': false,
          'erroConexao': true,
          'mensagem': 'Não foi possível verificar a sessão.',
        };
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        return {
          'success': false,
          'erroConexao': true,
          'mensagem': 'Resposta inválida do servidor.',
        };
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SESSÃO VÁLIDA
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
      // QUE A SESSÃO NÃO EXISTE
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();

        return resultado;
      }

      // =================================================
      // RESPOSTA INESPERADA
      //
      // NÃO APAGA A SESSÃO.
      // =================================================

      return {...resultado, 'success': false, 'erroConexao': false};
    } on TimeoutException {
      return {
        'success': false,
        'erroConexao': true,
        'mensagem':
            'Tempo de conexão esgotado. '
            'A sessão local foi preservada.',
      };
    } catch (e) {
      debugPrint('Recuperar sessão: erro: $e');

      return {
        'success': false,
        'erroConexao': true,
        'mensagem': 'Não foi possível verificar a sessão.',
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
      // VERIFICA SE EXISTE SESSÃO
      // =================================================

      if (!possuiSessao) {
        throw Exception(
          'Sessão não encontrada. Faça login novamente.',
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
        '&t=${DateTime.now().millisecondsSinceEpoch}',
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
        'Código: $_codigoSessao',
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
        // QUE O SERVIDOR CONFIRMOU EXPIRAÇÃO
        // ===============================================

        if (
          resultado['sessaoExpirada'] ==
          true
        ) {
          await limparSessao();

          throw Exception(
            resultado['mensagem']
                    ?.toString() ??
                'Sessão inválida ou encerrada.',
          );
        }

        // ===============================================
        // OUTRO ERRO DO SERVIDOR
        //
        // NÃO APAGA A SESSÃO
        // ===============================================

        throw Exception(
          resultado['mensagem']
                  ?.toString() ??
              'Erro ao buscar vagas.',
        );
      }

      // =================================================
      // RESPOSTA INVÁLIDA
      // =================================================

      throw Exception(
        'Resposta inválida ao buscar vagas.',
      );

    } on TimeoutException {
      // =================================================
      // TIMEOUT
      //
      // NÃO APAGA SESSÃO
      // =================================================

      throw Exception(
        'Tempo de conexão esgotado.',
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
  // SALVAR INSCRIÇÃO
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
          'mensagem': 'Sessão não encontrada. Faça login novamente.',
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

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao salvar inscrição.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta inválida ao salvar inscrição.');
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SOMENTE APAGA SE SERVIDOR CONFIRMAR EXPIRAÇÃO
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception('Erro ao salvar inscrição.\n$e');
    }
  }

  // ===================================================
  // CANCELAR INSCRIÇÃO
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
          'mensagem': 'Sessão não encontrada. Faça login novamente.',
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

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao cancelar inscrição.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta inválida ao cancelar inscrição.');
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SOMENTE APAGA SE SERVIDOR CONFIRMAR EXPIRAÇÃO
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception('Erro ao cancelar inscrição.\n$e');
    }
  }

  // ===================================================
  // MINHAS INSCRIÇÕES
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

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar inscrições.');
      }

      final body = jsonDecode(response.body);

      // =================================================
      // RESPOSTA EM MAP = POSSÍVEL ERRO DO SERVIDOR
      // =================================================

      if (body is Map) {
        final resultado = Map<String, dynamic>.from(body);

        if (resultado['sessaoExpirada'] == true) {
          await limparSessao();
        }

        throw Exception(resultado['mensagem'] ?? 'Erro ao buscar inscrições.');
      }

      if (body is! List) {
        throw Exception('Resposta inválida ao buscar inscrições.');
      }

      final dados = List<dynamic>.from(body);

      return dados.map((e) => Map<String, dynamic>.from(e)).toList();
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception('Erro ao buscar inscrições.\n$e');
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
          'mensagem': 'Sessão não encontrada. Faça login novamente.',
        };
      }

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=inicial'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar dados iniciais.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception('Resposta inválida ao buscar dados iniciais.');
      }

      final resultado = Map<String, dynamic>.from(body);

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception('Erro ao buscar dados iniciais.\n$e');
    }
  }

  // ===================================================
// RELATÓRIO ADMINISTRATIVO
// ===================================================

static Future<List<dynamic>> buscarInscricoesPDF() async {
  try {
    // =================================================
    // PRIMEIRO:
    // GARANTE QUE A SESSÃO SALVA FOI CARREGADA
    // =================================================

    await inicializarSessao();

    // =================================================
    // VERIFICA SE EXISTE SESSÃO
    // =================================================

    if (!possuiSessao) {
      throw Exception(
        'Sessão do administrador não encontrada. '
        'Faça login novamente.',
      );
    }

    // =================================================
    // GUARDA OS DADOS DA SESSÃO
    // =================================================

    final codigo = _codigoSessao!;
    final sessionId = _sessionId!;

    debugPrint('==========================================');
    debugPrint('RELATÓRIO ADMINISTRATIVO');
    debugPrint('Código: $codigo');
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
      '&t=${DateTime.now().millisecondsSinceEpoch}',
    );

    debugPrint('Consultando relatório...');
    debugPrint('URL: $url');

    // =================================================
    // CONSULTA O APPS SCRIPT
    // =================================================

    final response = await http
        .get(url)
        .timeout(timeout);

    debugPrint(
      'Relatório HTTP: ${response.statusCode}',
    );

    debugPrint(
      'Relatório resposta: ${response.body}',
    );

    // =================================================
    // ERRO HTTP
    // =================================================

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao buscar relatório. '
        'Código HTTP: ${response.statusCode}',
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
        'Relatório recebido com ${body.length} registros.',
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
        'Relatório retornou MAP: $resultado',
      );

      // =================================================
      // SESSÃO EXPIRADA
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();

        throw Exception(
          resultado['mensagem']?.toString() ??
              'Sessão do administrador inválida ou encerrada.',
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
            'Relatório encontrado na chave: $chave',
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
        'O servidor retornou uma resposta inesperada ao buscar o relatório.',
      );
    }

    // =================================================
    // TIPO INVÁLIDO
    // =================================================

    throw Exception(
      'Resposta inválida ao buscar relatório.',
    );

  } on TimeoutException {
    throw Exception(
      'Tempo de conexão esgotado.',
    );

  } catch (e) {
    debugPrint(
      'ERRO RELATÓRIO: $e',
    );

    throw Exception(
      'Erro ao buscar relatório.\n$e',
    );
  }
}
  // ===================================================
  // HEARTBEAT
  // ===================================================

  static Future<bool> heartbeat() async {
    // =================================================
    // NÃO EXISTE SESSÃO LOCAL
    // =================================================

    if (!possuiSessao) {
      return false;
    }

    try {
      // =================================================
      // MONTA URL
      // =================================================

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=heartbeat'
        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      // =================================================
      // CONSULTA SERVIDOR
      // =================================================

      final response = await http.get(url).timeout(timeout);

      // =================================================
      // ERRO HTTP
      //
      // NÃO APAGA A SESSÃO.
      // =================================================

      if (response.statusCode != 200) {
        return true;
      }

      // =================================================
      // DECODIFICA
      // =================================================

      final body = jsonDecode(response.body);

      if (body is! Map) {
        return true;
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SERVIDOR CONFIRMOU SESSÃO ATIVA
      // =================================================

      if (resultado['success'] == true) {
        return true;
      }

      // =================================================
      // SERVIDOR CONFIRMOU EXPIRAÇÃO
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();

        return false;
      }

      // =================================================
      // RESPOSTA INDETERMINADA
      //
      // NÃO APAGA A SESSÃO.
      // =================================================

      return true;
    } catch (e) {
      // =================================================
      // INTERNET / TIMEOUT
      //
      // NÃO APAGA A SESSÃO.
      // =================================================

      debugPrint('Heartbeat: erro de conexão: $e');

      return true;
    }
  }

  // ===================================================
  // LOGOUT
  // ===================================================

  static Future<bool> logout() async {
    // =================================================
    // NÃO EXISTE SESSÃO
    // =================================================

    if (!possuiSessao) {
      return true;
    }

    // =================================================
    // GUARDA OS DADOS DA SESSÃO
    // =================================================

    final codigo = _codigoSessao!;

    final sessao = _sessionId!;

    try {
      // =================================================
      // MONTA URL
      // =================================================

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=logout'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(sessao)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      // =================================================
      // ENVIA LOGOUT PARA O SERVIDOR
      // =================================================

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      // =================================================
      // ERRO HTTP
      //
      // NÃO APAGA A SESSÃO LOCAL.
      // =================================================

      if (response.statusCode != 200) {
        return false;
      }

      // =================================================
      // DECODIFICA RESPOSTA
      // =================================================

      final body = jsonDecode(response.body);

      if (body is! Map) {
        return false;
      }

      final resultado = Map<String, dynamic>.from(body);

      // =================================================
      // SERVIDOR CONFIRMOU LOGOUT
      // =================================================

      if (resultado['success'] == true) {
        await limparSessao();

        return true;
      }

      // =================================================
      // SERVIDOR NÃO CONFIRMOU
      //
      // MANTÉM A SESSÃO LOCAL.
      // =================================================

      return false;
    } catch (e) {
      debugPrint('Logout: erro de conexão: $e');

      // =================================================
      // NÃO APAGA A SESSÃO LOCAL
      // =================================================

      return false;
    }
  }
}
