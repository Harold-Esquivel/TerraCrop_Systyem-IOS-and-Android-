import 'package:flutter/material.dart';

import '../data/agronomy_catalog.dart';
import '../data/models.dart';

/// Returns user-entered analysis data; persistence belongs to the caller.
class SoilAnalysisEditor extends StatefulWidget {
  const SoilAnalysisEditor({super.key, this.initial});
  final SoilAnalysis? initial;

  @override
  State<SoilAnalysisEditor> createState() => _SoilAnalysisEditorState();
}

class _SoilAnalysisEditorState extends State<SoilAnalysisEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController ph;
  late final TextEditingController ec;
  late final TextEditingController organicMatter;
  late NutrientLevel nitrogen;
  late NutrientLevel phosphorus;
  late NutrientLevel potassium;
  bool? moistureLow;
  bool? sandySoil;
  bool? waterlogged;
  bool? soilDiseaseHistory;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    ph = TextEditingController(text: initial?.ph?.toString() ?? '');
    ec = TextEditingController(text: initial?.ec?.toString() ?? '');
    organicMatter = TextEditingController(
      text: initial?.organicMatter?.toString() ?? '',
    );
    nitrogen = initial?.nitrogen ?? NutrientLevel.unknown;
    phosphorus = initial?.phosphorus ?? NutrientLevel.unknown;
    potassium = initial?.potassium ?? NutrientLevel.unknown;
    moistureLow = initial?.moistureLow;
    sandySoil = initial?.sandySoil;
    waterlogged = initial?.waterlogged;
    soilDiseaseHistory = initial?.soilDiseaseHistory;
  }

  @override
  void dispose() {
    ph.dispose();
    ec.dispose();
    organicMatter.dispose();
    super.dispose();
  }

  double? _number(TextEditingController field) {
    final text = field.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  String? _validate(String? value, double min, double? max) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null ||
        !number.isFinite ||
        number < min ||
        (max != null && number > max)) {
      return max == null
          ? 'Ingresa un número mayor o igual a $min'
          : 'Ingresa un valor entre $min y $max';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Análisis de suelo')),
    body: SafeArea(
      top: false,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Registra tu análisis y lo que observas en la parcela. Deja en «Sin dato» lo que no conoces.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 18),
              _numericField('pH medido', 'analysis-ph', ph, 0, 14),
              _numericField(
                'CE del extracto saturado (dS/m)',
                'analysis-ec',
                ec,
                0,
                1000,
              ),
              const Text(
                'Usa la CE del extracto saturado del suelo; no la CE del agua ni de otra extracción.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              _numericField(
                'Materia orgánica (%)',
                'analysis-organic-matter',
                organicMatter,
                0,
                100,
              ),
              const SizedBox(height: 6),
              const Text(
                'Disponibilidad de nutrientes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona el nivel que indica tu análisis de suelo.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              _nutrient(
                'Nitrógeno',
                'analysis-nitrogen',
                nitrogen,
                (v) => setState(() => nitrogen = v),
              ),
              _nutrient(
                'Fósforo',
                'analysis-phosphorus',
                phosphorus,
                (v) => setState(() => phosphorus = v),
              ),
              _nutrient(
                'Potasio',
                'analysis-potassium',
                potassium,
                (v) => setState(() => potassium = v),
              ),
              const SizedBox(height: 12),
              _observation(
                'Humedad baja observada',
                moistureLow,
                (v) => setState(() => moistureLow = v),
              ),
              _observation(
                'Suelo arenoso',
                sandySoil,
                (v) => setState(() => sandySoil = v),
              ),
              _observation(
                'Encharcamiento o napa superficial',
                waterlogged,
                (v) => setState(() => waterlogged = v),
              ),
              _observation(
                'Enfermedades de suelo en Allium o papa',
                soilDiseaseHistory,
                (v) => setState(() => soilDiseaseHistory = v),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('analysis-save'),
                onPressed: () {
                  if (!(form.currentState?.validate() ?? false)) return;
                  Navigator.pop(
                    context,
                    SoilAnalysis(
                      ph: _number(ph),
                      ec: _number(ec),
                      organicMatter: _number(organicMatter),
                      nitrogen: nitrogen,
                      phosphorus: phosphorus,
                      potassium: potassium,
                      moistureLow: moistureLow,
                      sandySoil: sandySoil,
                      waterlogged: waterlogged,
                      soilDiseaseHistory: soilDiseaseHistory,
                      sampledAt: widget.initial?.sampledAt,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar análisis'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _numericField(
    String label,
    String key,
    TextEditingController controller,
    double min,
    double? max,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: 'Sin dato'),
      validator: (value) => _validate(value, min, max),
    ),
  );

  Widget _nutrient(
    String label,
    String key,
    NutrientLevel value,
    ValueChanged<NutrientLevel> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: DropdownButtonFormField<NutrientLevel>(
      key: ValueKey(key),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final level in NutrientLevel.values)
          DropdownMenuItem(value: level, child: Text(nutrientLabel(level))),
      ],
      onChanged: (level) {
        if (level != null) onChanged(level);
      },
    ),
  );

  Widget _observation(
    String label,
    bool? value,
    ValueChanged<bool?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: DropdownButtonFormField<int>(
      initialValue: value == null
          ? -1
          : value
          ? 1
          : 0,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: -1, child: Text('Sin dato')),
        DropdownMenuItem(value: 0, child: Text('No')),
        DropdownMenuItem(value: 1, child: Text('Sí')),
      ],
      onChanged: (v) => onChanged(v == -1 || v == null ? null : v == 1),
    ),
  );
}

String nutrientLabel(NutrientLevel value) => switch (value) {
  NutrientLevel.unknown => 'Sin dato',
  NutrientLevel.low => 'Bajo',
  NutrientLevel.adequate => 'Adecuado',
  NutrientLevel.high => 'Alto',
};

class CropHistoryEditor extends StatefulWidget {
  const CropHistoryEditor({
    super.key,
    required this.initial,
    required this.catalog,
  });
  final List<String> initial;
  final AgronomyCatalog catalog;
  @override
  State<CropHistoryEditor> createState() => _CropHistoryEditorState();
}

class _CropHistoryEditorState extends State<CropHistoryEditor> {
  late final List<String> history = [...widget.initial];
  String? selected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de cultivos')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Registra campañas anteriores, de la más antigua a la más reciente. El cultivo actual no se añade automáticamente a esta lista hasta que registres una nueva siembra.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Text('Aún no hay campañas anteriores registradas.'),
          for (var i = 0; i < history.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(history[i]),
              subtitle: i == history.length - 1
                  ? const Text('Más reciente')
                  : null,
              trailing: IconButton(
                tooltip: 'Eliminar campaña ${i + 1}',
                onPressed: () => setState(() => history.removeAt(i)),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cultivo de la campaña anterior',
            ),
            items: [
              for (final crop in widget.catalog.crops)
                DropdownMenuItem(value: crop.name, child: Text(crop.name)),
            ],
            onChanged: (value) => setState(() => selected = value),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: selected == null
                ? null
                : () => setState(() => history.add(selected!)),
            icon: const Icon(Icons.add),
            label: const Text('Añadir campaña'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('history-save'),
            onPressed: () =>
                Navigator.pop(context, List<String>.unmodifiable(history)),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar historial'),
          ),
        ],
      ),
    ),
  );
}
