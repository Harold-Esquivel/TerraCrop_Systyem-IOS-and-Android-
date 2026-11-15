import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/terra_store.dart';
import 'devices_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> editName() async {
    final store = context.read<TerraStore>();
    final controller = TextEditingController(text: store.userName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tu nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      store.updateName(controller.text);
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TerraStore>();
    final nextGoal = ((store.streak ~/ 7) + 1) * 7;
    return Column(
      children: [
        const PageIntro(
          eyebrow: 'Tu espacio',
          title: 'Mi perfil',
          subtitle: 'Cada día cuenta para un campo mejor',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 95),
            children: [
              StaggerItem(
                index: 0,
                child: SurfaceCard(
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.colors.softBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 35,
                          color: context.colors.blue,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.userName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Miembro de TerraCrop',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: editName,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: context.colors.blue,
                        ),
                        tooltip: 'Editar nombre',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('profile-devices-button'),
                icon: const Icon(Icons.sensors_outlined),
                label: const Text('Dispositivos'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Mis dispositivos')),
                      body: const SafeArea(top: false, child: DevicesScreen()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StaggerItem(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(23),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF12624B), Color(0xFF1769D2)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFB6F4D6),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Racha diaria',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: store.streak.toDouble()),
                        duration: const Duration(milliseconds: 950),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, _) => Text(
                          '${value.round()} días',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '¡Sigue entrando para cuidar tus cultivos!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (store.streak % 7) / 7),
                        duration: const Duration(milliseconds: 1000),
                        builder: (_, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFB6F4D6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Próxima meta: $nextGoal días',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 23),
              Text(
                'Tu actividad',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              StaggerItem(
                index: 2,
                child: SurfaceCard(
                  child: Row(
                    children: [
                      _stat(
                        '${store.parcels.length}',
                        'Parcelas',
                        Icons.grid_view_rounded,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: context.colors.border,
                      ),
                      _stat(
                        '${store.parcels.fold<int>(0, (s, p) => s + p.devices.length)}',
                        'Dispositivos',
                        Icons.sensors_outlined,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: context.colors.border,
                      ),
                      _stat(
                        '${store.parcels.where((p) => !p.warning).length}',
                        'Saludables',
                        Icons.eco_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              StaggerItem(
                index: 3,
                child: SurfaceCard(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: context.colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Los datos de sensores son demostrativos. Explora escenarios desde Smart-Cycle.',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: context.colors.blue, size: 19),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colors.ink,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.colors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}
