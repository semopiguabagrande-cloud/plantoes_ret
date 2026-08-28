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
    'https://script.google.com/macros/s/AKfycbw77y97FCRMsV9a9p6P2ApOODLAnjn7rNBXmNG7jck38gKLuCD7orTpp71b_fIzm35tlg/exec';

  static const Duration timeout =
      Duration(seconds: 30);

  // ===================================================
  // CHAVES DA SESSÃO SALVA
  // ===================================================

  static const String _chaveCodigo =
      'sessao_codigo';

  static const String _chaveSessionId =
      'sessao_session_id';

  // ===================================================
  // CONTROLE DA SESSÃO EM MEMÓRIA
  // ===================================================

  static String? _codigoSessao;
  static String? _sessionId;

  static String? get codigoSessao =>
      _codigoSessao;

  static String? get sessionId =>
      _sessionId;

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
      final prefs =
          await SharedPreferences.getInstance();

      final codigo =
          prefs.getString(
        _chaveCodigo,
      );

      final sessao =
          prefs.getString(
        _chaveSessionId,
      );

      if (codigo != null &&
          codigo.isNotEmpty &&
          sessao != null &&
          sessao.isNotEmpty) {
        _codigoSessao = codigo;
        _sessionId = sessao;
      }
    } catch (e) {
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
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        _chaveCodigo,
        _codigoSessao!,
      );

      await prefs.setString(
        _chaveSessionId,
        _sessionId!,
      );
    } catch (e) {
      // A sessão continua funcionando em memória.
    }
  }

  // ===================================================
  // APAGAR SESSÃO LOCAL
  // ===================================================

  static Future<void> limparSessao() async {
    _codigoSessao = null;
    _sessionId = null;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.remove(
        _chaveCodigo,
      );

      await prefs.remove(
        _chaveSessionId,
      );
    } catch (e) {
      // ignora
    }
  }

  // ===================================================
  // LOGIN
  // ===================================================

  static Future<Map<String, dynamic>> buscarAgente(
    String codigo,
  ) async {
    try {
      final codigoNormalizado =
          codigo.trim();

      if (codigoNormalizado.isEmpty) {
        return {
          'success': false,
          'mensagem':
              'Código não informado.',
        };
      }

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=agente'
        '&codigo=${Uri.encodeComponent(codigoNormalizado)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro de conexão.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(
        body,
      );

      // =================================================
      // LOGIN AUTORIZADO
      // =================================================

      if (resultado['success'] == true) {
        final novaSessao =
            resultado['sessionId'];

        // =================================================
        // AGENTE NORMAL
        // =================================================

        if (novaSessao != null &&
            novaSessao
                .toString()
                .isNotEmpty) {
          _codigoSessao =
              codigoNormalizado;

          _sessionId =
              novaSessao.toString();

          // Salva para sobreviver ao fechamento
          // da aba/navegador.
          await _salvarSessaoLocal();
        }

        // =================================================
        // SEGURANÇA
        // =================================================

        if (resultado['tipo']
                    ?.toString()
                    .toUpperCase() !=
                'ADMIN' &&
            (novaSessao == null ||
                novaSessao
                    .toString()
                    .isEmpty)) {
          return {
            'success': false,
            'mensagem':
                'O servidor não forneceu uma sessão válida.',
          };
        }
      }

      return resultado;
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
      throw Exception(
        'Erro ao buscar agente.\n$e',
      );
    }
  }

 // ===================================================
// RECUPERAR SESSÃO
// ===================================================

