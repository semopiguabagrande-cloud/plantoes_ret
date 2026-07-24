import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class InscricoesScreen extends StatefulWidget {
  const InscricoesScreen({
    super.key,
  });

  @override
  State<InscricoesScreen> createState() =>
      _InscricoesScreenState();
}

class _InscricoesScreenState
    extends State<InscricoesScreen> {
  bool carregando = true;

  Timer? timerAtualizacao;

  List<dynamic> dados = [];

  List<dynamic> filtrados = [];

  final TextEditingController
      pesquisaController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    carregar();

    pesquisaController
        .addListener(
      filtrar,
    );

    timerAtualizacao =
        Timer.periodic(
      const Duration(
        minutes: 1,
      ),
      (_) async {
        await carregar();
      },
    );
  }

  @override
  void dispose() {
    timerAtualizacao
        ?.cancel();

    pesquisaController
        .dispose();

    super.dispose();
  }

  Future<void> carregar() async {
    try {
      setState(() {
        carregando = true;
      });

      final lista =
          await ApiService
              .buscarInscricoesPDF();

      lista.sort(
        (a, b) {
          return a['data']
              .toString()
              .compareTo(
                b['data']
                    .toString(),
              );
        },
      );

      if (!mounted) return;

      setState(() {
        dados = lista;

        filtrados =
            List.from(
          lista,
        );

        carregando = false;
      });
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
          content:
              Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  void filtrar() {
    final texto =
        pesquisaController.text
            .toLowerCase();

    setState(() {
      filtrados =
          dados.where(
        (e) {
          final nome =
              e['nome']
                  .toString()
                  .toLowerCase();

          final matricula =
              e['matricula']
                  .toString();

          final data =
              e['data']
                  .toString()
                  .toLowerCase();

          final turno =
              e['turno']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          return nome.contains(
                    texto,
                  ) ||
              matricula.contains(
                texto,
              ) ||
              data.contains(
                texto,
              ) ||
              turno.contains(
                texto,
              );
        },
      ).toList();
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final desktop =
        MediaQuery.of(context)
                .size
                .width >
            900;

    final agentes =
        filtrados
            .map(
              (e) => e[
                      'matricula']
                  .toString(),
            )
            .toSet()
            .length;

    final dias =
        filtrados
            .map(
              (e) => e[
                      'data']
                  .toString(),
            )
            .toSet()
            .length;

    final Map<
            String,
            List<dynamic>>
        agrupados = {};

    for (final item
        in filtrados) {
      final data =
          item['data']
              .toString();

      agrupados.putIfAbsent(
        data,
        () => [],
      );

      agrupados[data]!
          .add(item);
    }

    return Scaffold(
      backgroundColor:
          const Color(
        0xff021426,
      ),
      appBar: AppBar(
        title:
            const Text(
          'Inscrições',
        ),
        actions: [
          IconButton(
            tooltip:
                'Atualizar',
            icon:
                const Icon(
              Icons.sync,
            ),
            onPressed:
                () async {
              await carregar();

              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content:
                      Text(
                    'Dados sincronizados.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
            body: carregando
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh:
                  carregar,
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    child:
                        Column(
                      children: [
                        Wrap(
                          alignment:
                              WrapAlignment
                                  .center,
                          spacing:
                              12,
                          runSpacing:
                              12,
                          children: [
                            SizedBox(
                              width:
                                  desktop
                                      ? 180
                                      : 110,
                              child:
                                  _cardResumo(
                                'INSCRIÇÕES',
                                filtrados
                                    .length
                                    .toString(),
                              ),
                            ),
                            SizedBox(
                              width:
                                  desktop
                                      ? 180
                                      : 110,
                              child:
                                  _cardResumo(
                                'AGENTES',
                                agentes
                                    .toString(),
                              ),
                            ),
                            SizedBox(
                              width:
                                  desktop
                                      ? 180
                                      : 110,
                              child:
                                  _cardResumo(
                                'DIAS',
                                dias
                                    .toString(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height:
                              20,
                        ),

                        TextField(
                          controller:
                              pesquisaController,
                          decoration:
                              InputDecoration(
                            hintText:
                                'Pesquisar nome, matrícula, data ou turno',
                            prefixIcon:
                                const Icon(
                              Icons.search,
                            ),
                            suffixIcon:
                                pesquisaController
                                        .text
                                        .isEmpty
                                    ? null
                                    : IconButton(
                                        icon:
                                            const Icon(
                                          Icons.clear,
                                        ),
                                        onPressed:
                                            () {
                                          pesquisaController
                                              .clear();
                                        },
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child:
                        agrupados
                                .isEmpty
                            ? const Center(
                                child:
                                    Text(
                                  'Nenhuma inscrição encontrada.',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white70,
                                    fontSize:
                                        18,
                                  ),
                                ),
                              )
                            : ListView(
                                padding:
                                    EdgeInsets.symmetric(
                                  horizontal:
                                      desktop
                                          ? 80
                                          : 20,
                                ),
                                children:
                                    agrupados.entries
                                        .map(
                                  (
                                    grupo,
                                  ) {
                                    final lista =
                                        grupo.value;

                                    return Card(
                                      color:
                                          Colors.white10,
                                      margin:
                                          const EdgeInsets.only(
                                        bottom:
                                            15,
                                      ),
                                      child:
                                          ExpansionTile(
                                        leading:
                                            const Icon(
                                          Icons
                                              .calendar_month,
                                          color:
                                              Colors.amber,
                                        ),
                                        title:
                                            Text(
                                          grupo
                                              .key,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        subtitle:
                                            Text(
                                          '${lista.length} inscrição(ões)',
                                        ),
                                        children:
                                            lista.map(
                                          (
                                            e,
                                          ) {
                                            return ListTile(
                                              isThreeLine:
                                                  true,
                                              leading:
                                                  CircleAvatar(
                                                backgroundColor:
                                                    Colors.blue,
                                                child:
                                                    Text(
                                                  e['nome']
                                                      .toString()
                                                      .substring(
                                                        0,
                                                        1,
                                                      ),
                                                ),
                                              ),
                                              title:
                                                  Text(
                                                e['nome']
                                                    .toString(),
                                              ),
                                              subtitle:
                                                  Text(
                                                'Matrícula: ${e['matricula']}'
                                                '\nTurno: ${e['turno'] ?? 'DIA'}',
                                              ),
                                            );
                                          },
                                        ).toList(),
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                  ),
                ],
              ),
            ),

      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor:
            Colors.blue,
        icon:
            const Icon(
          Icons.sync,
        ),
        label:
            const Text(
          'Atualizar',
        ),
        onPressed:
            () async {
          await carregar();

          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content:
                  Text(
                'Dados sincronizados.',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cardResumo(
    String titulo,
    String valor,
  ) {
    return Card(
      color:
          Colors.white10,
      child: Padding(
        padding:
            const EdgeInsets.all(
          15,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              titulo,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              valor,
              style:
                  const TextStyle(
                fontSize:
                    28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}