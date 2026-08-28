import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../screens/login_screen.dart';

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

  bool sincronizando = false;

  bool salvando = false;

  bool enviandoHeartbeat = false;

  bool saindo = false;

  late int limitePlantao;

  late String anoAtual;
  late String mesAtual;

  Timer? _timerAtualizacao;

  bool get desktop =>
      MediaQuery.of(context).size.width > 800;

  // ===================================================
  // INICIALIZAÇÃO
  // ===================================================

  @override
  void initState() {
    super.initState();

    // IMPORTANTE:
    // Aqui está o mês que o aplicativo está utilizando.
    //
    // Se o Apps Script estiver trabalhando com setembro,
    // posteriormente podemos fazer o aplicativo receber
    // automaticamente o mês/ano do servidor.
    //
    // NÃO alterei sua lógica de vagas aqui.
    anoAtual = '2026';
    mesAtual = '07';

    limitePlantao =
        widget.agente['ferias'] == true ? 10 : 8;

    iniciar();

    _timerAtualizacao = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (!mounted) return;

        if (salvando || saindo) {
          return;
        }

        await manterSessaoAtiva();

        if (!mounted || saindo) return;

        await carregarVagas(
          mostrarLoading: false,
        );
      },
    );
  }

  // ===================================================
  // DISPOSE
  // ===================================================

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    _timerAtualizacao = null;

    super.dispose();
  }

  // ===================================================
  // INICIAR
  // ===================================================

  Future<void> iniciar() async {
    await carregarInicial();
  }

  // ===================================================
  // HEARTBEAT
  // ===================================================

  Future<void> manterSessaoAtiva() async {
    if (enviandoHeartbeat || saindo) {
      return;
    }

    if (!ApiService.possuiSessao) {
      debugPrint(
        'Heartbeat ignorado: não existe sessão.',
      );

      return;
    }

    enviandoHeartbeat = true;

    try {
      final sessaoAtiva =
          await ApiService.heartbeat();

      debugPrint(
        'Heartbeat: $sessaoAtiva',
      );

      if (!sessaoAtiva && mounted && !saindo) {
        await sessaoEncerrada();
      }
    } catch (e) {
      debugPrint(
        'Erro no heartbeat: $e',
      );
    } finally {
      enviandoHeartbeat = false;
    }
  }

  // ===================================================
  // SESSÃO ENCERRADA PELO SERVIDOR
  // ===================================================

  Future<void> sessaoEncerrada() async {
    if (!mounted || saindo) return;

    saindo = true;

    _timerAtualizacao?.cancel();
    _timerAtualizacao = null;

    ApiService.limparSessao();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Sessão encerrada',
          ),
          content: const Text(
            'Sua sessão foi encerrada. '
            'Será necessário fazer login novamente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    // IMPORTANTE:
    // Remove TODAS as telas anteriores e cria
    // explicitamente uma nova tela de login.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ===================================================
  // LOGOUT VOLUNTÁRIO
  // ===================================================

  Future<void> fazerLogout() async {
    if (salvando || saindo) {
      if (salvando && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'Aguarde o salvamento terminar.',
            ),
          ),
        );
      }

      return;
    }

    // =================================================
    // CONFIRMAÇÃO
    // =================================================

    final confirmar =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Sair do aplicativo?',
          ),
          content: const Text(
            'Ao sair, sua sessão será liberada '
            'e você poderá fazer login em outro dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'CANCELAR',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'SAIR',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    if (!mounted) return;

    // =================================================
    // MARCA QUE ESTÁ SAINDO
    // =================================================

    setState(() {
      saindo = true;
    });

    // =================================================
    // PARA O HEARTBEAT
    // =================================================

    _timerAtualizacao?.cancel();
    _timerAtualizacao = null;

    // =================================================
    // MOSTRA CARREGAMENTO
    // =================================================

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Encerrando sessão...',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // =================================================
      // AVISA O SERVIDOR
      // =================================================

      final resultado =
          await ApiService.logout();

      debugPrint(
        'Logout: $resultado',
      );
    } catch (e) {
      debugPrint(
        'Erro no logout: $e',
      );
    }

    // =================================================
    // LIMPA A SESSÃO LOCAL
    // =================================================

    ApiService.limparSessao();

    if (!mounted) return;

    // =================================================
    // FECHA O "ENCERRANDO SESSÃO"
    // =================================================

    Navigator.of(context).pop();

    // =================================================
    // VAI DIRETAMENTE PARA O LOGIN
    //
    // NÃO usamos popUntil(route.isFirst)
    // porque isso poderia deixar o usuário
    // em alguma tela anterior.
    // =================================================

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ===================================================
  // CARREGAR MINHAS INSCRIÇÕES
  // ===================================================

  Future<void> carregarMinhasInscricoes() async {
    try {
      final dados =
          await ApiService.buscarMinhasInscricoes(
        widget.agente['codigo'].toString(),
      );

      if (!mounted || saindo) return;

      setState(() {
        selecionados =
            List<Map<String, dynamic>>.from(
          dados,
        );

        inscricoesOriginais =
            List<Map<String, dynamic>>.from(
          dados,
        );
      });
    } catch (e) {
      debugPrint(
        e.toString(),
      );
    }
  }

  // ===================================================
  // CARREGAR DADOS INICIAIS
  // ===================================================

  Future<void> carregarInicial({
    bool mostrarLoading = true,
  }) async {
    if (saindo) return;

    try {
      if (mounted) {
        setState(() {
          if (mostrarLoading) {
            carregando = true;
          } else {
            sincronizando = true;
          }
        });
      }

      final dados =
          await ApiService.buscarInicial(
        codigo:
            widget.agente['codigo']
                .toString(),
      );

      if (!mounted || saindo) return;

      // =================================================
      // SESSÃO ENCERRADA
      // =================================================

      if (dados['sessaoExpirada'] == true) {
        await sessaoEncerrada();
        return;
      }

      // =================================================
      // ERRO
      // =================================================

      if (dados['success'] != true) {
        throw Exception(
          dados['mensagem'] ??
              'Não foi possível carregar os dados.',
        );
      }

      final listaVagas =
          dados['vagas'] is List
              ? dados['vagas']
              : [];

      final listaMinhas =
          dados['minhas'] is List
              ? dados['minhas']
              : [];

      if (!mounted || saindo) return;

      setState(() {
        vagas =
            List<dynamic>.from(
          listaVagas,
        );

        selecionados =
            List<Map<String, dynamic>>.from(
          listaMinhas.map(
            (e) =>
                Map<String, dynamic>.from(
              e,
            ),
          ),
        );

        inscricoesOriginais =
            List<Map<String, dynamic>>.from(
          selecionados,
        );

        carregando = false;
        sincronizando = false;
      });
    } catch (e) {
      if (!mounted || saindo) return;

      setState(() {
        carregando = false;
        sincronizando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  // ===================================================
  // CARREGAR VAGAS
  // ===================================================

  Future<void> carregarVagas({
    bool mostrarLoading = true,
  }) async {
    if (saindo) return;

    try {
      if (mounted) {
        setState(() {
          if (mostrarLoading) {
            carregando = true;
          } else {
            sincronizando = true;
          }
        });
      }

      final dados =
          await ApiService.buscarVagas(
        ano: anoAtual,
        mes: mesAtual,
      );

      if (!mounted || saindo) return;

      setState(() {
        vagas = dados;
        carregando = false;
        sincronizando = false;
      });
    } catch (e) {
      if (!mounted || saindo) return;

      setState(() {
        carregando = false;
        sincronizando = false;
      });

      debugPrint(
        'Erro ao atualizar vagas: $e',
      );
    }
  }

  // ===================================================
  // SELECIONAR
  // ===================================================

  void selecionar(
    String data,
    String turno,
  ) {
    if (saindo) return;

    final existe =
        selecionados.any(
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

    if (selecionados.length >=
        limitePlantao) {
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
      selecionados.removeWhere(
        (e) => e['data'] == data,
      );

      selecionados.add({
        'data': data,
        'turno': turno,
      });
    });
  }

  // ===================================================
  // SALVAR ESCOLHAS
  // ===================================================

  Future<void> salvarEscolhas() async {
    if (salvando || saindo) return;

    setState(() {
      salvando = true;
    });

    try {
      final cronometro =
          Stopwatch()..start();

      await carregarVagas(
        mostrarLoading: false,
      );

      if (!mounted || saindo) return;

      final adicionar =
          selecionados.where(
        (item) {
          return !inscricoesOriginais.any(
            (x) =>
                x['data'] ==
                    item['data'] &&
                x['turno'] ==
                    item['turno'],
          );
        },
      ).toList();

      final remover =
          inscricoesOriginais.where(
        (item) {
          return !selecionados.any(
            (x) =>
                x['data'] ==
                    item['data'] &&
                x['turno'] ==
                    item['turno'],
          );
        },
      ).toList();

      // =================================================
      // VALIDA VAGAS
      // =================================================

      for (final item in adicionar) {
        final vaga =
            vagas.firstWhere(
          (e) =>
              e['data'].toString() ==
              item['data'].toString(),
        );

        final turno =
            item['turno'].toString();

        if (turno == 'DIA') {
          final restantes =
              int.tryParse(
                    vaga['restantesDia']
                        .toString(),
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
          final restantes =
              int.tryParse(
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

      // =================================================
      // CANCELAR
      // =================================================

      if (remover.isNotEmpty) {
        await ApiService.cancelarInscricao(
          codigo:
              widget.agente['codigo']
                  .toString(),
          datas: remover,
        );
      }

      debugPrint(
        'Cancelar: '
        '${cronometro.elapsedMilliseconds} ms',
      );

      // =================================================
      // ADICIONAR
      // =================================================

      if (adicionar.isNotEmpty) {
        final resposta =
            await ApiService.salvarInscricao(
          ano: anoAtual,
          mes: mesAtual,
          codigo:
              widget.agente['codigo']
                  .toString(),
          matricula:
              widget.agente['matricula']
                  .toString(),
          nome:
              widget.agente['nome']
                  .toString(),
          datas: adicionar,
        );

        debugPrint(
          'Salvar API: '
          '${cronometro.elapsedMilliseconds} ms',
        );

       if (resposta['success'] != true) {
  final dataErro =
      resposta['data']?.toString();

  final turnoErro =
      resposta['turno']?.toString();

  // ===============================================
  // REMOVE AUTOMATICAMENTE A VAGA QUE FOI RECUSADA
  // ===============================================

  if (dataErro != null &&
      turnoErro != null) {
    if (mounted) {
      setState(() {
        selecionados.removeWhere(
          (e) =>
              e['data'].toString() ==
                  dataErro &&
              e['turno'].toString().toUpperCase() ==
                  turnoErro.toUpperCase(),
        );
      });
    }
  }

  // Atualiza as vagas e as inscrições
  // depois de retirar a marcação
  await carregarInicial(
    mostrarLoading: false,
  );
          if (!mounted || saindo) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                resposta['mensagem']
                        ?.toString() ??
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

      // =================================================
      // ATUALIZA
      // =================================================

      await carregarInicial(
        mostrarLoading: false,
      );

      if (!mounted || saindo) return;

      setState(() {
        salvando = false;
      });

      debugPrint(
        'TOTAL (sucesso): '
        '${cronometro.elapsedMilliseconds} ms',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Alterações salvas.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted || saindo) return;

      setState(() {
        salvando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
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
      backgroundColor: const Color(0xff021426),

      appBar: AppBar(
        backgroundColor: const Color(0xff00162f),
        centerTitle: true,

        title: const Text(
          'PLANTÕES RET',
        ),

        actions: [
          if (sincronizando)
            const Padding(
              padding: EdgeInsets.only(
                right: 10,
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // =================================================
          // BOTÃO SAIR
          // =================================================

          IconButton(
            tooltip: 'Sair',
            icon: const Icon(
              Icons.logout,
            ),
            onPressed:
                (salvando || saindo)
                    ? null
                    : fazerLogout,
          ),
        ],
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
                      padding:
                          const EdgeInsets.all(20),

                      child: Column(
                        children: [
                          Text(
                            widget.agente[
                                    'nome'] ??
                                '',
                            style: TextStyle(
                              fontSize:
                                  desktop
                                      ? 30
                                      : 24,
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
                            '${selecionados.length}'
                            '/$limitePlantao',
                            style:
                                const TextStyle(
                              color:
                                  Colors.amber,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          Container(
                            width:
                                double.infinity,

                            height: 58,

                            alignment:
                                Alignment.centerLeft,

                            child:
                                selecionados
                                        .isEmpty
                                    ? const Center(
                                        child:
                                            Text(
                                          'Nenhum plantão selecionado',
                                          style:
                                              TextStyle(
                                            color:
                                                Colors.white70,
                                          ),
                                        ),
                                      )
                                    : Builder(
                                        builder:
                                            (context) {
                                          final lista =
                                              List<Map<String, dynamic>>.from(
                                            selecionados,
                                          );

                                          lista.sort(
                                            (a, b) {
                                              final da =
                                                  DateTime.parse(
                                                a['data']
                                                    .toString()
                                                    .split(
                                                      '/',
                                                    )
                                                    .reversed
                                                    .join(
                                                      '-',
                                                    ),
                                              );

                                              final db =
                                                  DateTime.parse(
                                                b['data']
                                                    .toString()
                                                    .split(
                                                      '/',
                                                    )
                                                    .reversed
                                                    .join(
                                                      '-',
                                                    ),
                                              );

                                              return da.compareTo(
                                                db,
                                              );
                                            },
                                          );

                                          return ListView.separated(
                                            scrollDirection:
                                                Axis.horizontal,

                                            physics:
                                                const BouncingScrollPhysics(),

                                            itemCount:
                                                lista.length,

                                            separatorBuilder:
                                                (
                                              _,
                                              __,
                                            ) =>
                                                const SizedBox(
                                              width:
                                                  8,
                                            ),

                                            itemBuilder:
                                                (
                                              context,
                                              index,
                                            ) {
                                              final e =
                                                  lista[index];

                                              return Center(
                                                child:
                                                    Chip(
                                                  backgroundColor:
                                                      Colors.white10,

                                                  label:
                                                      Text(
                                                    '${e['data']} '
                                                    '(${e['turno']})',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        const TextStyle(
                                                      color:
                                                          Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Expanded(
                    child:
                        desktop
                            ? GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      2,
                                  childAspectRatio:
                                      1.7,
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
                    padding:
                        EdgeInsets.only(
                      bottom:
                          MediaQuery.of(
                                context,
                              )
                              .padding
                              .bottom +
                          10,
                    ),

                    child: SizedBox(
                      width:
                          double.infinity,

                      height:
                          60,

                      child:
                          ElevatedButton(
                        onPressed:
                            (salvando ||
                                    saindo)
                                ? null
                                : salvarEscolhas,

                        child:
                            salvando
                                ? const SizedBox(
                                    height:
                                        30,
                                    width:
                                        30,
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

  // ===================================================
  // CARD DA VAGA
  // ===================================================

  Widget montarCard(
    BuildContext context,
    int i,
  ) {
    final vaga =
        vagas[i];

    final data =
        vaga['data'].toString();

    final restantesDia =
        int.tryParse(
              vaga['restantesDia']
                  .toString(),
            ) ??
            0;

    final restantesNoite =
        int.tryParse(
              vaga['restantesNoite']
                  .toString(),
            ) ??
            0;

    final possuiNoite =
        vaga['possuiNoite']
                .toString()
                .toLowerCase() ==
            'true';

    final marcadoDia =
        selecionados.any(
      (e) =>
          e['data'] ==
              data &&
          e['turno'] ==
              'DIA',
    );

    final marcadoNoite =
        selecionados.any(
      (e) =>
          e['data'] ==
              data &&
          e['turno'] ==
              'NOITE',
    );

    return Card(
      color:
          Colors.white10,

      child: Padding(
        padding:
            const EdgeInsets.all(
          15,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Text(
              data,
              style:
                  const TextStyle(
                fontSize:
                    18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            CheckboxListTile(
              dense:
                  true,

              contentPadding:
                  EdgeInsets.zero,

              value:
                  marcadoDia,

              title:
                  Text(
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
                dense:
                    true,

                contentPadding:
                    EdgeInsets.zero,

                value:
                    marcadoNoite,

                title:
                    Text(
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