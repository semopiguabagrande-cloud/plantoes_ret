import 'package:flutter/material.dart';

import '../agente/home_screen.dart';

class AvisoScreen extends StatefulWidget {
  final Map<String, dynamic> agente;

  const AvisoScreen({
    super.key,
    required this.agente,
  });

  @override
  State<AvisoScreen> createState() =>
      _AvisoScreenState();
}

class _AvisoScreenState
    extends State<AvisoScreen> {
  bool aceitou = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xff021426,
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(
            18,
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 8,
              ),

              const Text(
                'AVISO',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 36,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Expanded(
                flex: 3,
                child: Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white10,
                    borderRadius:
                        BorderRadius.circular(
                      25,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white54,
                    ),
                  ),
                  child: RichText(
                    textAlign:
                        TextAlign.justify,
                    text: const TextSpan(
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text:
                              'A participação no Sistema de Plantões RET é destinada aos servidores autorizados pela Guarda Civil Municipal, observadas as normas institucionais vigentes.\n\n'
                              'É obrigatório o comparecimento devidamente uniformizado, utilizando exclusivamente o uniforme operacional azul-marinho oficial da Corporação.\n\n'
                              'Os Plantões RET destinam-se, a princípio, à execução de serviços operacionais de trânsito. Conforme a necessidade do serviço e por decisão da Administração, poderão ser criados Plantões RET para atuação no Destacamento Ambiental ou em outras atividades operacionais.\n\n',
                        ),
                        TextSpan(
                          text:
                              'Conforme dispõe o art. 2º, § 7º, da Lei Complementar Municipal nº 247/2026, a ausência injustificada ao Plantão RET acarretará a suspensão automática da inscrição no Regime Especial de Trabalho (RET) pelo período de 60 (sessenta) dias.',
                          style: TextStyle(
                            color:
                                Colors.redAccent,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: aceitou,
                    onChanged: (v) {
                      setState(() {
                        aceitou = v ?? false;
                      });
                    },
                  ),

                  const Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(
                        top: 8,
                      ),
                      child: Text(
                        'Ao clicar em "Prosseguir", declaro que li, tomei ciência e concordo com estas condições.',
                        style: TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 6,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: aceitou
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HomeScreen(
                                agente:
                                    widget.agente,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text(
                    'PROSSEGUIR',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}