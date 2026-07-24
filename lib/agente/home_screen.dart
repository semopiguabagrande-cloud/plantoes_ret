import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> agente;

  const HomeScreen({
    super.key,
    required this.agente,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> vagas = [];

  List<Map<String, dynamic>> selecionados = [];

  List<Map<String, dynamic>> inscricoesOriginais = [];

  bool carregando = true;
  bool salvando = false;

  late int limitePlantao;

  late String anoAtual;
  late String mesAtual;

  Timer? _timerAtualizacao;

  bool get desktop =>
      MediaQuery.of(context).size.width > 800;

  @override
  void initState() {
    super.initState();

    anoAtual = '2026';
    mesAtual = '07';

    limitePlantao =
        widget.agente['ferias'] == true ? 10 : 8;

    iniciar();

    _timerAtualizacao = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (!mounted || salvando) {
          return;
        }

        await carregarVagas();
      },
    );
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  Future<void> iniciar() async {
    await carregarVagas();
    await carregarMinhasInscricoes();
  }

  Future<void> carregarMinhasInscricoes() async {
    try {
      final dados =
          await ApiService.buscarMinhasInscricoes(
        widget.agente['codigo'].toString(),
      );

      if (!mounted) return;

      setState(() {
        selecionados =
            List<Map<String, dynamic>>.from(dados);

        inscricoesOriginais =
            List<Map<String, dynamic>>.from(dados);
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> carregarVagas() async {
    try {
      if (mounted) {
        setState(() {
          carregando = true;
        });
      }

      final dados = await ApiService.buscarVagas(
        ano: anoAtual,
        mes: mesAtual,
      );

      if (!mounted) return;

      setState(() {
        vagas = dados;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  void selecionar(
    String data,
    String turno,
  ) {
    final existe = selecionados.any(
      (e) =>
          e['data'] == data &&
          e['turno'] == turno,
    );

    if (existe) {
      setState(() {
        selecionados.removeWhere(
          (e) =>
              e['data'] == data &&
              e['turno'] == turno,
        );
      });

      return;
    }

    if (selecionados.length >= limitePlantao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Limite de plantões atingido.',
          ),
        ),
      );

      return;
    }

    setState(() {
      // impede DIA e NOITE no mesmo dia
      selecionados.removeWhere(
        (e) => e['data'] == data,
      );

      selecionados.add({
        'data': data,
        'turno': turno,
      });
    });
  }

  Future<void> salvarEscolhas() async {
    if (salvando) return;

    setState(() {
      salvando = true;
    });

    try {
      // atualização imediata
      await carregarVagas();

      final adicionar = selecionados.where(
        (item) {
          return !inscricoesOriginais.any(
            (x) =>
                x['data'] == item['data'] &&
                x['turno'] == item['turno'],
          );
        },
      ).toList();

      final remover =
          inscricoesOriginais.where(
        (item) {
          return !selecionados.any(
            (x) =>
                x['data'] == item['data'] &&
                x['turno'] == item['turno'],
          );
        },
      ).toList();

      // valida novamente antes de salvar
      for (final item in adicionar) {
        final vaga = vagas.firstWhere(
          (e) =>
              e['data'].toString() ==
              item['data'].toString(),
        );

        final turno =
            item['turno'].toString();

        if (turno == 'DIA') {
          final restantes = int.tryParse(
                vaga['restantesDia'].toString(),
              ) ??
              0;

          if (restantes <= 0) {
            throw Exception(
              'A vaga do dia '
              '${item['data']} '
              'foi preenchida por outro agente.',
            );
          }
        }

        if (turno == 'NOITE') {
          final restantes = int.tryParse(
                vaga['restantesNoite']
                    .toString(),
              ) ??
              0;

          if (restantes <= 0) {
            throw Exception(
              'A vaga da noite '
              '${item['data']} '
              'foi preenchida por outro agente.',
            );
          }
        }
      }

      if (remover.isNotEmpty) {
        await ApiService.cancelarInscricao(
          codigo:
              widget.agente['codigo'].toString(),
          datas: remover,
        );
      }

      if (adicionar.isNotEmpty) {
        final resposta =
            await ApiService.salvarInscricao(
          ano: anoAtual,
          mes: mesAtual,
          codigo:
              widget.agente['codigo'].toString(),
          matricula: widget.agente['matricula']
              .toString(),
          nome: widget.agente['nome'],
          datas: adicionar,
        );

        if (resposta['success'] != true) {
          final dataErro =
              resposta['data']?.toString();

          final turnoErro =
              resposta['turno']?.toString();

          if (dataErro != null &&
              turnoErro != null) {
            setState(() {
              selecionados.removeWhere(
                (e) =>
                    e['data'].toString() ==
                        dataErro &&
                    e['turno'].toString() ==
                        turnoErro,
              );
            });
          }

          await carregarMinhasInscricoes();
          await carregarVagas();

          if (!mounted) return;

          setState(() {});

          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                resposta['mensagem'] ??
                    'Erro ao salvar.',
              ),
            ),
          );

          setState(() {
            salvando = false;
          });

          return;
        }
      }

      await carregarMinhasInscricoes();
      await carregarVagas();

      if (!mounted) return;

      setState(() {});

      if (!mounted) return;

      setState(() {
        salvando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Alterações salvas.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        salvando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xff021426),
      appBar: AppBar(
        backgroundColor: const Color(0xff00162f),
        centerTitle: true,
        title: const Text(
          'PLANTÕES RET',
        ),
      ),
      body: carregando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: EdgeInsets.all(
                desktop ? 30 : 20,
              ),
              child: Column(
                children: [
                  Card(
                    color: Colors.white10,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            widget.agente['nome'] ?? '',
                            style: TextStyle(
                              fontSize:
                                  desktop ? 30 : 24,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Matrícula: '
                            '${widget.agente['matricula']}',
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Plantões '
                            '${selecionados.length}/$limitePlantao',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                selecionados.map((e) {
                              return Chip(
                                backgroundColor:
                                    Colors.white10,
                                label: Text(
                                  '${e['data']} (${e['turno']})',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Expanded(
                    child: desktop
                        ? GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.7,
                              crossAxisSpacing:
                                  15,
                              mainAxisSpacing:
                                  15,
                            ),
                            itemCount:
                                vagas.length,
                            itemBuilder:
                                montarCard,
                          )
                        : ListView.builder(
                            itemCount:
                                vagas.length,
                            itemBuilder:
                                montarCard,
                          ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          MediaQuery.of(context)
                                  .padding
                                  .bottom +
                              10,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: salvando
                            ? null
                            : salvarEscolhas,
                        child: salvando
                            ? const SizedBox(
                                height: 30,
                                width: 30,
                                child:
                                    CircularProgressIndicator(),
                              )
                            : const Text(
                                'SALVAR ALTERAÇÕES',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
    Widget montarCard(
    BuildContext context,
    int i,
  ) {
    final vaga = vagas[i];

    final data = vaga['data'].toString();

    final restantesDia = int.tryParse(
          vaga['restantesDia'].toString(),
        ) ??
        0;

    final restantesNoite = int.tryParse(
          vaga['restantesNoite'].toString(),
        ) ??
        0;

    final possuiNoite =
        vaga['possuiNoite']
                .toString()
                .toLowerCase() ==
            'true';

    final marcadoDia = selecionados.any(
      (e) =>
          e['data'] == data &&
          e['turno'] == 'DIA',
    );

    final marcadoNoite = selecionados.any(
      (e) =>
          e['data'] == data &&
          e['turno'] == 'NOITE',
    );

    return Card(
      color: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              data,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding:
                  EdgeInsets.zero,
              value: marcadoDia,
              title: Text(
                restantesDia <= 0 &&
                        !marcadoDia
                    ? 'DIA - ESGOTADO'
                    : 'DIA - Restantes: '
                        '$restantesDia',
              ),
              onChanged:
                  restantesDia <= 0 &&
                          !marcadoDia
                      ? null
                      : (_) {
                          selecionar(
                            data,
                            'DIA',
                          );
                        },
            ),
            if (possuiNoite)
              CheckboxListTile(
                dense: true,
                contentPadding:
                    EdgeInsets.zero,
                value: marcadoNoite,
                title: Text(
                  restantesNoite <= 0 &&
                          !marcadoNoite
                      ? 'NOITE - ESGOTADO'
                      : 'NOITE - Restantes: '
                          '$restantesNoite',
                ),
                onChanged:
                    restantesNoite <= 0 &&
                            !marcadoNoite
                        ? null
                        : (_) {
                            selecionar(
                              data,
                              'NOITE',
                            );
                          },
              ),
          ],
        ),
      ),
    );
  }
}