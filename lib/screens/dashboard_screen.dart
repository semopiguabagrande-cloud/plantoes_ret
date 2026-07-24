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
static const String ano = "2026";
static const String mes = "07";

List<dynamic> vagas = [];
List<String> meusDias = [];

bool carregando = true;

@override
void initState() {
super.initState();
carregarVagas();
}

Future<void> carregarVagas() async {
print("INICIOU CARREGAR VAGAS");

try {
  final dados = await ApiService.buscarVagas(
    ano: ano,
    mes: mes,
  );

  print("VAGAS RECEBIDAS:");
  print(dados);

  setState(() {
    vagas = dados;
    carregando = false;
  });
} catch (e) {
  print("ERRO AO CARREGAR VAGAS:");
  print(e);

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

void selecionarDia(String dia) {
if (meusDias.contains(dia)) {
setState(() {
meusDias.remove(dia);
});
return;
}

if (meusDias.length >= 8) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Máximo de 8 plantões"),
    ),
  );
  return;
}

setState(() {
  meusDias.add(dia);
});

}

Future<void> confirmarPlantao() async {
  if (meusDias.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Selecione ao menos um dia",
        ),
      ),
    );
    return;
  }

  try {
    final resposta =
        await ApiService.salvarInscricao(
      ano: ano,
      mes: mes,
      codigo: widget.codigo,
      matricula:
          widget.matricula,
      nome: widget.nome,
      datas:
          meusDias.join(","),
    );

    print("RESPOSTA SALVAR:");
    print(resposta);

    final sucesso =
        resposta["success"] ==
            true ||
        resposta["sucesso"] ==
            true;

    if (!sucesso) {
      final data =
          resposta["data"];

      if (data != null) {
        setState(() {
          meusDias.remove(
            data.toString(),
          );
        });
      }

      await carregarVagas();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            resposta[
                    "mensagem"] ??
                "A vaga não está mais disponível.",
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          resposta[
                  "mensagem"] ??
              "Inscrição salva.",
        ),
      ),
    );

    setState(() {
      meusDias.clear();
    });

    await carregarVagas();
  } catch (e) {
    print("ERRO SALVAR:");
    print(e);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          e.toString(),
        ),
      ),
    );
  }
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text("PLANTÕES RET"),
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
Text(
"Matrícula: ${widget.matricula}",
),
const SizedBox(height: 20),
Text(
"Dias escolhidos: ${meusDias.length}/8",
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 20),
Expanded(
child: ListView.builder(
itemCount: vagas.length,
itemBuilder: (context, index) {
final vaga = vagas[index];

                    String data =
                        vaga["data"].toString();

                    if (data.contains("T")) {
                      final dt =
                          DateTime.parse(data);

                      data =
                          "${dt.day.toString().padLeft(2, '0')}/"
                          "${dt.month.toString().padLeft(2, '0')}/"
                          "${dt.year}";
                    }

                    final restantes =
                        int.tryParse(
                              vaga["vagas"]
                                  .toString(),
                            ) ??
                            0;

                    final encerrado =
                        restantes <= 0;

                    return Card(
                      child: ListTile(
                        title: Text(data),
                        subtitle: Text(
                          encerrado
                              ? "Vagas encerradas"
                              : "$restantes vagas disponíveis",
                        ),
                        trailing: Checkbox(
                          value:
                              meusDias.contains(
                            data,
                          ),
                          onChanged: encerrado
                              ? null
                              : (_) {
                                  selecionarDia(
                                    data,
                                  );
                                },
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      confirmarPlantao,
                  child: const Text(
                    "CONFIRMAR PLANTÕES",
                  ),
                ),
              ),
            ],
          ),
        ),
);
}
}
