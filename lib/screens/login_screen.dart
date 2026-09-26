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
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _codigoController =
      TextEditingController();

  bool carregando = false;

  bool mostrarLogin = false;

  bool recuperandoSessao = true;

  // Código que gerou conflito de "outro dispositivo".
  String? _codigoConflito;

  bool get isDesktop =>
      MediaQuery.of(context).size.width >= 800;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  // ===================================================
  // MONTA O MAPA DO AGENTE A PARTIR DA RESPOSTA
  // ===================================================

  Map<String, dynamic>? _agenteDoResultado(
    Map<String, dynamic> resultado,
  ) {
    final aninhado = resultado['agente'];

    if (aninhado is Map) {
      return Map<String, dynamic>.from(aninhado);
    }

    if (resultado['codigo'] != null ||
        resultado['tipo'] != null ||
        resultado['nome'] != null) {
      return {
        'codigo': resultado['codigo'],
        'matricula': resultado['matricula'],
        'nome': resultado['nome'],
        'tipo': resultado['tipo'],
        'ferias': resultado['ferias'],
      };
    }

    return null;
  }

  // ===================================================
  // INICIALIZAÇÃO
  // ===================================================

  Future<void> _inicializar() async {
    try {
      await ApiService.inicializarSessao();

      if (!mounted) return;

      if (!ApiService.possuiSessao) {
        debugPrint('Nenhuma sessão salva.');
        await _mostrarLogin();
        return;
      }

      debugPrint('Sessão salva encontrada.');
      debugPrint('Código: ${ApiService.codigoSessao}');
      debugPrint('Session ID: ${ApiService.sessionId}');

      final resultado = await ApiService.recuperarSessao();

      if (!mounted) return;

      // =================================================
      // SESSÃO RECUPERADA
      // =================================================

      if (resultado['success'] == true) {
        debugPrint('Sessão recuperada.');

        final agenteMap = _agenteDoResultado(
          Map<String, dynamic>.from(resultado),
        );

        if (agenteMap != null) {
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
            debugPrint('Sessão ADMIN recuperada.');

            if (!mounted) return;

            setState(() {
              recuperandoSessao = false;
            });

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminHome(),
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
              builder: (_) => AvisoScreen(
                agente: agenteMap,
              ),
            ),
          );

          return;
        }

        debugPrint(
          'Sessão encontrada, mas agente não retornado.',
        );

        await ApiService.limparSessao();

        if (!mounted) return;

        await _mostrarLogin();
        return;
      }

      // =================================================
      // SESSÃO EXPIRADA
      // =================================================

      if (resultado['sessaoExpirada'] == true) {
        debugPrint('Sessão expirada.');

        await ApiService.limparSessao();

        if (!mounted) return;

        await _mostrarLogin();
        return;
      }

      // =================================================
      // ERRO DE CONEXÃO — NÃO APAGA A SESSÃO
      // =================================================

      if (resultado['erroConexao'] == true) {
        debugPrint('Erro de conexão ao recuperar sessão.');

        if (!mounted) return;

        await _mostrarLogin();
        return;
      }

      debugPrint('Resposta inesperada: $resultado');

      if (!mounted) return;

      await _mostrarLogin();
    } catch (e) {
      debugPrint('Erro ao inicializar: $e');

      if (!mounted) return;

      await _mostrarLogin();
    }
  }

  // ===================================================
  // MOSTRAR LOGIN
  // ===================================================

  Future<void> _mostrarLogin() async {
    if (!mounted) return;

    setState(() {
      recuperandoSessao = false;
    });

    // Pequena pausa só para a animação de entrada.
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    setState(() {
      mostrarLogin = true;
    });
  }

  // ===================================================
  // DIÁLOGO "ENTRAR MESMO ASSIM"
  // ===================================================

  Future<void> _mostrarDialogoConflito(
    String codigo,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff0b2239),
          title: const Text(
            'Sessão ativa em outro dispositivo',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Este código já está conectado em outro dispositivo.\n\n'
            'Se você continuar, a sessão do outro aparelho será encerrada '
            'e você entrará neste aqui.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Entrar mesmo assim'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await fazerLogin(forcar: true);
    }
  }

  // ===================================================
  // LOGIN
  // ===================================================

  Future<void> fazerLogin({
    bool forcar = false,
  }) async {
    if (carregando) return;

    final codigo = forcar && _codigoConflito != null
        ? _codigoConflito!
        : _codigoController.text.trim();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Informe o código.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      debugPrint('========================================');
      debugPrint(
        'Tentando login com código: $codigo (forçar: $forcar)',
      );
      debugPrint('========================================');

      final resultado = await ApiService.buscarAgente(
        codigo,
        forcar: forcar,
      );

      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      // =================================================
      // CONFLITO: JÁ LOGADO EM OUTRO DISPOSITIVO
      // =================================================

      if (resultado['success'] != true &&
          resultado['codigoConflito'] == true) {
        _codigoConflito = codigo;

        await _mostrarDialogoConflito(codigo);

        return;
      }

      // =================================================
      // LOGIN RECUSADO (OUTROS MOTIVOS)
      // =================================================

      if (resultado['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            content: Text(
              resultado['mensagem']?.toString() ??
                  'Código não autorizado.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      _codigoConflito = null;

      // =================================================
      // IDENTIFICA TIPO
      // =================================================

      final tipo =
          resultado['tipo']?.toString().trim().toUpperCase() ??
              'AGENTE';

      final sessionId = resultado['sessionId'];

      // =================================================
      // ADMIN
      // =================================================

      if (tipo == 'ADMIN') {
        debugPrint('LOGIN ADMIN AUTORIZADO.');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminHome(),
          ),
        );

        return;
      }

      // =================================================
      // AGENTE NORMAL
      // =================================================

      if (sessionId == null ||
          sessionId.toString().trim().isEmpty) {
        debugPrint(
          'Servidor não forneceu sessionId para agente.',
        );

        await ApiService.limparSessao();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            content: Text(
              'Não foi possível iniciar uma sessão segura. '
              'Tente novamente.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      debugPrint('LOGIN DE AGENTE AUTORIZADO.');

      final agenteMap = _agenteDoResultado(
            Map<String, dynamic>.from(resultado),
          ) ??
          Map<String, dynamic>.from(resultado);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AvisoScreen(
            agente: agenteMap,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      debugPrint('Erro no login: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // =================================================
          // FUNDO
          // =================================================

          Positioned.fill(
            child: Image.asset(
              isDesktop
                  ? 'assets/images/pc_login_bg.png'
                  : 'assets/images/mobile_login_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // =================================================
          // ESCURECIMENTO
          // =================================================

          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              color: mostrarLogin
                  ? Colors.black.withValues(alpha: .35)
                  : Colors.transparent,
            ),
          ),

          // =================================================
          // RECUPERANDO SESSÃO
          // =================================================

          if (recuperandoSessao)
            const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
            ),

          // =================================================
          // LOGIN
          // =================================================

          if (mostrarLogin)
            SafeArea(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  opacity: mostrarLogin ? 1 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    scale: mostrarLogin ? 1 : .85,
                    child: LoginCard(
                      controller: _codigoController,
                      carregando: carregando,
                      onLogin: () => fazerLogin(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
