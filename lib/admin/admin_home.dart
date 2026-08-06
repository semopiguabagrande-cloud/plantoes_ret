import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'inscricoes_screen.dart';
import 'relatorios_screen.dart';
import 'lista_presenca_screen.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({
    super.key,
  });

  Widget botao({
    required IconData icone,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton.icon(
        icon: Icon(icone),
        label: Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final desktop =
        MediaQuery.of(context)
                .size
                .width >
            800;

    return Scaffold(
      backgroundColor:
          const Color(
        0xff021426,
      ),
      appBar: AppBar(
        backgroundColor:
            const Color(
          0xff00162f,
        ),
        centerTitle: true,
        title: const Text(
          'Administrador',
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
            ),
            tooltip: 'Sair',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child:
            SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.all(
              30,
            ),
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 550,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons
                        .admin_panel_settings,
                    size: 110,
                    color:
                        Colors.white,
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  Text(
                    'Painel Administrativo',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          desktop
                              ? 32
                              : 26,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Text(
                    'Gerenciamento do sistema de plantões',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize:
                          16,
                    ),
                  ),

                  const SizedBox(
                    height: 50,
                  ),

                  /// INSCRIÇÕES

                  botao(
                    icone:
                        Icons.list_alt,
                    titulo:
                        'VISUALIZAR INSCRIÇÕES',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  const InscricoesScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                                 /// RELATÓRIO PDF

                  botao(
                    icone: Icons.picture_as_pdf,
                    titulo: 'RELATÓRIO GERAL PDF',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const RelatoriosScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  /// LISTA DE PRESENÇA

                  botao(
                    icone: Icons.fact_check,
                    titulo: 'LISTA DE PRESENÇA',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ListaPresencaScreen(),
                        ),
                      );
                    },
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