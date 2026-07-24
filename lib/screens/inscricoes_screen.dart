import 'package:flutter/material.dart';

class InscricoesScreen
    extends StatelessWidget {
  const InscricoesScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Inscrições',
        ),
      ),
      body: const Center(
        child: Text(
          'Tela de inscrições',
        ),
      ),
    );
  }
}