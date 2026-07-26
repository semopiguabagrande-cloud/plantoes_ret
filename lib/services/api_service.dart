import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "https://script.google.com/macros/s/AKfycbw77y97FCRMsV9a9p6P2ApOODLAnjn7rNBXmNG7jck38gKLuCD7orTpp71b_fIzm35tlg/exec";

  static const Duration timeout =
      Duration(
    seconds: 30,
  );

  // ===================================================
  // LOGIN
  // ===================================================

  static Future<Map<String, dynamic>>
      buscarAgente(
    String codigo,
  ) async {
    try {
      final url = Uri.parse(
        "$baseUrl"
        "?tipo=agente"
        "&codigo=$codigo"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode !=
          200) {
        throw Exception(
          'Erro de conexão.',
        );
      }

      final body =
          jsonDecode(
        response.body,
      );

      return Map<String,
          dynamic>.from(
        body,
      );
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

  static Future<List<dynamic>>
      buscarVagas({
    required String ano,
    required String mes,
  }) async {
    try {
      final url = Uri.parse(
        "$baseUrl"
        "?tipo=vagas"
        "&ano=$ano"
        "&mes=$mes"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode !=
          200) {
        throw Exception(
          'Erro ao buscar vagas.',
        );
      }

      final body =
          jsonDecode(
        response.body,
      );

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
    required List<
            Map<String, dynamic>>
        datas,
  }) async {
    try {
      final jsonDatas =
          jsonEncode(
        datas,
      );

      final url = Uri.parse(
        "$baseUrl"
        "?tipo=salvarInscricao"
        "&ano=$ano"
        "&mes=$mes"
        "&codigo=$codigo"
        "&matricula=$matricula"
        "&nome=${Uri.encodeComponent(nome)}"
        "&datas=${Uri.encodeComponent(jsonDatas)}"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode !=
          200) {
        throw Exception(
          'Erro ao salvar inscrição.',
        );
      }

      final body =
          jsonDecode(
        response.body,
      );

      return Map<String,
          dynamic>.from(
        body,
      );
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
    required List<
            Map<String, dynamic>>
        datas,
  }) async {
    try {
      final jsonDatas =
          jsonEncode(
        datas,
      );

      final url = Uri.parse(
        "$baseUrl"
        "?tipo=cancelarInscricao"
        "&codigo=$codigo"
        "&datas=${Uri.encodeComponent(jsonDatas)}"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode !=
          200) {
        throw Exception(
          'Erro ao cancelar inscrição.',
        );
      }

      final body =
          jsonDecode(
        response.body,
      );

      return Map<String,
          dynamic>.from(
        body,
      );
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

  static Future<
          List<
              Map<String,
                  dynamic>>>
      buscarMinhasInscricoes(
    String codigo,
  ) async {
    try {
      final url = Uri.parse(
        "$baseUrl"
        "?tipo=minhas"
        "&codigo=$codigo"
        "&t=${DateTime.now().millisecondsSinceEpoch}",
      );

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode !=
          200) {
        throw Exception(
          'Erro ao buscar inscrições.',
        );
      }

      final body =
          jsonDecode(
        response.body,
      );

      final dados =
          List<dynamic>.from(
        body,
      );

      return dados
          .map(
            (e) =>
                Map<String,
                    dynamic>.from(
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
// DADOS INICIAIS (AGENTE + VAGAS + INSCRIÇÕES)
// ===================================================

static Future<Map<String, dynamic>> buscarInicial({
  required String codigo,
}) async {
  try {
    final url = Uri.parse(
      "$baseUrl"
      "?tipo=inicial"
      "&codigo=$codigo"
      "&t=${DateTime.now().millisecondsSinceEpoch}",
    );

    final response = await http
        .get(url)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao buscar dados iniciais.',
      );
    }

    final body = jsonDecode(response.body);

    return Map<String, dynamic>.from(body);
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

      final response =
          await http
              .get(url)
              .timeout(timeout);

      if (response.statusCode !=
          200) {
        throw Exception(
          'Erro ao buscar relatório.',
        );
      }

      final body =
          jsonDecode(
        response.body,
      );

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
}