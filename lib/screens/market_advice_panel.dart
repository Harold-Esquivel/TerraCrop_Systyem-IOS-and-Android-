import 'package:flutter/material.dart';

import '../app/ui.dart';
import '../data/agronomy_catalog.dart';
import '../data/campaign_engine.dart';
import '../data/market_recommendations.dart';

class MarketAdvicePanel extends StatelessWidget {
  const MarketAdvicePanel({super.key, required this.evaluation});
  final CampaignEvaluation evaluation;
  @override
  Widget build(BuildContext context) {
    final catalog = AgronomyCatalog.current;
    if (catalog == null) return const SizedBox.shrink();
    final advice = MarketRecommendationService(catalog).recommend(evaluation);
    return SurfaceCard(
      key: const Key('market-campaign-advice'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qué verificar en ${evaluation.input.parcel.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Campaña de ${evaluation.crop.name} · ${evaluation.input.start.month}/${evaluation.input.start.year}',
          ),
          const Text(
            'Contexto capturado al evaluar la campaña. Tras cambiar el suelo o la planificación, vuelve a evaluar en Smart-Cycle.',
          ),
          for (final m in advice.measurements)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(m.title),
              subtitle: Text(m.reason),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${m.method}\n${m.limitations}\nCalibración: ${m.calibration}\nReferencias: ${m.references.join(', ')}',
                  ),
                ),
                for (final p in m.products)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.measurement}\n${p.description}\n${p.notes}',
                    ),
                  ),
                const Text(
                  'Comprobar rango, protocolo y compatibilidad técnica antes de elegir; el catálogo no acredita interoperabilidad directa con el móvil.',
                ),
              ],
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Opciones microbianas y sus condiciones'),
            subtitle: Text(
              '${advice.microorganisms.length} fichas relacionadas con reglas activas',
            ),
            children: [
              if (advice.microorganisms.isEmpty)
                const Text(
                  'No hay una condición medida que justifique sugerir un microorganismo específico.',
                ),
              for (final m in advice.microorganisms)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(m.profile.group),
                  subtitle: Text(
                    m.blockers.isEmpty
                        ? 'Por verificar antes de considerar aplicación'
                        : 'No sugerido en estas condiciones',
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        [
                          m.profile.species,
                          'Finalidad: ${m.profile.function}',
                          'Reglas relacionadas: ${m.ruleIds.join(', ')}',
                          'Cultivos: ${m.profile.crops}',
                          'Condiciones: ${m.profile.conditions}',
                          'Aplicación de referencia: ${m.profile.application}',
                          'Límites: ${m.profile.limitations}',
                          ...m.blockers,
                          ...m.pending,
                          'Evidencia: ${m.references.join(', ')}',
                          'No sustituye drenaje, manejo, rotación ni fertilización validada. La respuesta depende de la cepa y de la parcela.',
                        ].join('\n'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Text(
            'Estas verificaciones no requieren realizar una compra. El catálogo y el carrito de demostración siguen disponibles.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
