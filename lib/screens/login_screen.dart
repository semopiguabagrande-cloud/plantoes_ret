import 'package:flutter/material.dart';

import '../admin/admin_home.dart';
import '../services/api_service.dart';
import '../widgets/login_card.dart';
import 'aviso_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _codigoController =
      TextEditingController();

  bool carregando = false;

  bool mostrarLogin = false;

  bool recuperandoSessao = true;

  // ===================================================
  // INIT
  // ===================================================

  @override
  void initState() {
    super.initState();

    _inicializar();
  }

  // ===================================================
  // INICIALIZAÇÃO
  // ===================================================

  Future<void> _inicializar() async {
    try {
      // =================================================
      // CARREGA SESSÃO LOCAL
      // =================================================

      await ApiService.inicializarSessao();

      if (!mounted) {
        return;
      }

      // =================================================
      // NÃO EXISTE SESSÃO
      // =================================================

      if (!ApiService.possuiSessao) {
        debugPrint(
          'Nenhuma sessão salva.',
        );

        await _mostrarLogin();

        return;
      }

      // =================================================
      // EXISTE SESSÃO
      // =================================================

      debugPrint(
        'Sessão salva encontrada.',
      );

      debugPrint(
        'Código: ${ApiService.codigoSessao}',
      );

      debugPrint(
        'Session ID: ${ApiService.sessionId}',
      );

      // =================================================
      // TENTA RECUPERAR SESSÃO NO SERVIDOR
      // =================================================

      final resultado =
          await ApiService.recuperarSessao();

      if (!mounted) {
        return;
      }

      // =================================================
      // SESSÃO RECUPERADA
      // =================================================

      if (resultado['success'] == true) {
        debugPrint(
          'Sessão recuperada.',
        );

        final agente = resultado['agente'];

        if (agente is Map) {
          final agenteMap =
              Map<String, dynamic>.from(
            agente,
          );

          final tipo =
              agenteMap['tipo']
                      ?.toString()
                      .trim()
                      .toUpperCase() ??
                  'AGENTE';

          // =============================================
          // ADMIN
          // =============================================

          if (tipo == 'ADMIN') {
            debugPrint(
              'Sessão ADMIN recuperada.',
            );

            debugPrint(
              'Código ADMIN: ${ApiService.codigoSessao}',
            );

            debugPrint(
              'Session ID ADMIN: ${ApiService.sessionId}',
            );

            if (!mounted) {
              return;
            }

            setState(() {
              recuperandoSessao = false;
            });

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AdminHome(),
              ),
            );

            return;
          }

          // =============================================
          // AGENTE
          // =============================================

          if (!mounted) {
            return;
          }

          setState(() {
            recuperandoSessao = false;
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AvisoScreen(
                agente: agenteMap,
              ),
            ),
          );

          return;
        }

        // =================================================
        // SESSÃO EXISTE MAS NÃO RETORNOU AGENTE
        // =================================================

        debugPrint(
          'Sessão encontrada, mas agente não retornado.',
        );

        await ApiService.limparSessao();

        if (!mounted) {
          return;
        }

        await _mostrarLogin();

        return;
      }

      // =================================================
      // SESSÃO EXPIRADA
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        debugPrint(
          'Sessão expirada.',
        );

        await ApiService.limparSessao();

        if (!mounted) {
          return;
        }

        await _mostrarLogin();

        return;
      }

      // =================================================
      // ERRO DE CONEXÃO
      //
      // NÃO APAGA A SESSÃO.
      // =================================================

      if (resultado['erroConexao'] == true) {
        debugPrint(
          'Erro de conexão ao recuperar sessão.',
        );

        if (!mounted) {
          return;
        }

        await _mostrarLogin();

        return;
      }

      // =================================================
      // OUTRO RESULTADO
      // =================================================

      debugPrint(
        'Resposta inesperada: $resultado',
      );

      if (!mounted) {
        return;
      }

      await _mostrarLogin();
    } catch (e) {
      debugPrint(
        'Erro ao inicializar: $e',
      );

      // =================================================
      // NÃO APAGA SESSÃO EM CASO DE ERRO
      // =================================================

      if (!mounted) {
        return;
      }

      await _mostrarLogin();
    }
  }

  // ===================================================
  // MOSTRAR LOGIN
  // ===================================================

  Future<void> _mostrarLogin() async {
    if (!mounted) {
      return;
    }

    setState(() {
      recuperandoSessao = false;
    });

    await Future.delayed(
      const Duration(
        seconds: 5,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      mostrarLogin = true;
    });
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  @override
  void dispose() {
    _codigoController.dispose();

    super.dispose();
  }

  // ===================================================
  // LOGIN
  // ===================================================

  Future<void> fazerLogin() async {
    if (carregando) {
      return;
    }

    // =================================================
    // CÓDIGO
    // =================================================

    final codigo =
        _codigoController.text.trim();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Informe o código.',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );

      return;
    }

    // =================================================
    // INICIA LOGIN
    // =================================================

    setState(() {
      carregando = true;
    });

    try {
      debugPrint(
        '========================================',
      );

      debugPrint(
        'Tentando login com código: $codigo',
      );

      debugPrint(
        '========================================',
      );

      // =================================================
      // CONSULTA SERVIDOR
      //
      // É AQUI QUE DESCOBRIMOS SE É ADMIN OU AGENTE.
      //
      // O SERVIDOR TAMBÉM CRIA O SESSION ID.
      // =================================================

      final resultado =
          await ApiService.buscarAgente(
        codigo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        carregando = false;
      });

      // =================================================
      // LOGIN RECUSADO
      // =================================================

      if (resultado['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            duration: const Duration(
              seconds: 5,
            ),
            content: Text(
              resultado['mensagem']
                      ?.toString() ??
                  'Código não autorizado.',
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );

        return;
      }

      // =================================================
      // IDENTIFICA TIPO
      // =================================================

      final tipo =
          resultado['tipo']
                  ?.toString()
                  .trim()
                  .toUpperCase() ??
              'AGENTE';

      debugPrint(
        'Tipo retornado pelo servidor: $tipo',
      );

      // =================================================
      // SESSION ID RETORNADO PELO SERVIDOR
      // =================================================

      final sessionId =
          resultado['sessionId'];

      debugPrint(
        'Session ID retornado pelo servidor: $sessionId',
      );

      // =================================================
      // ADMIN
      //
      // IMPORTANTE:
      //
      // O ADMIN TAMBÉM POSSUI SESSION ID.
      //
      // NÃO PODEMOS MAIS EXECUTAR:
      //
      // await ApiService.limparSessao();
      //
      // pois isso apagaria a sessão antes do acesso
      // ao relatório administrativo.
      // =================================================

      if (tipo == 'ADMIN') {
        debugPrint(
          '========================================',
        );

        debugPrint(
          'LOGIN ADMIN AUTORIZADO.',
        );

        debugPrint(
          'Código ADMIN: ${ApiService.codigoSessao}',
        );

        debugPrint(
          'Session ID ADMIN: ${ApiService.sessionId}',
        );

        debugPrint(
          'Sessão ADMIN será mantida.',
        );

        debugPrint(
          '========================================',
        );

        // =================================================
        // NÃO LIMPAR A SESSÃO AQUI!
        //
        // A sessão será usada pelo:
        //
        // buscarInscricoesPDF()
        //
        // para enviar:
        //
        // codigo
        // sessionId
        //
        // ao Apps Script.
        // =================================================

        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AdminHome(),
          ),
        );

        return;
      }

      // =================================================
      // AGENTE NORMAL
      // =================================================

      // =================================================
      // AGENTE PRECISA DE SESSION ID
      // =================================================

      if (sessionId == null ||
          sessionId
              .toString()
              .trim()
              .isEmpty) {
        debugPrint(
          'Servidor não forneceu sessionId para agente.',
        );

        await ApiService.limparSessao();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            duration: Duration(
              seconds: 5,
            ),
            content: Text(
              'Não foi possível iniciar uma sessão segura. '
              'Tente novamente.',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );

        return;
      }

      // =================================================
      // LOGIN DO AGENTE OK
      // =================================================

      debugPrint(
        '========================================',
      );

      debugPrint(
        'LOGIN DE AGENTE AUTORIZADO.',
      );

      debugPrint(
        'Código: ${ApiService.codigoSessao}',
      );

      debugPrint(
        'Session ID: ${ApiService.sessionId}',
      );

      debugPrint(
        '========================================',
      );

      // =================================================
      // ENTRA NO AVISO
      // =================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AvisoScreen(
            agente: resultado,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        carregando = false;
      });

      debugPrint(
        'Erro no login: $e',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          duration: const Duration(
            seconds: 5,
          ),
          content: Text(
            e.toString(),
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    // =================================================
    // RECUPERANDO SESSÃO
    // =================================================

    if (recuperandoSessao) {
      return const Scaffold(
        backgroundColor:
            Color(0xff021426),
        body: Center(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
              ),

              SizedBox(
                height: 20,
              ),

              Text(
                'Verificando sessão...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // =================================================
    // LOGIN
    // =================================================

    return AnimatedOpacity(
      duration: const Duration(
        milliseconds: 2200,
      ),
      curve: Curves.easeInOut,
      opacity:
          mostrarLogin
              ? 1
              : 0,
      child: AnimatedScale(
        duration: const Duration(
          milliseconds: 2200,
        ),
        curve: Curves.easeOutBack,
        scale:
            mostrarLogin
                ? 1
                : 0.85,
        child: IgnorePointer(
          ignoring: !mostrarLogin,
          child: LoginCard(
            controller:
                _codigoController,
            carregando:
                carregando,
            onLogin:
                fazerLogin,
          ),
        ),
      ),
    );
  }
}