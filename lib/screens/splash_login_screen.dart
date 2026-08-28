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

class _SplashLoginScreenState
    extends State<SplashLoginScreen> {

  bool mostrarLogin = false;

  bool carregandoSessao = true;

  @override
  void initState() {
    super.initState();

    recuperarSessao();
  }

  // ===================================================
  // RECUPERAR SESSÃO AO ABRIR O APLICATIVO
  // ===================================================

  Future<void> recuperarSessao() async {

    try {

      debugPrint(
        '========================================',
      );

      debugPrint(
        'INICIANDO RECUPERAÇÃO DA SESSÃO',
      );

      debugPrint(
        '========================================',
      );


      // =================================================
      // TENTA RECUPERAR A SESSÃO SALVA
      // =================================================

      final resultado =
          await ApiService.recuperarSessao();


      debugPrint(
        'Resultado recuperação: $resultado',
      );


      if (!mounted) {
        return;
      }


      // =================================================
      // SESSÃO ENCONTRADA E VÁLIDA
      // =================================================

      if (
        resultado['success'] == true &&
        resultado['sessaoRecuperada'] == true &&
        resultado['agente'] is Map
      ) {

        debugPrint(
          'SESSÃO RECUPERADA COM SUCESSO.',
        );


        final agente =
            Map<String, dynamic>.from(
          resultado['agente'],
        );


        // =================================================
        // ENTRA DIRETAMENTE NA HOME
        // =================================================

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                HomeScreen(
              agente: agente,
            ),
          ),
        );


        return;

      }


      // =================================================
      // NÃO EXISTE SESSÃO VÁLIDA
      // MOSTRA LOGIN
      // =================================================

      debugPrint(
        'Nenhuma sessão válida encontrada.',
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
        'ERRO AO RECUPERAR SESSÃO: $e',
      );


      if (!mounted) {
        return;
      }


      // =================================================
      // EM CASO DE ERRO
      //
      // Mostra o login.
      //
      // A ApiService é responsável por decidir
      // se deve ou não apagar a sessão local.
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
  Widget build(
    BuildContext context,
  ) {

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

              duration:
                  const Duration(
                milliseconds: 800,
              ),

              curve:
                  Curves.easeInOut,

              color:
                  mostrarLogin
                      ? Colors.black.withOpacity(.35)
                      : Colors.transparent,

            ),

          ),


          // =================================================
          // INDICADOR ENQUANTO RECUPERA A SESSÃO
          // =================================================

          if (carregandoSessao)

            const Center(

              child: SizedBox(

                width: 40,

                height: 40,

                child:
                    CircularProgressIndicator(),

              ),

            ),


          // =================================================
          // LOGIN
          // =================================================

          if (mostrarLogin)

            SafeArea(

              child: Center(

                child: AnimatedOpacity(

                  duration:
                      const Duration(
                    milliseconds: 900,
                  ),

                  curve:
                      Curves.easeInOut,

                  opacity:
                      mostrarLogin
                          ? 1
                          : 0,

                  child: AnimatedScale(

                    duration:
                        const Duration(
                      milliseconds: 900,
                    ),

                    curve:
                        Curves.easeOutBack,

                    scale:
                        mostrarLogin
                            ? 1
                            : .85,

                    child:
                        const LoginScreen(),

                  ),

                ),

              ),

            ),

        ],

      ),

    );

  }

}