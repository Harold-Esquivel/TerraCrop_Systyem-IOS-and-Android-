import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/alert_service.dart';
import '../data/cloud_service.dart';
import '../data/models.dart';
import '../data/terra_store.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String? selectedId;
  Parcel? draft;

  void change(Parcel next) => setState(() => draft = next);

  void commit(Parcel original) {
    final next = draft;
    if (next == null) return;
    context.read<TerraStore>().updateParcel(next);
    if (next.critical && !original.critical) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE46F4D),
          content: Text('Alerta crítica: ${next.name} necesita atención.'),
          duration: const Duration(seconds: 4),
        ),
      );
      AlertService.instance.notifyCritical(next.name);
      CloudService.instance.publishAlert(next.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcels = context.watch<TerraStore>().parcels;
    final selected =
        parcels.where((p) => p.id == selectedId).firstOrNull ??
        (parcels.isEmpty ? null : parcels.first);
    final current = draft?.id == selected?.id ? draft : selected;
    return Column(
      children: [
        const PageIntro(
          eyebrow: 'Laboratorio virtual',
          title: 'Modo prueba',
          subtitle: 'Explora escenarios sin afectar tus sensores',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
            children: [
              const StaggerItem(
                index: 0,
                child: SurfaceCard(
                  color: paleBlue,
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 28, color: blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Modifica los valores para ver cómo cambia el estado de tu cultivo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Selecciona una parcela',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 9),
              if (parcels.isEmpty)
                const SurfaceCard(
                  child: Text('Crea una parcela en el mapa para comenzar.'),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  key: ValueKey(selected?.id),
                  items: [
                    for (final p in parcels)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (id) => setState(() {
                    selectedId = id;
                    draft = null;
                  }),
                ),
              if (current != null && selected != null) ...[
                const SizedBox(height: 17),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: current.critical
                        ? const Color(0xFFFFF2E9)
                        : const Color(0xFFEAF8F0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        current.critical
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: current.critical ? Colors.deepOrange : green,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          current.critical
                              ? 'Estado crítico · revisa las recomendaciones'
                              : current.warning
                              ? 'Requiere atención'
                              : 'Condiciones saludables',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: current.critical ? Colors.deepOrange : green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                StaggerItem(
                  index: 1,
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Propiedades del suelo',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Desliza para simular nuevos valores',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        _slider(
                          'Nivel de pH',
                          current.ph,
                          3,
                          9,
                          '',
                          (value) => change(current.copyWith(ph: value)),
                          () => commit(selected),
                        ),
                        _slider(
                          'Humedad',
                          current.moisture,
                          0,
                          100,
                          '%',
                          (value) => change(current.copyWith(moisture: value)),
                          () => commit(selected),
                        ),
                        _slider(
                          'Nitrógeno (N)',
                          current.nitrogen,
                          0,
                          100,
                          '%',
                          (value) => change(current.copyWith(nitrogen: value)),
                          () => commit(selected),
                        ),
                        _slider(
                          'Fósforo (P)',
                          current.phosphorus,
                          0,
                          100,
                          '%',
                          (value) =>
                              change(current.copyWith(phosphorus: value)),
                          () => commit(selected),
                        ),
                        _slider(
                          'Potasio (K)',
                          current.potassium,
                          0,
                          100,
                          '%',
                          (value) => change(current.copyWith(potassium: value)),
                          () => commit(selected),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PressButton(
                  label: 'Restablecer valores saludables',
                  icon: Icons.restart_alt_rounded,
                  outlined: true,
                  onPressed: () {
                    final reset = current.copyWith(
                      ph: 6.5,
                      moisture: 68,
                      nitrogen: 70,
                      phosphorus: 65,
                      potassium: 75,
                    );
                    context.read<TerraStore>().updateParcel(reset);
                    setState(() => draft = null);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String unit,
    ValueChanged<double> onChanged,
    VoidCallback onEnd,
  ) => Padding(
    padding: const EdgeInsets.only(top: 11),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                '${value.toStringAsFixed(label == 'Nivel de pH' ? 1 : 0)}$unit',
                key: ValueKey(value.round()),
                style: const TextStyle(
                  color: blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: blue,
          onChanged: onChanged,
          onChangeEnd: (_) => onEnd(),
        ),
      ],
    ),
  );
}
