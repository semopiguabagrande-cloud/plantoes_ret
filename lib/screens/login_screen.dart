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

  /// controla quando o card aparece
  bool mostrarLogin = false;

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

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> fazerLogin() async {
  if (carregando) return;

  final codigo =
      _codigoController.text.trim();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          backgroundColor:
              Colors.red,
          content: Text(
            'Informe o código.',
            style: TextStyle(
              color:
                  Colors.white,
            ),
          ),
        ),
      );

      return;
    }

    try {
      setState(() {
        carregando = true;
      });

      final agente =
          await ApiService
              .buscarAgente(
        codigo,
      );

      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      if (agente['success'] !=
          true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            backgroundColor:
                Colors.red,
            content: Text(
              agente[
                          'mensagem']
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

      final tipo =
          agente['tipo']
                  ?.toString()
                  .toUpperCase() ??
              'AGENTE';

      if (tipo ==
          'ADMIN') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AdminHome(),
          ),
        );

        return;
      }

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
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

  @override
  Widget build(
    BuildContext context,
  ) {
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