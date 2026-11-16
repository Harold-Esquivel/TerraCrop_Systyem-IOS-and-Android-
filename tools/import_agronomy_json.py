"""Normalize TerraCrop 2.1 JSON offline. All free text remains inert source data."""
import hashlib
import json
import math
import re

from import_agronomy import CROP, COMPATIBILITY, SEQUENCE, STEP, MICRO, RULE, SOURCE


MAPPINGS = [
    ('cultivos', 'crops', CROP, '''id_cultivo nombre nombre_cientifico familia_botanica
        tipo_de_cultivo leguminosa clasificacion evidencias demanda_hidrica_min
        demanda_hidrica_max demanda_hidrica_prom unidad_demanda periodo_dias_min
        periodo_dias_max periodo_dias_prom periodo_descripcion temp_optima_min_c
        temp_optima_max_c ph_min ph_max n_kg_ha_min n_kg_ha_max p2o5_kg_ha_min
        p2o5_kg_ha_max k2o_kg_ha_min k2o_kg_ha_max salinidad_categoria
        salinidad_umbral_ce_ds_m salinidad_nota observaciones estado_y_validacion'''),
    ('compatibilidad', 'compatibility', COMPATIBILITY, '''id_previo cultivo_previo
        id_siguiente cultivo_siguiente nivel puntaje_de_0_a_3 regla_o_condicion observacion'''),
    ('secuencias', 'sequences', SEQUENCE, '''id_secuencia rol secuencia
        demanda_hidrica_total_m3_ha periodo_total_dias demanda_por_dia_m3_ha
        diferencia_demanda_vs_referencia campanas_con_cultivo_sensible familia_diferentes
        beneficio_esperado_y_el_mecanismo condiciones_para_que_funcione
        limitaciones_y_riesgo microorganismos_sugeridos'''),
    ('secuencias_detalle', 'sequenceDetails', STEP, '''id_secuencia campana id_cultivo
        cultivo familia_botanica presencia_local demanda_hidrica_m3_ha periodo_dias salinidad_categoria'''),
    ('microorganismos', 'microorganisms', MICRO, '''id_micro grupo genero_especie
        funcion_principal problema_que_resuelve cultivos condiciones_para_el_uso
        forma_de_aplicacion limitaciones_precauciones_a_tener'''),
    ('suelo_reglas', 'soilRules', RULE, '''id_regla parametro condicion_umbral
        interpretacion accion_recomendada microorganismos_sugeridos_ids advertencia'''),
    ('fuentes', 'sources', SOURCE, 'fuentes_por_id referencia respaldo link'),
]


def reject_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON key: {key}')
        result[key] = value
    return result


def numeric(value):
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f'Expected finite number or null: {value!r}')
    return value


def split_ids(value):
    return [v.strip() for v in (value or '').split(';') if v.strip()]


def normalize(row, schema, source_keys):
    result = {}
    keys = source_keys.split()
    if len(schema) != len(keys):
        raise ValueError('Internal mapping length mismatch')
    for (_, field, kind), key in zip(schema, keys):
        value = row[key]
        if kind in (int, float):
            result[field] = numeric(value)
            if kind is int and value is not None and value != int(value):
                raise ValueError(f'{key}: expected integer')
        elif kind is bool:
            if value not in ('Sí', 'No'):
                raise ValueError(f'{key}: expected Sí/No')
            result[field] = value == 'Sí'
        elif kind is list:
            result[field] = split_ids(value)
        else:
            if value is not None and not isinstance(value, str):
                raise ValueError(f'{key}: expected text')
            result[field] = (value or '').strip()
    return result


def months(value):
    # Labels such as "Por confirmar", "No aplica" and perennial cuts are
    # preserved as labels, never silently interpreted as all twelve months.
    if not isinstance(value, str) or not re.fullmatch(r'\d+(;\d+)*', value):
        return []
    result = [int(v) for v in value.split(';')]
    if len(result) != len(set(result)) or any(not 1 <= v <= 12 for v in result):
        raise ValueError(f'Invalid months: {value}')
    return result


