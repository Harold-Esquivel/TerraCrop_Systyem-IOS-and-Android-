import 'crop_recommendations.dart';
import 'models.dart';

enum CropCareTopic {
  drainage,
  salinity,
  ph,
  water,
  organicMatter,
  nitrogen,
  phosphorus,
  potassium,
  nutrientExcess,
  soilHealth,
}

/// A short presentation of the existing assessment, preserving its conditions.
/// This layer neither changes measurements nor calculates application doses.
class CropCareAction {
  const CropCareAction({
    required this.id,
    required this.topic,
    required this.title,
    required this.reason,
    required this.instruction,
    required this.severity,
    required this.sourceIssueIds,
  });

  final String id, title, reason, instruction;
  final CropCareTopic topic;
  final RecommendationSeverity severity;
  final List<String> sourceIssueIds;
}

List<CropCareAction> buildCropCarePlan(
  Parcel parcel,
  CropAssessment assessment,
) {
  final issues = assessment.issues;
  final ids = issues.map((issue) => issue.id).toSet();
  final waterlogged = ids.contains('S012');
  final saline =
      ids.contains('S001') || ids.contains('S002') || ids.contains('crop-ec');
  final actions = <CropCareAction>[];

  void add(
    Set<String> matches,
    CropCareTopic topic,
    String title,
    String reason,
    String instruction,
  ) {
    final sources = issues
        .where((issue) => matches.contains(issue.id))
        .toList();
    if (sources.isEmpty) return;
    final severity = sources.fold(
      RecommendationSeverity.info,
      (value, issue) =>
          issue.severity.index > value.index ? issue.severity : value,
    );
    actions.add(
      CropCareAction(
        id: sources.first.id,
        topic: topic,
        title: title,
        reason: reason,
        instruction: instruction,
        severity: severity,
        sourceIssueIds: List.unmodifiable(sources.map((issue) => issue.id)),
      ),
    );
  }

  add(
    {'S012'},
    CropCareTopic.drainage,
    'Mejora el drenaje',
    'Hay encharcamiento',
    'Reduce la lámina de riego y revisa drenes o camas elevadas antes de aportar más agua.',
  );
  add(
    {'S001', 'S002', 'crop-ec'},
    CropCareTopic.salinity,
    'Controla las sales',
    'Salinidad por encima de la referencia',
    waterlogged
        ? 'Resuelve el encharcamiento antes de planificar un lavado de sales.'
        : 'Planifica un lavado de sales solo si el drenaje funciona; revisa la tolerancia del cultivo.',
  );
  add(
    {'S003', 'S004', 'S006', 'crop-ph'},
    CropCareTopic.ph,
    ids.contains('S006')
        ? 'Revisa la acidez del suelo'
        : 'Revisa el pH del suelo',
    'pH ${(parcel.soilAnalysis?.ph ?? parcel.ph).toStringAsFixed(1)} · ${ids.contains('S006')
        ? 'bajo / ácido'
        : ids.contains('S003')
        ? 'muy alto'
        : ids.contains('S004')
        ? 'alcalino'
        : 'fuera del rango del cultivo'}',
    ids.contains('S003')
        ? 'Solicita análisis de sodio antes de usar yeso u otras enmiendas; el pH solo no basta.'
        : ids.contains('S006')
        ? 'Evalúa cal agrícola solo con análisis de suelo; vuelve a medir a los 6 meses.'
        : ids.contains('S004')
        ? 'Evalúa materia orgánica y confirma el análisis antes de corregir el pH.'
        : 'Confirma el pH y el rango de tu cultivo antes de elegir una enmienda.',
  );
  add(
    {'S011', 'low-moisture', 'demo-moisture'},
    CropCareTopic.water,
    waterlogged ? 'Comprueba la humedad' : 'Ajusta el riego',
    waterlogged ? 'Humedad baja y encharcamiento registrados' : 'Humedad baja',
    waterlogged
        ? 'Los datos se contradicen: revisa la humedad y resuelve el drenaje antes de aumentar el riego.'
        : ids.contains('S011')
        ? 'Usa riegos más frecuentes y de menor lámina; considera goteo o cobertura del suelo.'
        : 'Confirma la humedad y la textura del suelo antes de aumentar la frecuencia de riego.',
  );
  add(
    {'S007'},
    CropCareTopic.organicMatter,
    'Refuerza la materia orgánica',
    'Materia orgánica: ${parcel.soilAnalysis?.organicMatter?.toStringAsFixed(1)}% · baja',
    saline
        ? 'Evalúa compost maduro con el análisis de salinidad; evita estiércol fresco.'
        : 'Incorpora compost maduro o estiércol bien curado; evita el estiércol fresco.',
  );
  String nutrientInstruction(String instruction) => waterlogged || saline
      ? '$instruction Ajusta el aporte tras revisar drenaje y salinidad.'
      : '$instruction Ajusta el aporte con el análisis.';
  add(
    {'S009'},
    CropCareTopic.nitrogen,
    'Refuerza el nitrógeno',
    'Nitrógeno bajo',
    nutrientInstruction('Fracciona el aporte de nitrógeno.'),
  );
  add(
    {'S008'},
    CropCareTopic.phosphorus,
    'Refuerza el fósforo',
    'Fósforo bajo',
    nutrientInstruction('Evalúa fósforo localizado en la siembra.'),
  );
  add(
    {'S010'},
    CropCareTopic.potassium,
    'Refuerza el potasio',
    'Potasio bajo',
    nutrientInstruction(
      saline
          ? 'Evalúa sulfato de potasio en lugar de cloruro.'
          : 'Evalúa un aporte de potasio según el cultivo.',
    ),
  );
  for (final nutrient in ['nitrógeno', 'fósforo', 'potasio']) {
    add(
      {'high-$nutrient'},
      CropCareTopic.nutrientExcess,
      'Evita añadir más $nutrient',
      'Nivel alto en el análisis',
      'Revisa el informe y el abonado antes de hacer un nuevo aporte.',
    );
  }
  add(
    {'S013'},
    CropCareTopic.soilHealth,
    'Cambia de familia en la rotación',
    'Antecedentes de enfermedades del suelo',
    'Alterna con otra familia durante varias campañas; el biocontrol es un complemento.',
  );

  actions.sort((a, b) {
    // Drainage is a prerequisite for irrigation and salt leaching, even when
    // those issues have a higher individual severity in the source assessment.
    final aNeedsDrainage = a.topic == CropCareTopic.drainage;
    final bNeedsDrainage = b.topic == CropCareTopic.drainage;
    if (aNeedsDrainage != bNeedsDrainage) return aNeedsDrainage ? -1 : 1;
    final severity = b.severity.index.compareTo(a.severity.index);
    if (severity != 0) return severity;
    final topic = a.topic.index.compareTo(b.topic.index);
    return topic != 0 ? topic : a.id.compareTo(b.id);
  });
  return List.unmodifiable(actions);
}
