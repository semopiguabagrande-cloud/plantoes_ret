
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../agente/home_screen.dart';
import 'login_screen.dart';

class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({
    super.key,
  });

  @override
  State<SplashLoginScreen> createState() =>
      _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> {
  bool mostrarLogin = false;

  bool carregandoSessao = true;

  @override
  void initState() {
    super.initState();

    recuperarSessao();
  }

  // ===================================================
  // RECUPERAR SESSÃƒO AO ABRIR O APLICATIVO
  // ===================================================

  Future<void> recuperarSessao() async {
    try {
      debugPrint(
        '========================================',
      );

      debugPrint(
        'INICIANDO RECUPERAÃ‡ÃƒO DA SESSÃƒO',
      );

      debugPrint(
        '========================================',
      );

      // =================================================
      // TENTA RECUPERAR A SESSÃƒO SALVA
      // =================================================

      final resultado = await ApiService.recuperarSessao();

      debugPrint(
        'Resultado recuperaÃ§Ã£o: $resultado',
      );

      if (!mounted) {
        return;
      }

      // =================================================
      // SESSÃƒO ENCONTRADA E VÃLIDA
      // =================================================

      if (resultado['success'] == true &&
          resultado['sessaoRecuperada'] == true &&
          resultado['agente'] is Map) {
        debugPrint(
          'SESSÃƒO RECUPERADA COM SUCESSO.',
        );

        final agente = Map<String, dynamic>.from(
          resultado['agente'],
        );

        // =================================================
        // ENTRA DIRETAMENTE NA HOME
        // =================================================

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              agente: agente,
            ),
          ),
        );

        return;
      }

      // =================================================
      // NÃƒO EXISTE SESSÃƒO VÃLIDA
      // MOSTRA LOGIN
      // =================================================

      debugPrint(
        'Nenhuma sessÃ£o vÃ¡lida encontrada.',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        carregandoSessao = false;
        mostrarLogin = true;
      });
    } catch (e) {
      debugPrint(
        'ERRO AO RECUPERAR SESSÃƒO: $e',
      );

      if (!mounted) {
        return;
      }

      // =================================================
      // EM CASO DE ERRO
      //
      // Mostra o login.
      //
      // A ApiService Ã© responsÃ¡vel por decidir
      // se deve ou nÃ£o apagar a sessÃ£o local.
      // =================================================

      setState(() {
        carregandoSessao = false;
        mostrarLogin = true;
      });
    }
  }

  // ===================================================
  // DESKTOP
  // ===================================================

  bool get isDesktop =>
      MediaQuery.of(context).size.width >= 800;

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
          // ESCURECIMENTO DO LOGIN
          // =================================================

          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 800,
              ),
              curve: Curves.easeInOut,
              color: mostrarLogin
                  ? Colors.black.withValues(alpha: .35)
                  : Colors.transparent,
            ),
          ),

          // =================================================
          // INDICADOR ENQUANTO RECUPERA A SESSÃƒO
          // =================================================

          if (carregandoSessao)
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
                  duration: const Duration(
                    milliseconds: 900,
                  ),
                  curve: Curves.easeInOut,
                  opacity: mostrarLogin ? 1 : 0,
                  child: AnimatedScale(
                    duration: const Duration(
                      milliseconds: 900,
                    ),
                    curve: Curves.easeOutBack,
                    scale: mostrarLogin ? 1 : .85,
                    child: const LoginScreen(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}