def validate_supplemental(raw):
    groups = {
        'cultivos': ('id_cultivo', r'C\d{3}'),
        'calendario_la_joya': ('id_cultivo', r'C\d{3}'),
        'umbrales_criticos': ('id_cultivo', r'C\d{3}'),
        'secuencias': ('id_secuencia', r'S\d{2}'),
        'secuencias_locales': ('id', r'L\d{2}'),
        'suelo_reglas': ('id_regla', r'S\d{3}'),
        'microorganismos': ('id_micro', r'M\d{3}'),
        'alertas_preventivas': ('id_alerta', r'A\d{2}'),
        'advertencias': ('id', r'W\d{2}'),
        'fuentes_dinamicas': ('id', r'FD\d{2}'),
        'fuentes': ('fuentes_por_id', r'F\d{2}'),
        'revision_de_datos': ('id', r'R\d{2}'),
    }
    ids = {}
    for key, (field, pattern) in groups.items():
        values = [r[field] for r in raw[key]]
        if len(set(values)) != len(values) or any(not re.fullmatch(pattern, v) for v in values):
            raise ValueError(f'Invalid or duplicate identifiers: {key}')
        ids[key] = set(values)
    for key in ('calendario_la_joya', 'umbrales_criticos'):
        if ids[key] != ids['cultivos']:
            raise ValueError(f'{key}: must cover all crops')
    references = [
        ('microorganismos_presentaciones', 'id_micro', 'microorganismos', r'M\d{3}'),
        ('productos_disponibles', 'id_micro', 'microorganismos', r'M\d{3}'),
        ('alertas_preventivas', 'fuente_dinamica_ids', 'fuentes_dinamicas', r'FD\d{2}'),
        ('alertas_preventivas', 'cultivos_afectados_ids', 'cultivos', r'C\d{3}'),
        ('alertas_preventivas', 'microorganismos_ids', 'microorganismos', r'M\d{3}'),
        ('alertas_preventivas', 'advertencias_ids', 'advertencias', r'W\d{2}'),
        ('secuencias_locales', 'ids_de_cultivos_orden', 'cultivos', r'C\d{3}'),
        ('secuencias_locales', 'advertencias_ids', 'advertencias', r'W\d{2}'),
    ]
    for table, field, target, pattern in references:
        for row in raw[table]:
            if not set(re.findall(pattern, row[field] or '')).issubset(ids[target]):
                raise ValueError(f'Unknown reference: {table}.{field}')


def import_json(path):
    raw = json.loads(path.read_text(encoding='utf-8-sig'), object_pairs_hook=reject_duplicates)
    if not isinstance(raw, dict) or raw.get('meta', {}).get('version') != '2.1':
        raise ValueError('Expected TerraCrop JSON version 2.1')
    validate_supplemental(raw)
    data = {
        'schemaVersion': 2,
        'source': {
            'fileName': path.name,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'version': raw['meta']['version'],
            'generated': raw['meta']['generado'],
            'region': 'La Joya, Arequipa',
            'verification': 'Datos proporcionados en el JSON; estados y revisiones pendientes preservados, sin verificación independiente.',
            'nutrientUnit': 'kg/ha de N, P2O5 y K2O: referencias de fertilización, no concentraciones medidas en suelo. Extracción y aporte de N se conservan aparte; algunos valores son proxies.',
            'waterMeaning': 'Demanda hídrica del cultivo, no riego aplicado ni ahorro de agua.',
        },
        'notes': [
            'La demanda hídrica del cultivo NO es el riego aplicado ni un ahorro garantizado.',
            'La clasificación, las fechas y las referencias son declaraciones del archivo suministrado.',
            'Las revisiones pendientes no se aplican automáticamente a las fichas ni a las secuencias.',
        ],
        'sequenceNotes': ['Las secuencias diseñadas son escenarios; las prácticas locales conservan su evidencia y confianza.'],
        'rawTables': [],
        'formulaCells': [],
        'rawDocument': raw,
    }
    for table, target, schema, keys in MAPPINGS:
        data[target] = [normalize(row, schema, keys) for row in raw[table]]
    for crop, row in zip(data['crops'], raw['cultivos']):
        crop.update(
            soilContribution=row['aporte_al_suelo'].strip(),
            nitrogenContribution=numeric(row['aporte_de_n_al_siguiente_cultivo']),
            bridgeSuitability=row['apto_como_cultivo_puente'].strip(),
            extractionN=numeric(row['extraccion_n_kg_ha_usada_en_balance']),
            extractionP=numeric(row['extraccion_p2o5_kg_ha_usada_en_balance']),
            extractionK=numeric(row['extraccion_k2o_kg_ha_usada_en_balance']),
            extractionSource=row['fuente_de_la_extraccion'].strip(),
            localPresence=row['presencia_en_la_joya'].strip(),
        )
    for source in data['sources']:
        source['url'] = source['url'] or None
    data['calendars'] = [dict(
        cropId=r['id_cultivo'], sowingMonths=months(r['meses_de_siembra_trasplante_112']),
        harvestMonths=months(r['meses_de_cosecha_112']),
        sowingLabel=r['meses_de_siembra_trasplante_112'], harvestLabel=r['meses_de_cosecha_112'],
        duration=r['duracion_verificada_del_ciclo'], campaigns=r['campanas_por_ano'],
        evidence=r['evidencia_observada'], confidence=r['nivel_de_confianza'],
    ) for r in raw['calendario_la_joya']]
    data['criticalThresholds'] = [dict(
        cropId=r['id_cultivo'], low=numeric(r['t_critica_baja_el_desarrollo_se_detiene']),
        lethal=numeric(r['t_letal_c_helada_que_mata_tejido']),
        high=numeric(r['t_critica_alta_c_dano_por_calor']), stage=r['etapa_mas_sensible'],
        effect=r['efecto_si_se_supera'], source=r['fuente'], confidence=r['confianza'],
    ) for r in raw['umbrales_criticos']]
    return data