static Future<Map<String, dynamic>>
    recuperarSessao() async {

  try {

    // =================================================
    // CARREGA A SESSÃO SALVA NO DISPOSITIVO
    // =================================================

    await inicializarSessao();


    // =================================================
    // NÃO EXISTE SESSÃO SALVA
    // =================================================

    if (!possuiSessao) {

      return {
        'success': false,
        'sessaoExpirada': true,
        'mensagem':
            'Nenhuma sessão salva neste dispositivo.',
      };

    }


    // =================================================
    // GUARDA OS DADOS DA SESSÃO
    // =================================================

    final codigo =
        _codigoSessao!;

    final sessao =
        _sessionId!;


    // =================================================
    // VERIFICA A SESSÃO DIRETAMENTE NO SERVIDOR
    //
    // IMPORTANTE:
    //
    // NÃO usamos heartbeat aqui.
    //
    // Se a internet estiver indisponível,
    // a sessão local NÃO será apagada.
    // =================================================

    final url = Uri.parse(
      '$baseUrl'
      '?tipo=recuperarSessao'
      '&codigo=${Uri.encodeComponent(codigo)}'
      '&sessionId=${Uri.encodeComponent(sessao)}'
      '&t=${DateTime.now().millisecondsSinceEpoch}',
    );


    final response =
        await http
            .get(url)
            .timeout(timeout);


    // =================================================
    // ERRO HTTP
    //
    // PRESERVA A SESSÃO LOCAL.
    // =================================================

    if (response.statusCode != 200) {

      return {
        'success': false,
        'erroConexao': true,
        'mensagem':
            'Não foi possível verificar a sessão.',
      };

    }


    // =================================================
    // DECODIFICA RESPOSTA
    // =================================================

    final body =
        jsonDecode(response.body);


    final resultado =
        Map<String, dynamic>.from(
      body,
    );


    // =================================================
    // SESSÃO VÁLIDA
    // =================================================

    if (
      resultado['success'] == true &&
      resultado['sessaoRecuperada'] == true
    ) {

      // =================================================
      // MANTÉM O MESMO SESSION_ID
      // =================================================

      _codigoSessao =
          codigo;

      _sessionId =
          sessao;


      // =================================================
      // GARANTE QUE A SESSÃO CONTINUE SALVA
      // =================================================

      await _salvarSessaoLocal();


      // =================================================
      // DEVOLVE O SESSION_ID
      // =================================================

      resultado['sessionId'] =
          sessao;


      resultado['sessaoRecuperada'] =
          true;


      return resultado;

    }


    // =================================================
    // SERVIDOR CONFIRMOU QUE A SESSÃO FOI ENCERRADA
    //
    // SOMENTE NESTE CASO APAGAMOS A SESSÃO LOCAL.
    // =================================================

    if (
      resultado['sessaoExpirada'] == true
    ) {

      await limparSessao();


      return resultado;

    }


    // =================================================
    // RESPOSTA INESPERADA DO SERVIDOR
    //
    // NÃO APAGA A SESSÃO LOCAL.
    // =================================================

    return {

      ...resultado,

      'success': false,

      'erroConexao': false,

    };

  }


  // ===================================================
  // TIMEOUT
  //
  // NÃO APAGA A SESSÃO.
  // ===================================================

  on TimeoutException {

    return {

      'success': false,

      'erroConexao': true,

      'mensagem':
          'Tempo de conexão esgotado. '
          'A sessão local foi preservada.',

    };

  }


  // ===================================================
  // ERRO DE CONEXÃO
  //
  // NÃO APAGA A SESSÃO.
  // ===================================================

  catch (e) {

    return {

      'success': false,

      'erroConexao': true,

      'mensagem':
          'Não foi possível verificar a sessão.',

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
      final url = Uri.parse(
        '$baseUrl'
        '?tipo=vagas'
        '&ano=${Uri.encodeComponent(ano)}'
        '&mes=${Uri.encodeComponent(mes)}'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar vagas.',
        );
      }

      final body =
          jsonDecode(response.body);

      return List<dynamic>.from(
        body,
      );
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
      throw Exception(
        'Erro ao buscar vagas.\n$e',
      );
    }
  }

  // ===================================================
  // SALVAR INSCRIÇÃO
  // ===================================================

  static Future<Map<String, dynamic>>
      salvarInscricao({
    required String ano,
    required String mes,
    required String codigo,
    required String matricula,
    required String nome,
    required List<Map<String, dynamic>>
        datas,
  }) async {
    try {
      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem':
              'Sessão não encontrada. Faça login novamente.',
        };
      }

      final jsonDatas =
          jsonEncode(datas);

      final parametros =
          StringBuffer(
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

      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(
                Uri.parse(
                  parametros.toString(),
                ),
              )
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao salvar inscrição.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(
        body,
      );

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
      throw Exception(
        'Erro ao salvar inscrição.\n$e',
      );
    }
  }

  // ===================================================
  // CANCELAR INSCRIÇÃO
  // ===================================================

  static Future<Map<String, dynamic>>
      cancelarInscricao({
    required String codigo,
    required List<Map<String, dynamic>>
        datas,
  }) async {
    try {
      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem':
              'Sessão não encontrada. Faça login novamente.',
        };
      }

      final jsonDatas =
          jsonEncode(datas);

      final parametros =
          StringBuffer(
        '$baseUrl'
        '?tipo=cancelarInscricao'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&datas=${Uri.encodeComponent(jsonDatas)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(
                Uri.parse(
                  parametros.toString(),
                ),
              )
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao cancelar inscrição.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(
        body,
      );

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
      throw Exception(
        'Erro ao cancelar inscrição.\n$e',
      );
    }
  }

  // ===================================================
  // MINHAS INSCRIÇÕES
  // ===================================================

  static Future<List<Map<String, dynamic>>>
      buscarMinhasInscricoes(
    String codigo,
  ) async {
    try {
      if (!possuiSessao) {
        return [];
      }

      final parametros =
          StringBuffer(
        '$baseUrl'
        '?tipo=minhas'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(
                Uri.parse(
                  parametros.toString(),
                ),
              )
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar inscrições.',
        );
      }

      final body =
          jsonDecode(response.body);

      if (body is Map) {
        final resultado =
            Map<String, dynamic>.from(
          body,
        );

        if (resultado['sessaoExpirada'] == true) {
          await limparSessao();
        }

        throw Exception(
          resultado['mensagem'] ??
              'Erro ao buscar inscrições.',
        );
      }

      final dados =
          List<dynamic>.from(
        body,
      );

      return dados
          .map(
            (e) =>
                Map<String, dynamic>.from(
              e,
            ),
          )
          .toList();
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
      throw Exception(
        'Erro ao buscar inscrições.\n$e',
      );
    }
  }

  // ===================================================
  // DADOS INICIAIS
  // ===================================================

  static Future<Map<String, dynamic>>
      buscarInicial({
    required String codigo,
  }) async {
    try {
      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem':
              'Sessão não encontrada. Faça login novamente.',
        };
      }

      final parametros =
          StringBuffer(
        '$baseUrl'
        '?tipo=inicial'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(
                Uri.parse(
                  parametros.toString(),
                ),
              )
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar dados iniciais.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(
        body,
      );

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
      throw Exception(
        'Erro ao buscar dados iniciais.\n$e',
      );
    }
  }

  // ===================================================
  // RELATÓRIO
  // ===================================================

  static Future<List<dynamic>>
      buscarInscricoesPDF() async {
    try {
      final url = Uri.parse(
        '$baseUrl'
        '?tipo=relatorio'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar relatório.',
        );
      }

      final body =
          jsonDecode(response.body);

      return List<dynamic>.from(
        body,
      );
    } on TimeoutException {
      throw Exception(
        'Tempo de conexão esgotado.',
      );
    } catch (e) {
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

    final response =
        await http
            .get(url)
            .timeout(timeout);

    // =================================================
    // ERRO HTTP
    //
    // NÃO APAGA A SESSÃO LOCAL.
    //
    // Pode ser uma falha temporária do servidor,
    // internet ou redirecionamento.
    // =================================================

    if (response.statusCode != 200) {

      return true;

    }

    // =================================================
    // DECODIFICA RESPOSTA
    // =================================================

    final body =
        jsonDecode(response.body);

    final resultado =
        Map<String, dynamic>.from(
      body,
    );

    // =================================================
    // SERVIDOR CONFIRMOU QUE A SESSÃO ESTÁ ATIVA
    // =================================================

    if (resultado['success'] == true) {

      return true;

    }

    // =================================================
    // SERVIDOR CONFIRMOU EXPLICITAMENTE
    // QUE A SESSÃO FOI ENCERRADA
    // =================================================

    if (resultado['sessaoExpirada'] == true) {

      await limparSessao();

      return false;

    }

    // =================================================
    // RESPOSTA INDETERMINADA
    //
    // NÃO APAGA A SESSÃO LOCAL.
    // =================================================

    return true;

  } catch (e) {

    // =================================================
    // FALHA DE INTERNET / TIMEOUT
    //
    // NÃO APAGA A SESSÃO LOCAL.
    //
    // Isso permite que o navegador seja fechado
    // e a sessão continue salva para tentativa
    // de recuperação posteriormente.
    // =================================================

    debugPrint(
      'Heartbeat: erro de conexão: $e',
    );

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
  // GUARDA OS DADOS ANTES DA REQUISIÇÃO
  // =================================================

  final codigo =
      _codigoSessao!;

  final sessao =
      _sessionId!;

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

    final response =
        await http
            .get(url)
            .timeout(
              const Duration(
                seconds: 10,
              ),
            );

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

    final body =
        jsonDecode(response.body);

    final resultado =
        Map<String, dynamic>.from(
      body,
    );

    // =================================================
    // SERVIDOR CONFIRMOU O LOGOUT
    //
    // AGORA SIM APAGA A SESSÃO LOCAL.
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

    // =================================================
    // ERRO DE INTERNET / TIMEOUT
    //
    // NÃO APAGA A SESSÃO LOCAL.
    // =================================================

    debugPrint(
      'Logout: erro de conexão: $e',
    );

    return false;

  }
}

}
