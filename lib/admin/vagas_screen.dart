import 'package:flutter/material.dart';

class VagasScreen extends StatelessWidget {
  const VagasScreen({
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
          'Gerenciar Vagas',
        ),
      ),
      body:
          const Center(
        child: Text(
          'Tela de Vagas',
        ),
      ),
    );
  }
}