import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();

    Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          mostrarLogin = true;
        });
      },
    );
  }

  bool get isDesktop =>
      MediaQuery.of(context).size.width >=
      800;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Stack(
        children: [

          /// FUNDO
          Positioned.fill(
            child: Image.asset(
              isDesktop
                  ? 'assets/images/pc_login_bg.png'
                  : 'assets/images/mobile_login_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          /// ESCURECIMENTO AO EXIBIR LOGIN
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
                      ? Colors.black
                          .withOpacity(
                          .35,
                        )
                      : Colors
                          .transparent,
            ),
          ),

          /// LOGIN
          SafeArea(
            child: Center(
              child:
                  AnimatedOpacity(
                duration:
                    const Duration(
                  milliseconds:
                      900,
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
                    milliseconds:
                        900,
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