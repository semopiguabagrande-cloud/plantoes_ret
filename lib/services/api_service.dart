import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // ===================================================
  // ENDEREÇO DO GOOGLE APPS SCRIPT
  // ===================================================

  static const String baseUrl =
      "https://script.google.com/macros/s/AKfycbw77y97FCRMsV9a9p6P2ApOODLAnjn7rNBXmNG7jck38gKLuCD7orTpp71b_fIzm35tlg/exec";

  static const Duration timeout =
      Duration(seconds: 30);

  // ===================================================
  // CONTROLE DA SESSÃO
  // ===================================================

  static String? _codigoSessao;
  static String? _sessionId;

  static String? get codigoSessao =>
      _codigoSessao;

  static String? get sessionId =>
      _sessionId;

  static bool get possuiSessao =>
      _codigoSessao != null &&
      _sessionId != null &&
      _sessionId!.isNotEmpty;

  // ===================================================
  // LOGIN
  // ===================================================

  static Future<Map<String, dynamic>> buscarAgente(
    String codigo,
  ) async {
    try {
      final codigoNormalizado =
          codigo.trim();

      final url = Uri.parse(
        "$baseUrl"
        "?tipo=agente"
        "&codigo=${Uri.encodeComponent(codigoNormalizado)}"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response = await http
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
          Map<String, dynamic>.from(body);

      // =================================================
      // LOGIN AUTORIZADO
      // =================================================

      if (resultado['success'] == true) {

        final novaSessao =
            resultado['sessionId'];

        // O servidor precisa enviar
        // sessionId para agente normal.
        if (novaSessao != null &&
            novaSessao
                .toString()
                .isNotEmpty) {

          _codigoSessao =
              codigoNormalizado;

          _sessionId =
              novaSessao.toString();
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
  // BUSCAR VAGAS
  // ===================================================

  static Future<List<dynamic>> buscarVagas({
    required String ano,
    required String mes,
  }) async {
    try {
      final url = Uri.parse(
        "$baseUrl"
        "?tipo=vagas"
        "&ano=${Uri.encodeComponent(ano)}"
        "&mes=${Uri.encodeComponent(mes)}"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar vagas.',
        );
      }

      final body =
          jsonDecode(response.body);

      return List<dynamic>.from(body);

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
      final jsonDatas =
          jsonEncode(datas);

      final parametros =
          StringBuffer(
        "$baseUrl"
        "?tipo=salvarInscricao"
        "&ano=${Uri.encodeComponent(ano)}"
        "&mes=${Uri.encodeComponent(mes)}"
        "&codigo=${Uri.encodeComponent(codigo)}"
        "&matricula=${Uri.encodeComponent(matricula)}"
        "&nome=${Uri.encodeComponent(nome)}"
        "&datas=${Uri.encodeComponent(jsonDatas)}",
      );

      // =================================================
      // ENVIA SESSION ID
      // =================================================

      if (possuiSessao) {
        parametros.write(
          "&sessionId="
          "${Uri.encodeComponent(_sessionId!)}",
        );
      }

      parametros.write(
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final url =
          Uri.parse(parametros.toString());

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao salvar inscrição.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(body);

      // Se a sessão foi rejeitada pelo servidor
      if (resultado['sessaoExpirada'] == true) {
        limparSessao();
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
      final jsonDatas =
          jsonEncode(datas);

      final parametros =
          StringBuffer(
        "$baseUrl"
        "?tipo=cancelarInscricao"
        "&codigo=${Uri.encodeComponent(codigo)}"
        "&datas=${Uri.encodeComponent(jsonDatas)}",
      );

      // =================================================
      // ENVIA SESSION ID
      // =================================================

      if (possuiSessao) {
        parametros.write(
          "&sessionId="
          "${Uri.encodeComponent(_sessionId!)}",
        );
      }

      parametros.write(
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final url =
          Uri.parse(parametros.toString());

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao cancelar inscrição.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(body);

      if (resultado['sessaoExpirada'] == true) {
        limparSessao();
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
      final parametros =
          StringBuffer(
        "$baseUrl"
        "?tipo=minhas"
        "&codigo=${Uri.encodeComponent(codigo)}",
      );

      if (possuiSessao) {
        parametros.write(
          "&sessionId="
          "${Uri.encodeComponent(_sessionId!)}",
        );
      }

      parametros.write(
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final url =
          Uri.parse(parametros.toString());

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar inscrições.',
        );
      }

      final body =
          jsonDecode(response.body);

      final dados =
          List<dynamic>.from(body);

      return dados
          .map(
            (e) =>
                Map<String, dynamic>.from(e),
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
  // AGENTE + VAGAS + INSCRIÇÕES
  // ===================================================

  static Future<Map<String, dynamic>>
      buscarInicial({
    required String codigo,
  }) async {
    try {
      final parametros =
          StringBuffer(
        "$baseUrl"
        "?tipo=inicial"
        "&codigo=${Uri.encodeComponent(codigo)}",
      );

      // =================================================
      // ENVIA SESSION ID
      // =================================================

      if (possuiSessao) {
        parametros.write(
          "&sessionId="
          "${Uri.encodeComponent(_sessionId!)}",
        );
      }

      parametros.write(
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final url =
          Uri.parse(parametros.toString());

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar dados iniciais.',
        );
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(body);

      // =================================================
      // SESSÃO EXPIRADA / INVÁLIDA
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        limparSessao();
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
  // RELATÓRIO PDF
  // ===================================================

  static Future<List<dynamic>>
      buscarInscricoesPDF() async {
    try {
      final url = Uri.parse(
        "$baseUrl"
        "?tipo=relatorio"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar relatório.',
        );
      }

      final body =
          jsonDecode(response.body);

      return List<dynamic>.from(body);

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

    if (!possuiSessao) {
      return false;
    }

    try {
      final url = Uri.parse(
        "$baseUrl"
        "?tipo=heartbeat"
        "&codigo="
        "${Uri.encodeComponent(_codigoSessao!)}"
        "&sessionId="
        "${Uri.encodeComponent(_sessionId!)}"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response = await http
          .get(url)
          .timeout(timeout);

      if (response.statusCode != 200) {
        return false;
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(body);

      // =================================================
      // SERVIDOR REJEITOU A SESSÃO
      // =================================================

      if (resultado['success'] != true) {

        limparSessao();

        return false;
      }

      return true;

    } catch (e) {

      // =================================================
      // ATENÇÃO:
      //
      // Erro de internet NÃO apaga a sessão local.
      //
      // Assim, uma pequena falha de conexão não
      // faz o aplicativo perder a identificação
      // da sessão.
      // =================================================

      return false;
    }
  }

  // ===================================================
  // LOGOUT VOLUNTÁRIO
  // ===================================================

  static Future<bool> logout() async {

    if (!possuiSessao) {
      return true;
    }

    final codigo =
        _codigoSessao;

    final sessao =
        _sessionId;

    try {

      final url = Uri.parse(
        "$baseUrl"
        "?tipo=logout"
        "&codigo="
        "${Uri.encodeComponent(codigo!)}"
        "&sessionId="
        "${Uri.encodeComponent(sessao!)}"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response = await http
          .get(url)
          .timeout(
        const Duration(
          seconds: 10,
        ),
      );

      if (response.statusCode != 200) {

        // Não apagamos a sessão local
        // se o servidor não confirmou.
        return false;
      }

      final body =
          jsonDecode(response.body);

      final resultado =
          Map<String, dynamic>.from(body);

      if (resultado['success'] == true) {

        limparSessao();

        return true;
      }

      return false;

    } catch (e) {

      // =================================================
      // IMPORTANTE
      //
      // Se a internet cair durante o logout,
      // NÃO fingimos que o servidor recebeu.
      //
      // A sessão permanece localmente registrada.
      // =================================================

      return false;
    }
  }

  // ===================================================
  // LIMPAR SESSÃO LOCAL
  // ===================================================

  static void limparSessao() {
    _codigoSessao = null;
    _sessionId = null;
  }
}