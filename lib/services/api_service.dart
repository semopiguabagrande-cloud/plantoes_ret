import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  // IDENTIFICAÇÃO DO CLIENTE E VERSÃO
  // ===================================================

  static const String versaoAplicativo = '2.0.0+2';

  static String get identificacaoCliente {
    final cliente = kIsWeb ? 'flutter_web' : 'flutter_app';

    return '&cliente=$cliente'
        '&versao=${Uri.encodeComponent(versaoAplicativo)}';
  }

  // ===================================================
  // CHAVES DA SESSÃO SALVA
  // ===================================================

  static const String _chaveCodigo = 'sessao_codigo';
  static const String _chaveSessionId = 'sessao_session_id';

  // ===================================================
  // CHAVE DA TENTATIVA DE LOGIN
  // ===================================================

  // Este identificador é criado antes do primeiro login.
  //
  // Se o servidor criar a sessão, mas a resposta demorar
  // e o Flutter atingir o timeout, o mesmo tentativaId
  // será usado novamente no próximo login.
  //
  // Dessa forma o Apps Script consegue reconhecer que
  // trata-se da mesma tentativa e devolver a sessão criada.
  static const String _chaveTentativaLogin =
      'login_tentativa_id';

  static const String _chaveCodigoTentativaLogin =
      'login_tentativa_codigo';

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
  // GERAR IDENTIFICADOR DE TENTATIVA DE LOGIN
  // ===================================================

  static String _gerarTentativaId() {
    final agora = DateTime.now().microsecondsSinceEpoch;

    final aleatorio = Random.secure()
        .nextInt(0x7fffffff)
        .toRadixString(16);

    return '$agora-$aleatorio';
  }

  // ===================================================
  // OBTER / CRIAR TENTATIVA DE LOGIN
  // ===================================================

  static Future<String> _obterTentativaLogin(
    String codigo,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final codigoTentativa = prefs.getString(
      _chaveCodigoTentativaLogin,
    );

    final tentativaExistente = prefs.getString(
      _chaveTentativaLogin,
    );

    // =================================================
    // MESMO CÓDIGO
    // =================================================
    //
    // Se o usuário está tentando novamente entrar com o
    // mesmo código, reutilizamos o tentativaId.
    //
    // Isso é fundamental para o caso de internet lenta:
    //
    // tentativa 1 cria a sessão no servidor;
    // resposta demora;
    // Flutter dá timeout;
    // tentativa 2 usa o mesmo tentativaId;
    // servidor devolve a sessão já criada.
    //

    if (codigoTentativa == codigo &&
        tentativaExistente != null &&
        tentativaExistente.trim().isNotEmpty) {
      return tentativaExistente;
    }

    // =================================================
    // NOVO CÓDIGO OU NENHUMA TENTATIVA EXISTENTE
    // =================================================

    final novaTentativa = _gerarTentativaId();

    await prefs.setString(
      _chaveCodigoTentativaLogin,
      codigo,
    );

    await prefs.setString(
      _chaveTentativaLogin,
      novaTentativa,
    );

    return novaTentativa;
  }

  // ===================================================
  // LIMPAR TENTATIVA DE LOGIN
  // ===================================================

  static Future<void> _limparTentativaLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_chaveTentativaLogin);
      await prefs.remove(_chaveCodigoTentativaLogin);
    } catch (e) {
      debugPrint('Limpar tentativa de login: erro: $e');
    }
  }

  // ===================================================
  // LOGIN
  // ===================================================

  static Future<Map<String, dynamic>> buscarAgente(
    String codigo,
  ) async {
    try {
      final codigoNormalizado = codigo.trim();

      if (codigoNormalizado.isEmpty) {
        return {
          'success': false,
          'mensagem': 'Código não informado.',
        };
      }

      // =================================================
      // OBTÉM UMA TENTATIVA PERSISTENTE
      // =================================================
      //
      // IMPORTANTE:
      //
      // O tentativaId NÃO é recriado a cada chamada.
      //
      // Se a primeira requisição chegar ao Apps Script,
      // criar a sessão e depois estourar o timeout,
      // a segunda chamada usará exatamente o mesmo ID.
      //

      final tentativaId = await _obterTentativaLogin(
        codigoNormalizado,
      );

      debugPrint('========================================');
      debugPrint('INICIANDO LOGIN');
      debugPrint('Código: $codigoNormalizado');
      debugPrint('Tentativa ID: $tentativaId');
      debugPrint('========================================');

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=agente'
        '&codigo=${Uri.encodeComponent(codigoNormalizado)}'
        '&tentativaId=${Uri.encodeComponent(tentativaId)}'
        '$identificacaoCliente'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      debugPrint('Enviando solicitação de login...');

      final response = await http.get(url).timeout(timeout);

      debugPrint('Login HTTP: ${response.statusCode}');
      debugPrint('Login resposta: ${response.body}');

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
        // SESSION ID É OBRIGATÓRIO PARA TODOS
        // INCLUSIVE ADMINISTRADOR
        // =================================================

        if (novaSessao == null ||
            novaSessao.toString().trim().isEmpty) {
          return {
            'success': false,
            'mensagem':
                'O servidor não forneceu uma sessão válida.',
          };
        }

        // =================================================
        // SALVA SESSÃO DO USUÁRIO
        // =================================================

        _codigoSessao = codigoNormalizado;
        _sessionId = novaSessao.toString();

        await _salvarSessaoLocal();

        // =================================================
        // LOGIN CONCLUÍDO
        //
        // A tentativa pode ser apagada agora porque já
        // temos o sessionId salvo localmente.
        // =================================================

        await _limparTentativaLogin();

        final tipo =
            resultado['tipo']?.toString().trim().toUpperCase() ??
                '';

        debugPrint('Login $tipo autorizado.');
        debugPrint('Session ID: $_sessionId');

        return resultado;
      }

      // =================================================
      // LOGIN NEGADO
      // =================================================
      //
      // Se o servidor informou que já existe sessão ativa
      // em outro dispositivo, NÃO apagamos o tentativaId.
      //
      // Isso evita perder a identificação da tentativa.
      //

      debugPrint(
        'Login não autorizado: '
        '${resultado['mensagem'] ?? 'sem mensagem'}',
      );

      return resultado;
    } on TimeoutException {
      // =================================================
      // IMPORTANTE:
      //
      // NÃO apagamos o tentativaId aqui.
      //
      // A sessão pode ter sido criada no servidor mesmo
      // que a resposta não tenha chegado ao celular.
      //
      // Na próxima tentativa, o mesmo tentativaId será
      // enviado novamente.
      // =================================================

      debugPrint(
        'LOGIN: timeout. '
        'Tentativa preservada para nova tentativa.',
      );

      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      debugPrint('Buscar agente: erro: $e');

      throw Exception('Erro ao buscar agente.\n$e');
    }
  }

  // ===================================================
  // RECUPERAR SESSÃO
  // ===================================================

  static Future<Map<String, dynamic>> recuperarSessao() async {
    try {
      // Carrega a sessão salva.
      await inicializarSessao();

      if (!possuiSessao) {
        return {
          'success': false,
          'sessaoExpirada': true,
          'mensagem':
              'Nenhuma sessão salva neste dispositivo.',
        };
      }

      final codigo = _codigoSessao!;
      final sessao = _sessionId!;

      // Verifica diretamente no servidor.
      // Não usa heartbeat aqui.
      final url = Uri.parse(
        '$baseUrl'
        '?tipo=recuperarSessao'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(sessao)}'
        '$identificacaoCliente'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(url).timeout(timeout);

      // Erro HTTP: não apaga a sessão local.
      if (response.statusCode != 200) {
        return {
          'success': false,
          'erroConexao': true,
          'mensagem':
              'Não foi possível verificar a sessão.',
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
      // SERVIDOR CONFIRMOU QUE A SESSÃO NÃO EXISTE
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
        return resultado;
      }

      // Resposta inesperada: não apaga a sessão.
      return {
        ...resultado,
        'success': false,
        'erroConexao': false,
      };
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
      if (!possuiSessao) {
        throw Exception(
          'Sessão não encontrada. Faça login novamente.',
        );
      }

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=vagas'
        '&ano=${Uri.encodeComponent(ano)}'
        '&mes=${Uri.encodeComponent(mes)}'
        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(identificacaoCliente);
      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final url = Uri.parse(parametros.toString());

      debugPrint('========================================');
      debugPrint('BUSCANDO VAGAS');
      debugPrint('Código: $_codigoSessao');
      debugPrint('Session ID: $_sessionId');

      final response = await http.get(url).timeout(timeout);

      debugPrint('Vagas HTTP: ${response.statusCode}');
      debugPrint('Vagas resposta: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar vagas.');
      }

      final body = jsonDecode(response.body);

      if (body is List) {
        return List<dynamic>.from(body);
      }

      if (body is Map) {
        final resultado = Map<String, dynamic>.from(body);

        if (resultado['sessaoExpirada'] == true) {
          await limparSessao();

          throw Exception(
            resultado['mensagem']?.toString() ??
                'Sessão inválida ou encerrada.',
          );
        }

        throw Exception(
          resultado['mensagem']?.toString() ??
              'Erro ao buscar vagas.',
        );
      }

      throw Exception(
        'Resposta inválida ao buscar vagas.',
      );
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      debugPrint('Buscar vagas: erro: $e');
      throw Exception('Erro ao buscar vagas.\n$e');
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
          'mensagem':
              'Sessão não encontrada. Faça login novamente.',
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

      parametros.write(identificacaoCliente);
      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Erro ao salvar inscrição.');
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception(
          'Resposta inválida ao salvar inscrição.',
        );
      }

      final resultado = Map<String, dynamic>.from(body);

      // Só apaga se o servidor confirmar expiração.
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
          'mensagem':
              'Sessão não encontrada. Faça login novamente.',
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

      parametros.write(identificacaoCliente);
      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao cancelar inscrição.',
        );
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception(
          'Resposta inválida ao cancelar inscrição.',
        );
      }

      final resultado = Map<String, dynamic>.from(body);

      // Só apaga se o servidor confirmar expiração.
      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
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

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=minhas'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(identificacaoCliente);
      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar inscrições.',
        );
      }

      final body = jsonDecode(response.body);

      // Resposta em MAP = possível erro do servidor.
      if (body is Map) {
        final resultado = Map<String, dynamic>.from(body);

        if (resultado['sessaoExpirada'] == true) {
          await limparSessao();
        }

        throw Exception(
          resultado['mensagem'] ??
              'Erro ao buscar inscrições.',
        );
      }

      if (body is! List) {
        throw Exception(
          'Resposta inválida ao buscar inscrições.',
        );
      }

      final dados = List<dynamic>.from(body);

      return dados
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception(
        'Erro ao buscar inscrições.\n$e',
      );
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
          'mensagem':
              'Sessão não encontrada. Faça login novamente.',
        };
      }

      final parametros = StringBuffer(
        '$baseUrl'
        '?tipo=inicial'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}',
      );

      parametros.write(identificacaoCliente);
      parametros.write(
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http
          .get(Uri.parse(parametros.toString()))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar dados iniciais.',
        );
      }

      final body = jsonDecode(response.body);

      if (body is! Map) {
        throw Exception(
          'Resposta inválida ao buscar dados iniciais.',
        );
      }

      final resultado = Map<String, dynamic>.from(body);

      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
      }

      return resultado;
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      throw Exception(
        'Erro ao buscar dados iniciais.\n$e',
      );
    }
  }

  // ===================================================
  // RELATÓRIO ADMINISTRATIVO
  // ===================================================

  static Future<List<dynamic>> buscarInscricoesPDF() async {
    try {
      // Garante que a sessão salva foi carregada.
      await inicializarSessao();

      if (!possuiSessao) {
        throw Exception(
          'Sessão do administrador não encontrada. '
          'Faça login novamente.',
        );
      }

      final codigo = _codigoSessao!;
      final sessionId = _sessionId!;

      debugPrint(
        '==========================================',
      );
      debugPrint('RELATÓRIO ADMINISTRATIVO');
      debugPrint('Código: $codigo');
      debugPrint('Session ID: $sessionId');
      debugPrint(
        '==========================================',
      );

      final url = Uri.parse(
        '$baseUrl'
        '?tipo=relatorio'
        '&codigo=${Uri.encodeComponent(codigo)}'
        '&sessionId=${Uri.encodeComponent(sessionId)}'
        '$identificacaoCliente'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      debugPrint('Consultando relatório...');
      debugPrint('URL: $url');

      final response = await http.get(url).timeout(timeout);

      debugPrint(
        'Relatório HTTP: ${response.statusCode}',
      );
      debugPrint(
        'Relatório resposta: ${response.body}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao buscar relatório. '
          'Código HTTP: ${response.statusCode}',
        );
      }

      final body = jsonDecode(response.body);

      // Resposta normal = lista.
      if (body is List) {
        debugPrint(
          'Relatório recebido com '
          '${body.length} registros.',
        );

        return List<dynamic>.from(body);
      }

      // Resposta em MAP.
      if (body is Map) {
        final resultado = Map<String, dynamic>.from(body);

        debugPrint(
          'Relatório retornou MAP: $resultado',
        );

        if (resultado['sessaoExpirada'] == true) {
          await limparSessao();

          throw Exception(
            resultado['mensagem']?.toString() ??
                'Sessão do administrador inválida ou encerrada.',
          );
        }

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

        final mensagem =
            resultado['mensagem'] ??
            resultado['erro'] ??
            resultado['error'];

        if (mensagem != null) {
          throw Exception(mensagem.toString());
        }

        throw Exception(
          'O servidor retornou uma resposta inesperada '
          'ao buscar o relatório.',
        );
      }

      throw Exception(
        'Resposta inválida ao buscar relatório.',
      );
    } on TimeoutException {
      throw Exception('Tempo de conexão esgotado.');
    } catch (e) {
      debugPrint('ERRO RELATÓRIO: $e');

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
        '$baseUrl'
        '?tipo=heartbeat'
        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'
        '&sessionId=${Uri.encodeComponent(_sessionId!)}'
        '$identificacaoCliente'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(url).timeout(timeout);

      // Em caso de falha de comunicação,
      // preserva a sessão.
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

      // Só limpa a sessão se o servidor confirmar
      // a expiração.
      if (resultado['sessaoExpirada'] == true) {
        await limparSessao();
        return false;
      }

      // Resposta indeterminada:
      // preserva a sessão.
      return true;
    } catch (e) {
      debugPrint(
        'Heartbeat: erro de conexão: $e',
      );

      // Internet/timeout não deve apagar
      // a sessão local.
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
        '$identificacaoCliente'
        '&t=${DateTime.now().millisecondsSinceEpoch}',
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

      // Limpa a sessão somente após confirmação
      // do servidor.
      if (resultado['success'] == true) {
        await limparSessao();

        // Logout encerrado:
        // uma próxima entrada deverá ser considerada
        // uma nova tentativa.
        await _limparTentativaLogin();

        return true;
      }

      return false;
    } catch (e) {
      debugPrint(
        'Logout: erro de conexão: $e',
      );

      // Preserva a sessão local em caso de falha.
      return false;
    }
  }
}