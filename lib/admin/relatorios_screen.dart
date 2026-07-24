import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';

class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({
    super.key,
  });

  Future<Uint8List>
      gerarRelatorioGeral() async {
    final regular =
        await fontFromAssetBundle(
      'assets/fonts/Roboto-Regular.ttf',
    );

    final bold =
        await fontFromAssetBundle(
      'assets/fonts/Roboto-Bold.ttf',
    );

    final pdf =
        pw.Document(
      theme:
          pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    final List<
            Map<String, dynamic>>
        dados =
        List<Map<String, dynamic>>.from(
      await ApiService
          .buscarInscricoesPDF(),
    );

    dados.sort(
      (a, b) {
        final nomeA =
            (a['nome'] ?? '')
                .toString()
                .toLowerCase();

        final nomeB =
            (b['nome'] ?? '')
                .toString()
                .toLowerCase();

        final nome =
            nomeA.compareTo(
          nomeB,
        );

        if (nome != 0) {
          return nome;
        }

        final textoA =
            (a['data'] ?? '')
                .toString();

        final textoB =
            (b['data'] ?? '')
                .toString();

        if (textoA.isEmpty ||
            textoB.isEmpty) {
          return 0;
        }

        final dataA =
            DateTime.parse(
          textoA
              .split('/')
              .reversed
              .join('-'),
        );

        final dataB =
            DateTime.parse(
          textoB
              .split('/')
              .reversed
              .join('-'),
        );

        return dataA.compareTo(
          dataB,
        );
      },
    );

    final Map<
            String,
            List<
                Map<String,
                    dynamic>>>
        agrupados = {};

    for (final item
        in dados) {
      final chave =
          '${item['matricula']} - '
          '${item['nome']}';

      agrupados.putIfAbsent(
        chave,
        () =>
            <Map<String,
                dynamic>>[],
      );

      agrupados[chave]!
          .add(item);
    }

   final agentes = agrupados.keys.toList()
  ..sort((a, b) {
    final nomeA = a.split(' - ').length > 1
        ? a.split(' - ')[1].toLowerCase()
        : a.toLowerCase();

    final nomeB = b.split(' - ').length > 1
        ? b.split(' - ')[1].toLowerCase()
        : b.toLowerCase();

    return nomeA.compareTo(nomeB);
  });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

margin: const pw.EdgeInsets.only(
  left: 18,
  right: 18,
  top: 18,
  bottom: 18,
),
header: (context) {
  return pw.Column(
    crossAxisAlignment:
        pw.CrossAxisAlignment.center,
    children: [

      pw.Text(
        'SISTEMA DE PLANTÕES RET',
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
        ),
      ),

      pw.SizedBox(height: 2),

        pw.Text(
    'RELATÓRIO GERAL DE INSCRIÇÕES',
    style: pw.TextStyle(
      fontSize: 10,
    ),
  ),
      pw.SizedBox(height: 2),

      pw.Divider( 
        thickness: 0.5,
      ),

    ],
  );
},

        footer:
            (context) {
          final agora =
              DateTime.now();

          return pw.Align(
            alignment:
                pw.Alignment
                    .centerRight,
            child: pw.Text(
              'Emitido em '
              '${agora.day.toString().padLeft(2, '0')}/'
              '${agora.month.toString().padLeft(2, '0')}/'
              '${agora.year}'
              ' '
              '${agora.hour.toString().padLeft(2, '0')}:'
              '${agora.minute.toString().padLeft(2, '0')}',
              style:
                  const pw.TextStyle(
                fontSize: 7,
              ),
            ),
          );
        },

        build: (context) {
  List<pw.Widget> widgets = [];

  for (final agente in agentes) {
    final lista = agrupados[agente]!;

    lista.sort((a, b) {
      final textoA = (a['data'] ?? '').toString();
      final textoB = (b['data'] ?? '').toString();

      if (textoA.isEmpty || textoB.isEmpty) {
        return 0;
      }

      final dataA = DateTime.parse(
        textoA.split('/').reversed.join('-'),
      );

      final dataB = DateTime.parse(
        textoB.split('/').reversed.join('-'),
      );

      return dataA.compareTo(dataB);
    });

    widgets.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 3,
        ),
        color: PdfColors.blue100,
        child: pw.Text(
          agente,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );

    widgets.add(
      pw.SizedBox(height: 3),
    );

    widgets.add(
      pw.TableHelper.fromTextArray(
        headers: const [
          'DATA',
          'TURNO',
        ],
        headerStyle: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        cellStyle: const pw.TextStyle(
          fontSize: 8,
        ),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 2,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.blueGrey50,
        ),
        border: pw.TableBorder.all(
          width: 0.2,
          color: PdfColors.grey500,
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.3),
          1: pw.FlexColumnWidth(1),
        },
        data: lista.map((e) {
          return [
            e['data']?.toString() ?? '',
            e['turno']?.toString() ?? 'DIA',
          ];
        }).toList(),
      ),
    );

    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(
          top: 3,
          bottom: 6,
        ),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total de plantões: ${lista.length}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  widgets.add(
    pw.Divider(
      thickness: 0.5,
    ),
  );

  widgets.add(
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'TOTAL GERAL: ${dados.length} inscrições',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ),
  );

  return widgets;
},
      ),
    );

    return pdf.save();
  }
  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xff021426,
      ),
      appBar: AppBar(
        title:
            const Text(
          'Relatórios PDF',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Center(
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 700,
            ),
            child: SizedBox(
              width:
                  double.infinity,
              height: 70,
              child:
                  ElevatedButton.icon(
                icon:
                    const Icon(
                  Icons
                      .picture_as_pdf,
                  size: 28,
                ),

                label:
                    const Text(
                  'RELATÓRIO GERAL',
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),

                onPressed:
                    () async {
                  try {
                    final pdf =
                        await gerarRelatorioGeral();

                    if (!context.mounted) {
                      return;
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                                Scaffold(
                          appBar:
                              AppBar(
                            title:
                                const Text(
                              'Visualizar PDF',
                            ),
                          ),
                          body:
                              PdfPreview(
                            maxPageWidth:
                                700,
                            canChangePageFormat:
                                false,
                            canChangeOrientation:
                                false,
                            allowPrinting:
                                true,
                            allowSharing:
                                true,
                            build:
                                (_) async =>
                                    pdf,
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) {
                      return;
                    }

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
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}