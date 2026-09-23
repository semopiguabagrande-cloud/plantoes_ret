import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String codigo;
  final String nome;
  final String matricula;

  const HomeScreen({
    super.key,
    required this.codigo,
    required this.nome,
    required this.matricula,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String ano = '2026';
  static const String mes = '07';

  List<dynamic> vagas = [];

  // Cada escolha contém data e turno.
  final List<Map<String, dynamic>> meusDias = [];

  bool carregando = true;
  bool enviando = false;

  @override
  void initState() {
    super.initState();
    carregarVagas();
  }

  Future<void> carregarVagas() async {
    if (mounted) {
      setState(() {
        carregando = true;
      });
    }

    try {
      final dados = await ApiService.buscarVagas(
        ano: ano,
        mes: mes,
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

  String normalizarData(dynamic valor) {
    final texto = valor.toString().trim();

    if (texto.contains('T')) {
      final data = DateTime.parse(texto);

      return '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}/'
          '${data.year}';
    }

    return texto;
  }

  bool estaSelecionado(String data, String turno) {
    return meusDias.any(
      (item) =>
          item['data'] == data &&
          item['turno'] == turno,
    );
  }

  void selecionarPlantao(String data, String turno) {
    final jaSelecionado = estaSelecionado(data, turno);

    if (jaSelecionado) {
      setState(() {
        meusDias.removeWhere(
          (item) =>
              item['data'] == data &&
              item['turno'] == turno,
        );
      });

      return;
    }

    if (meusDias.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo de 8 plantões.'),
        ),
      );

      return;
    }

    setState(() {
      meusDias.add({
        'data': data,
        'turno': turno,
      });
    });
  }

  Future<void> confirmarPlantao() async {
    if (meusDias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos um plantão.'),
        ),
      );

      return;
    }

    setState(() {
      enviando = true;
    });

    // Cria uma cópia da lista no formato exigido pela API.
    final List<Map<String, dynamic>> preferencias =
        meusDias.map((item) {
      return <String, dynamic>{
        'data': item['data'],
        'turno': item['turno'],
      };
    }).toList();

    try {
      final resposta = await ApiService.salvarInscricao(
        ano: ano,
        mes: mes,
        codigo: widget.codigo,
        matricula: widget.matricula,
        nome: widget.nome,
        datas: preferencias,
      );

      if (!mounted) return;

      final sucesso =
          resposta['success'] == true ||
          resposta['sucesso'] == true;

      if (!sucesso) {
        final mensagem =
            resposta['mensagem']?.toString() ??
            'Não foi possível salvar a inscrição.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resposta['mensagem']?.toString() ??
                'Inscrição salva com sucesso.',
          ),
        ),
      );

      setState(() {
        meusDias.clear();
      });

      await carregarVagas();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  Widget construirOpcaoTurno({
    required String data,
    required String turno,
    required int restantes,
  }) {
    final selecionado = estaSelecionado(data, turno);
    final indisponivel = restantes <= 0;

    return CheckboxListTile(
      value: selecionado,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        turno == 'UNICO' ? 'Plantão' : turno,
      ),
      subtitle: Text(
        indisponivel
            ? 'Sem vagas disponíveis'
            : '$restantes vagas disponíveis',
      ),
      onChanged: indisponivel || enviando
          ? null
          : (_) => selecionarPlantao(data, turno),
    );
  }

  Widget construirCartaoVaga(dynamic vaga) {
    final data = normalizarData(vaga['data']);

    final restantesDia =
        int.tryParse(vaga['restantesDia']?.toString() ?? '') ?? 0;

    final restantesNoite =
        int.tryParse(vaga['restantesNoite']?.toString() ?? '') ?? 0;

    final possuiNoite = vaga['possuiNoite'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                data,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            construirOpcaoTurno(
              data: data,
              turno: possuiNoite ? 'DIA' : 'UNICO',
              restantes: restantesDia,
            ),
            if (possuiNoite)
              construirOpcaoTurno(
                data: data,
                turno: 'NOITE',
                restantes: restantesNoite,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PLANTÕES RET'),
        centerTitle: true,
      ),
      body: carregando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nome,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Matrícula: ${widget.matricula}'),
                  const SizedBox(height: 20),
                  Text(
                    'Plantões escolhidos: ${meusDias.length}/8',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: vagas.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhuma vaga encontrada.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: vagas.length,
                            itemBuilder: (context, index) {
                              return construirCartaoVaga(
                                vagas[index],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: enviando ? null : confirmarPlantao,
                      child: enviando
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('CONFIRMAR PLANTÕES'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}