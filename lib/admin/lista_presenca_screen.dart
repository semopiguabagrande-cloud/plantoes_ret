import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';

class ListaPresencaScreen extends StatelessWidget {
  const ListaPresencaScreen({
    super.key,
  });

  Future<Uint8List> gerarListaPresenca(
    String dataPlantao,
  ) async {
    final regular =
        await fontFromAssetBundle(
      'assets/fonts/Roboto-Regular.ttf',
    );

    final bold =
        await fontFromAssetBundle(
      'assets/fonts/Roboto-Bold.ttf',
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    final List<Map<String, dynamic>>
        dados =
        List<Map<String, dynamic>>.from(
      await ApiService.buscarInscricoesPDF(),
    );

    final lista = dados.where((e) {
      return (e['data'] ?? '')
              .toString() ==
          dataPlantao;
    }).toList();

    final turnoDia =
        lista.where((e) {
      return (e['turno'] ?? 'DIA')
              .toString()
              .toUpperCase() ==
          'DIA';
    }).toList();

    final turnoNoite =
        lista.where((e) {
      return (e['turno'] ?? 'NOITE')
              .toString()
              .toUpperCase() ==
          'NOITE';
    }).toList();

    turnoDia.sort(
      (a, b) => (a['nome'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo(
            (b['nome'] ?? '')
                .toString()
                .toLowerCase(),
          ),
    );

    turnoNoite.sort(
      (a, b) => (a['nome'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo(
            (b['nome'] ?? '')
                .toString()
                .toLowerCase(),
          ),
    );

    final agora = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4,
        margin:
            const pw.EdgeInsets.all(
          25,
        ),

        header: (context) {
          return pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment
                    .center,
            children: [

              pw.Text(
                'PREFEITURA MUNICIPAL DE IGUABA GRANDE',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              pw.SizedBox(
                height: 2,
              ),

              pw.Text(
                'SECRETARIA MUNICIPAL DE SEGURANÇA E ORDEM PÚBLICA',
                style:
                    const pw.TextStyle(
                  fontSize: 10,
                ),
              ),

              pw.SizedBox(
                height: 2,
              ),

              pw.Text(
                'GUARDA CIVIL MUNICIPAL',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),

              pw.SizedBox(
                height: 10,
              ),

              pw.Text(
                'LISTA DE PRESENÇA - RET',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              pw.SizedBox(
                height: 10,
              ),

              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment
                        .spaceBetween,
                children: [

                  pw.Text(
                    'Data do Plantão: $dataPlantao',
                    style:
                        const pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),

                  pw.Text(
                    'Emitido em '
                    '${agora.day.toString().padLeft(2, '0')}/'
                    '${agora.month.toString().padLeft(2, '0')}/'
                    '${agora.year} '
                    '${agora.hour.toString().padLeft(2, '0')}:'
                    '${agora.minute.toString().padLeft(2, '0')}',
                    style:
                        const pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(
                height: 4,
              ),

              pw.Align(
                alignment:
                    pw.Alignment
                        .centerLeft,
                child: pw.Text(
                  'Total de inscritos: ${lista.length}',
                  style: pw.TextStyle(
                    fontWeight:
                        pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),

              pw.Divider(),
            ],
          );
        },

        build: (context) {

          List<pw.Widget> widgets = [];
          int numero = 1;

void adicionarTurno(
  String titulo,
  List<Map<String, dynamic>> registros,
) {
  if (registros.isEmpty) return;

  widgets.add(
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      color: PdfColors.blue100,
      child: pw.Text(
        titulo,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
        ),
      ),
    ),
  );

  widgets.add(
    pw.SizedBox(height: 6),
  );

  widgets.add(
    pw.TableHelper.fromTextArray(
      headers: const [
        'Nº',
        'Nome',
        'Matrícula',
        'Assinatura',
      ],
      headerDecoration:
          const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      headerStyle: pw.TextStyle(
        fontWeight:
            pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle:
          const pw.TextStyle(
        fontSize: 9,
      ),
      border:
          pw.TableBorder.all(
        width: .3,
      ),
      cellAlignment:
          pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(5),
      },
      data: registros.map((e) {
        final linha = [
          numero.toString(),
          e['nome']
                  ?.toString() ??
              '',
          e['matricula']
                  ?.toString() ??
              '',
          '',
        ];

        numero++;

        return linha;
      }).toList(),
    ),
  );

  widgets.add(
    pw.Padding(
      padding:
          const pw.EdgeInsets.only(
        top: 5,
        bottom: 12,
      ),
      child: pw.Align(
        alignment:
            pw.Alignment
                .centerRight,
        child: pw.Text(
          'Total do turno: ${registros.length}',
          style: pw.TextStyle(
            fontWeight:
                pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ),
    ),
  );
}

adicionarTurno(
  'TURNO DIA',
  turnoDia,
);

adicionarTurno(
  'TURNO NOITE',
  turnoNoite,
);

widgets.add(
  pw.Divider(),
);

widgets.add(
  pw.Align(
    alignment:
        pw.Alignment.centerRight,
    child: pw.Text(
      'TOTAL GERAL: ${lista.length}',
      style: pw.TextStyle(
        fontWeight:
            pw.FontWeight.bold,
        fontSize: 11,
      ),
    ),
  ),
);

widgets.add(
  pw.SizedBox(height: 25),
);

widgets.add(
  pw.Text(
    'Observações:',
    style: pw.TextStyle(
      fontWeight:
          pw.FontWeight.bold,
    ),
  ),
);

for (int i = 0; i < 3; i++) {
  widgets.add(
    pw.Container(
      margin:
          const pw.EdgeInsets.only(
        top: 10,
      ),
      decoration:
          const pw.BoxDecoration(
        border: pw.Border(
          bottom:
              pw.BorderSide(
            width: .5,
          ),
        ),
      ),
      height: 15,
    ),
  );
}

widgets.add(
  pw.SizedBox(height: 40),
);

widgets.add(
  pw.Center(
    child: pw.Column(
      children: [
        pw.Container(
          width: 220,
          decoration:
              const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                width: .6,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
  'Supervisor',
),
      ],
    ),
  ),
);

return widgets;
        }
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
        title: const Text(
          'Lista de Presença',
        ),
      ),
      body: FutureBuilder<
          List<dynamic>>(
        future:
            ApiService
                .buscarInscricoesPDF(),
        builder: (
          context,
          snapshot,
        ) {
          if (!snapshot
                  .hasData &&
              snapshot.connectionState !=
                  ConnectionState
                      .done) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error
                    .toString(),
              ),
            );
          }

          final lista =
              snapshot.data ?? [];

          final datas =
              lista
                  .map(
                    (e) => e['data']
                        .toString(),
                  )
                  .toSet()
                  .toList();

          datas.sort();

          return ListView.builder(
            padding:
                const EdgeInsets.all(
              20,
            ),
            itemCount:
                datas.length,
            itemBuilder:
                (
              context,
              index,
            ) {
              final data =
                  datas[index];

              return Card(
                child: ListTile(
                  leading:
                      const Icon(
                    Icons
                        .calendar_month,
                  ),
                  title: Text(
                    data,
                  ),
                  trailing:
                      const Icon(
                    Icons
                        .picture_as_pdf,
                  ),
                  onTap:
                      () async {
                    try {
                      final pdf =
                          await gerarListaPresenca(
                        data,
                      );

                      if (!context
                          .mounted) {
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
                                  Text(
                                data,
                              ),
                            ),
                            body:
                                PdfPreview(
                              maxPageWidth:
                                  700,
                              canChangeOrientation:
                                  false,
                              canChangePageFormat:
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
                      if (!context
                          .mounted) {
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
              );
            },
          );
        },
      ),
    );
  }
}