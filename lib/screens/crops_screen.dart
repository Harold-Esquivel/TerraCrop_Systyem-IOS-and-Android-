import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/models.dart';
import '../data/terra_store.dart';

class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parcels = context.watch<TerraStore>().parcels;
    final alerts = parcels.where((p) => p.warning).length;
    return Column(
      children: [
        PageIntro(
          eyebrow: 'Monitoreo inteligente',
          title: 'Mis cultivos',
          subtitle: 'La salud de tu campo, siempre clara',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
            children: [
              StaggerItem(
                index: 0,
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2671E8), Color(0xFF4B98FF)],
                    ),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen de tu campo',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${parcels.length} parcelas activas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              alerts == 0
                                  ? 'Todo luce bien hoy'
                                  : '$alerts necesitan tu atención',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.spa_rounded,
                        size: 60,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: Text('Tus parcelas', maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge),
                  ),
                  Text(
                    '${parcels.length} en total',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (parcels.isEmpty)
                const SurfaceCard(
                  child: Text('Aún no hay parcelas. Crea una desde el mapa.'),
                ),
              for (var i = 0; i < parcels.length; i++) ...[
                StaggerItem(
                  key: ValueKey(parcels[i].id),
                  index: i + 1,
                  child: _CropCard(parcel: parcels[i]),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CropCard extends StatefulWidget {
  const _CropCard({required this.parcel});
  final Parcel parcel;
  @override
  State<_CropCard> createState() => _CropCardState();
}

class _CropCardState extends State<_CropCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.parcel;
    final riskColor = p.critical
        ? const Color(0xFFE57D45)
        : p.warning
        ? const Color(0xFFD8A13D)
        : green;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F7EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.eco_rounded, color: green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Cultivo de ${p.crop}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  p.status,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              _data(
                'pH del suelo',
                p.ph.toStringAsFixed(1),
                Icons.water_drop_outlined,
              ),
              _data('Humedad', '${p.moisture.round()}%', Icons.opacity_rounded),
              _data(
                'Nutrientes',
                '${((p.nitrogen + p.phosphorus + p.potassium) / 3).round()}%',
                Icons.grain_rounded,
              ),
            ],
          ),
          if (p.warning) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: Color(0xFFE58A4D),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _advice(p),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ink,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 11),
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    expanded ? 'Ver menos' : 'Ver recomendaciones',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: blue,
                  size: 18,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: border),
                        const SizedBox(height: 6),
                        Text(
                          p.critical
                              ? 'Cultivos alternativos sugeridos'
                              : 'Acciones recomendadas',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          p.critical
                              ? 'Considera quinua o papa, según el clima y un análisis de suelo local. Corrige el pH antes de cambiar el cultivo.'
                              : 'Mantén un riego constante, añade compost y revisa el suelo semanalmente.',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _data(String label, String value, IconData icon) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 10)),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(icon, color: green, size: 15),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _advice(Parcel p) {
    if (p.ph < 5.5) {
      return 'El pH está muy bajo. Considera una corrección con cal agrícola tras un análisis de suelo.';
    }
    if (p.ph > 7.8) {
      return 'El pH está alto. Consulta una corrección de suelo antes de sembrar.';
    }
    if (p.moisture < 40) {
      return 'La humedad es baja. Revisa el riego de esta parcela.';
    }
    return 'Los nutrientes están bajos. Añade compost y confirma con un análisis de suelo.';
  }
}
