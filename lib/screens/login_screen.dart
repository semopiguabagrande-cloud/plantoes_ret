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

class _LoginScreenState
    extends State<LoginScreen> {
  final TextEditingController
      _codigoController =
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
      // CARREGA SESSÃO SALVA NO NAVEGADOR
      // =================================================

      await ApiService.inicializarSessao();

      if (!mounted) return;

      // =================================================
      // NÃO EXISTE SESSÃO LOCAL
      // =================================================

      if (!ApiService.possuiSessao) {
        debugPrint(
          'Nenhuma sessão salva neste dispositivo.',
        );

        await _mostrarLogin();

        return;
      }

      // =================================================
      // EXISTE SESSÃO LOCAL
      // =================================================

      debugPrint(
        'Sessão encontrada no dispositivo.',
      );

      debugPrint(
        'Código: ${ApiService.codigoSessao}',
      );

      debugPrint(
        'Session ID: ${ApiService.sessionId}',
      );

      // =================================================
      // TENTA RECUPERAR
      // =================================================

      final resultado =
          await ApiService.recuperarSessao();

      if (!mounted) return;

      // =================================================
      // SESSÃO RECUPERADA
      // =================================================

      if (resultado['success'] == true) {
        debugPrint(
          'Sessão recuperada com sucesso.',
        );

        final agente =
            resultado['agente'];

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
            if (!mounted) return;

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

          if (!mounted) return;

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
        // SESSÃO EXISTE MAS DADOS ESTÃO INCOMPLETOS
        // =================================================

        debugPrint(
          'Sessão encontrada, mas agente não foi retornado.',
        );

        await ApiService.limparSessao();
      }
    } catch (e) {
      debugPrint(
        'Erro durante recuperação da sessão: $e',
      );

      // =================================================
      // IMPORTANTE
      //
      // Não apagamos automaticamente uma sessão local
      // somente porque houve erro de conexão.
      // =================================================
    }

    if (!mounted) return;

    await _mostrarLogin();
  }

  // ===================================================
  // MOSTRAR LOGIN
  // ===================================================

  Future<void> _mostrarLogin() async {
    if (!mounted) return;

    setState(() {
      recuperandoSessao = false;
    });

    // Mantém os 5 segundos da tela original.
    await Future.delayed(
      const Duration(
        seconds: 5,
      ),
    );

    if (!mounted) return;

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
    // AINDA RECUPERANDO
    // =================================================

    if (recuperandoSessao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor:
              Colors.orange,
          content: Text(
            'Aguarde a verificação da sessão.',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );

      return;
    }

    final codigo =
        _codigoController.text.trim();

    // =================================================
    // CÓDIGO VAZIO
    // =================================================

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor:
              Colors.red,
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
    // EXISTE SESSÃO LOCAL
    // =================================================

    if (ApiService.possuiSessao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor:
              Colors.orange,
          duration:
              Duration(seconds: 5),
          content: Text(
            'Este navegador já possui uma sessão ativa. '
            'Aguarde a recuperação da sessão ou utilize '
            'SAIR no aplicativo anterior.',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );

      return;
    }

    // =================================================
    // LOGIN
    // =================================================

    try {
      setState(() {
        carregando = true;
      });

      final agente =
          await ApiService.buscarAgente(
        codigo,
      );

      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      // =================================================
      // LOGIN RECUSADO
      // =================================================

      if (agente['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                Colors.red,
            duration:
                const Duration(
              seconds: 5,
            ),
            content: Text(
              agente['mensagem']
                      ?.toString() ??
                  'Agente não encontrado.',
              style:
                  const TextStyle(
                color:
                    Colors.white,
              ),
            ),
          ),
        );

        return;
      }

      // =================================================
      // TIPO
      // =================================================

      final tipo =
          agente['tipo']
                  ?.toString()
                  .trim()
                  .toUpperCase() ??
              'AGENTE';

      // =================================================
      // ADMIN
      // =================================================

      if (tipo == 'ADMIN') {
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

      final sessionId =
          agente['sessionId'];

      if (sessionId == null ||
          sessionId
              .toString()
              .trim()
              .isEmpty) {
        await ApiService.limparSessao();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor:
                Colors.red,
            duration:
                Duration(seconds: 5),
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
      // ENTRA NO AVISO
      // =================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AvisoScreen(
            agente: agente,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.red,
          duration:
              const Duration(
            seconds: 5,
          ),
          content: Text(
            e.toString(),
            style:
                const TextStyle(
              color:
                  Colors.white,
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
    // RECUPERANDO
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
                color:
                    Colors.white,
              ),

              SizedBox(
                height: 20,
              ),

              Text(
                'Verificando sessão...',
                style: TextStyle(
                  color:
                      Colors.white70,
                  fontSize:
                      16,
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
      duration:
          const Duration(
        milliseconds: 2200,
      ),
      curve:
          Curves.easeInOut,
      opacity:
          mostrarLogin
              ? 1
              : 0,
      child:
          AnimatedScale(
        duration:
            const Duration(
          milliseconds: 2200,
        ),
        curve:
            Curves.easeOutBack,
        scale:
            mostrarLogin
                ? 1
                : 0.85,
        child:
            IgnorePointer(
          ignoring:
              !mostrarLogin,
          child:
              LoginCard(
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