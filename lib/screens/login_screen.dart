import 'package:flutter/material.dart';

import '../admin/admin_home.dart';
import '../agente/home_screen.dart';
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

  /// Controla quando o card de login aparece.
  bool mostrarLogin = false;

  // ===================================================
  // INIT
  // ===================================================

  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(
        seconds: 5,
      ),
      () {
        if (!mounted) return;

        setState(() {
          mostrarLogin = true;
        });
      },
    );
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
    // Impede dois cliques simultâneos.
    if (carregando) {
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
    // SEGURANÇA LOCAL
    // =================================================
    //
    // Se este aplicativo já possui uma sessão,
    // não devemos tentar criar outra.
    //
    // Isso normalmente acontece se o usuário voltou
    // para a tela de login sem fazer logout.
    // =================================================

    if (ApiService.possuiSessao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
          content: Text(
            'Este aplicativo já possui uma sessão ativa. '
            'Faça logout antes de entrar novamente.',
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

    try {
      setState(() {
        carregando = true;
      });

      final agente =
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

      if (agente['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            duration: const Duration(
              seconds: 5,
            ),
            content: Text(
              agente['mensagem']
                      ?.toString() ??
                  'Agente não encontrado.',
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );

        return;
      }

      // =================================================
      // TIPO DO USUÁRIO
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
      //
      // Um agente normal precisa obrigatoriamente
      // possuir SESSION_ID.
      //
      // Se não possuir, não entramos no aplicativo.
      // =================================================

      final sessionId =
          agente['sessionId'];

      if (sessionId == null ||
          sessionId.toString().trim().isEmpty) {
        // Garante que não fique nenhuma sessão local
        // incompleta.
        ApiService.limparSessao();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
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
      // VAI PARA AVISO
      // =================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AvisoScreen(
            agente: agente,
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
    return AnimatedOpacity(
      duration: const Duration(
        milliseconds: 2200,
      ),
      curve: Curves.easeInOut,
      opacity: mostrarLogin ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(
          milliseconds: 2200,
        ),
        curve: Curves.easeOutBack,
        scale: mostrarLogin ? 1 : 0.85,
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