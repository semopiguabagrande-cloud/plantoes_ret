import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/api_service.dart';
import 'inscricoes_screen.dart';
import 'relatorios_screen.dart';
import 'lista_presenca_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({
    super.key,
  });

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome>
    with WidgetsBindingObserver {
  // ===================================================
  // HEARTBEAT DO ADMIN
  // ===================================================

  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _iniciarHeartbeat();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  void _iniciarHeartbeat() {
    _heartbeat?.cancel();

    _heartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) async {
        if (!ApiService.possuiSessao) {
          _sessaoEncerrada();
          return;
        }

        final ok = await ApiService.heartbeat();

        if (!ok) {
          _sessaoEncerrada();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      if (ApiService.possuiSessao) {
        ApiService.heartbeat();
        _iniciarHeartbeat();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _heartbeat?.cancel();
    }
  }

  // ===================================================
  // SESSÃO ENCERRADA PELO SERVIDOR
  // ===================================================

  void _sessaoEncerrada() {
    if (!mounted) return;

    _heartbeat?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          'Sua sessão foi encerrada. Faça login novamente.',
        ),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ===================================================
  // BOTÕES DO PAINEL
  // ===================================================

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

  // ===================================================
  // SAIR DO ADMINISTRADOR
  // ===================================================

  Future<void> _logout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sair do sistema'),
          content: const Text(
            'Deseja realmente sair do painel administrativo?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('SAIR'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    _heartbeat?.cancel();

    // ApiService.logout() SEMPRE limpa a sessão local.
    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final desktop =
        MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xff021426),
      appBar: AppBar(
        backgroundColor: const Color(0xff00162f),
        centerTitle: true,
        title: const Text('Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 110,
                    color: Colors.white,
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Painel Administrativo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: desktop ? 32 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Gerenciamento do sistema de plantões',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 50),

                  botao(
                    icone: Icons.list_alt,
                    titulo: 'VISUALIZAR INSCRIÇÕES',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const InscricoesScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 20),

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
