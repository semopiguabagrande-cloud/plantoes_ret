import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onLogin;
  final bool carregando;

  const LoginCard({
    super.key,
    required this.controller,
    required this.onLogin,
    required this.carregando,
  });

  @override
  State<LoginCard> createState() =>
      _LoginCardState();
}

class _LoginCardState
    extends State<LoginCard> {
  @override
  Widget build(
    BuildContext context,
  ) {
    final desktop =
        MediaQuery.of(context)
                .size
                .width >
            800;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            30,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
            ),
            child: Container(
              width:
                  desktop
                      ? 520
                      : 340,
              padding:
                  const EdgeInsets.all(
                35,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withOpacity(
                  .10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  30,
                ),
                border:
                    Border.all(
                  color:
                      Colors.white24,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black
                            .withOpacity(
                      .35,
                    ),
                    blurRadius: 30,
                    offset:
                        const Offset(
                      0,
                      15,
                    ),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/brasao.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Text(
                    'PLANTÕES RET',
                    style:
                        TextStyle(
                      color:
                          Colors
                              .amber
                              .shade300,
                      fontSize:
                          desktop
                              ? 30
                              : 24,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Acesso ao Sistema',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 35,
                  ),

                  TextField(
  controller:
      widget.controller,

  keyboardType:
      const TextInputType.numberWithOptions(
    decimal: false,
    signed: false,
  ),

  inputFormatters: [
    FilteringTextInputFormatter
        .digitsOnly,
  ],

  textInputAction:
      TextInputAction.done,
                    onSubmitted:
                        (_) {
                      if (!widget
                          .carregando) {
                        widget
                            .onLogin();
                      }
                    },
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Código do agente',
                      prefixIcon:
                          Icon(
                        Icons.badge,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 35,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 60,
                    child:
                        ElevatedButton(
                      onPressed:
                          widget
                                  .carregando
                              ? null
                              : widget
                                  .onLogin,
                      child:
                          widget
                                  .carregando
                              ? const SizedBox(
                                  width: 25,
                                  height: 25,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        3,
                                    color:
                                        Colors
                                            .white,
                                  ),
                                )
                              : const Text(
                                  'ENTRAR',
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}