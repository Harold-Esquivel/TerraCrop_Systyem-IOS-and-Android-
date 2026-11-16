#!/usr/bin/env python3
"""Verify a supplied NASA POWER package offline and export coordinate-free history.

Private originals stay at the user-supplied location. No embedded instructions
or URLs are executed. Monthly rain is summed; other variables are averaged.
"""
import argparse
import calendar
from collections import defaultdict
import csv
from datetime import date, timedelta
import hashlib
import io
import json
import math
from pathlib import Path
import re
import statistics

ROOT = Path(__file__).resolve().parents[1]
UNITS = {
    'T2M': ('C', '°C'), 'T2M_MAX': ('C', '°C'), 'T2M_MIN': ('C', '°C'),
    'PRECTOTCORR': ('mm/day', 'mm/month'), 'RH2M': ('%', '%'),
    'ALLSKY_SFC_SW_DWN': ('MJ/m^2/day', 'kWh/m²/day'), 'WS2M': ('m/s', 'm/s'),
}


def read_native(path):
    text = path.read_text(encoding='utf-8-sig')
    header, separator, body = text.partition('-END HEADER-')
    if not separator or '-BEGIN HEADER-' not in header:
        raise ValueError('Missing NASA POWER native header')
    period = re.search(r'Dates \(month/day/year\): (\d{2})/(\d{2})/(\d{4}) through (\d{2})/(\d{2})/(\d{4}) in (LST|UTC)', header)
    if not period:
        raise ValueError('Missing declared dates and time standard')
    a, b, c, d, e, f, time_standard = period.groups()
    start, end = date(int(c), int(a), int(b)), date(int(f), int(d), int(e))
    if end < start:
        raise ValueError('Invalid POWER period')
    # Validate the location privately; it is never returned or exported.
    location = re.search(r'Location: latitude\s+([-\d.]+)\s+longitude\s+([-\d.]+)', header)
    if not location or not (-90 <= float(location[1]) <= 90 and -180 <= float(location[2]) <= 180):
        raise ValueError('Invalid private POWER location')
    for variable, (unit, _) in UNITS.items():
        line = re.search(r'^' + variable + r'\s+.*\(([^()]+)\)\s*$', header, re.M)
        if not line or line[1] != unit:
            raise ValueError(f'Incompatible or undeclared source unit: {variable}')
    reader = csv.DictReader(io.StringIO(body.strip()))
    if reader.fieldnames != ['YEAR', 'DOY', *UNITS]:
        raise ValueError('Unexpected POWER YEAR/DOY columns')
    daily = {}
    for row in reader:
        year, doy = int(row['YEAR']), int(row['DOY'])
        if not 1 <= doy <= (366 if calendar.isleap(year) else 365):
            raise ValueError('Invalid day of year')
        day = date(year, 1, 1) + timedelta(days=doy - 1)
        if day in daily or not start <= day <= end:
            raise ValueError('Duplicate or out-of-period POWER day')
        values = {}
        for variable in UNITS:
            try:
                value = float(row[variable])
            except (TypeError, ValueError):
                value = math.nan
            if (not math.isfinite(value) or value <= -999 or
                    (variable in ('PRECTOTCORR', 'RH2M', 'ALLSKY_SFC_SW_DWN', 'WS2M') and value < 0) or
                    (variable == 'RH2M' and value > 100)):
                value = None
            values[variable] = value
        temperatures = [values[k] for k in ('T2M_MIN', 'T2M', 'T2M_MAX')]
        if all(v is not None for v in temperatures) and temperatures != sorted(temperatures):
            raise ValueError('Inconsistent daily temperature range')
        daily[day] = values
    if not daily:
        raise ValueError('Empty POWER data')
    return daily, dict(start=start, end=end, timeStandard=time_standard)


def aggregate(daily, key):
    groups = defaultdict(list)
    for day, row in sorted(daily.items()):
        groups[key(day)].append(row)
    return {
        group: {variable: (sum(values) if variable == 'PRECTOTCORR' else statistics.mean(values))
                if len(values := [r[variable] for r in rows if r[variable] is not None]) == len(rows) else None
                for variable in UNITS}
        for group, rows in groups.items()
    }


def history(path):
    daily, meta = read_native(path)
    grouped = defaultdict(list)
    for day, row in daily.items():
        grouped[day.replace(day=1)].append(row)
    observations, sources = [], []
    for variable, (source_unit, target_unit) in UNITS.items():
        sid = 'power_' + variable
        factor = 1 / 3.6 if variable == 'ALLSKY_SFC_SW_DWN' else 1
        sources.append(dict(
            id=sid, institution='NASA POWER', product='NASA POWER Daily; referencia histórica de La Joya',
            variable=variable, unit=target_unit, sourceUnit=source_unit, conversionFactor=factor,
            temporalResolution='monthly (from complete daily records)',
            spatialResolution='Datos de cuadrícula MERRA-2/CERES; resolución dependiente del producto, sin resolución de parcela.',
            latitude=None, longitude=None, bounds=None, scope='regional_reference', region='La Joya, Arequipa',
            referenceFirstYear=meta['start'].year, referenceLastYear=meta['end'].year,
            timeStandard=meta['timeStandard'], quality='Integridad y resúmenes contrastados con el CSV; sin validación de campo.',
            state='historical_estimate', file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        ))
        month = meta['start'].replace(day=1)
        while month <= meta['end']:
            values = [r[variable] for r in grouped[month] if r[variable] is not None]
            expected = calendar.monthrange(month.year, month.month)[1]
            complete = len(values) == expected
            value = ((sum(values) if variable == 'PRECTOTCORR' else statistics.mean(values)) * factor) if complete else None
            observations.append(dict(source=sid, date=month.isoformat(), value=value,
                                     quality='complete' if complete else 'incomplete',
                                     samples=len(values), rejected=expected-len(values)))
            month = date(month.year + (month.month == 12), month.month % 12 + 1, 1)
    return dict(schemaVersion=1, region='La Joya, Arequipa', sources=sources, observations=observations,
                forecasts=[], enso=None, limitations=[
                    'Referencia histórica 2015–2025; no es pronóstico ni normal climática de 30 años.',
                    'Coordenadas del punto omitidas. Su aplicación a una parcela requiere selección explícita y confirmación local.',
                    'Humedad del aire distinta de humedad del suelo. Lluvia distinta de disponibilidad de riego.',
                ])


def verify_package(folder):
    source = folder/'NASA_POWER_ORIGINAL_PRIVADO.csv'
    daily, meta = read_native(source)
    monthly = aggregate(daily, lambda d: d.replace(day=1))
    annual = aggregate(daily, lambda d: d.year)
    climatology = {m: {v: statistics.mean(r[v] for day, r in monthly.items() if day.month == m)
                       for v in UNITS} for m in range(1, 13)}
    checks = 0

    def close(actual, supplied, tolerance, label):
        nonlocal checks
        if actual is None or not math.isclose(actual, float(supplied), rel_tol=0, abs_tol=tolerance):
            raise ValueError(f'Derived value differs from original CSV: {label}')
        checks += 1

    for filename, computed, key, parse in [
        ('PASO3_serie_mensual_2015_2025.csv', monthly, 'mes', date.fromisoformat),
        ('PASO3_serie_anual_2015_2025.csv', annual, 'anio', int),
        ('PASO3_climatologia_mensual.csv', climatology, 'mes', int),
    ]:
        with (folder/filename).open(encoding='utf-8-sig') as f:
            supplied = list(csv.DictReader(f))
        keys = [parse(r[key]) for r in supplied]
        if len(keys) != len(set(keys)) or set(keys) != set(computed):
            raise ValueError(f'Incomplete or duplicated derived table: {filename}')
        for row in supplied:
            for variable in UNITS:
                close(computed[parse(row[key])][variable], row[variable], .000051, filename+':'+variable)
    quality = json.loads((folder/'PASO2_calidad_y_unidades.json').read_text())
    expected_days = (meta['end'] - meta['start']).days + 1
    if quality['filas'] != len(daily) or quality['fechas_unicas'] != len(daily) or quality['fechas_ausentes'] != expected_days-len(daily) or quality['duplicados'] != 0:
        raise ValueError('Supplied quality counts differ from original CSV')
    with (folder/'PASO2_calidad_y_unidades.csv').open(encoding='utf-8-sig') as f:
        csv_quality = {r['variable']: r for r in csv.DictReader(f)}
    for variable in UNITS:
        valid = [r[variable] for r in daily.values() if r[variable] is not None]
        report = quality['variables'][variable]
        expected_unit = {'T2M': '°C', 'T2M_MAX': '°C', 'T2M_MIN': '°C',
                         'PRECTOTCORR': 'mm/día', 'RH2M': '%',
                         'ALLSKY_SFC_SW_DWN': 'MJ/m²/día', 'WS2M': 'm/s'}[variable]
        if report['unidad'] != expected_unit or csv_quality[variable]['unidad'] != expected_unit:
            raise ValueError('Supplied quality unit differs from original CSV')
        if report['validos'] != len(valid) or report['faltantes'] != len(daily)-len(valid):
            raise ValueError('Supplied quality variable counts differ')
        for key, value in [('minimo', min(valid)), ('maximo', max(valid)), ('promedio_diario', statistics.mean(valid))]:
            close(value, report[key], .000051, 'quality:'+variable+':'+key)
            close(value, csv_quality[variable][key], .000051, 'quality csv:'+variable+':'+key)
    for filename in ['PASO3_para_Harold_SmartCycle_PRIVADO.json', 'PASO3_para_Harold_SmartCycle_SIN_COORDENADAS.json']:
        data = json.loads((folder/filename).read_text())
        if filename.endswith('SIN_COORDENADAS.json') and any(k in data for k in ('latitude', 'longitude', 'latitud', 'longitud', 'coordenadas_privadas_no_publicar')):
            raise ValueError('Coordinate-free handoff contains private coordinates')
        expected_units = dict(T2M='C', T2M_MAX='C', T2M_MIN='C', PRECTOTCORR='mm/mes (acumulado mensual medio)', RH2M='%', ALLSKY_SFC_SW_DWN='MJ/m2/dia', WS2M='m/s')
        if data['unidades'] != expected_units:
            raise ValueError('Supplied SmartCycle unit differs from original CSV')
        rows = data['climatologia_mensual']
        if sorted(r['mes'] for r in rows) != list(range(1, 13)):
            raise ValueError('Invalid SmartCycle climatology months')
        for row in rows:
            for variable in UNITS:
                close(climatology[row['mes']][variable], row[variable], .000501, 'SmartCycle:'+variable)
    summary = json.loads((folder/'PASO3_resumen_climatico.json').read_text())
    if summary['dias'] != len(daily):
        raise ValueError('Summary day count differs from original CSV')
    for key, variable, function in [
        ('mes_mas_lluvioso', 'PRECTOTCORR', max), ('mes_menos_lluvioso', 'PRECTOTCORR', min),
        ('temperatura_mensual_mas_alta_mes', 'T2M', max), ('temperatura_mensual_mas_baja_mes', 'T2M', min),
    ]:
        if summary[key] != function(climatology, key=lambda m: climatology[m][variable]):
            raise ValueError('Summary extreme month differs from original CSV')
    summary_values = {
        'temperatura_media_c': statistics.mean(r['T2M'] for r in daily.values()),
        'precipitacion_media_anual_mm': statistics.mean(r['PRECTOTCORR'] for r in annual.values()),
        'humedad_relativa_media_pct': statistics.mean(r['RH2M'] for r in daily.values()),
        'radiacion_media_MJ_m2_dia': statistics.mean(r['ALLSKY_SFC_SW_DWN'] for r in daily.values()),
        'viento_medio_m_s': statistics.mean(r['WS2M'] for r in daily.values()),
    }
    for key, value in summary_values.items():
        close(value, summary[key], .000501, 'summary:'+key)
    return dict(period=f"{meta['start']} / {meta['end']}", timeStandard=meta['timeStandard'],
                days=len(daily), missingDays=expected_days-len(daily), duplicateDays=0,
                months=len(monthly), years=len(annual), variables=len(UNITS), comparedValues=checks,
                matchedWithinPublishedRounding=True, summary=summary_values,
                files={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.iterdir()) if p.is_file()},
                privacy='No private coordinates or original CSV contents exported.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input_directory', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT/'assets/data/power_history.json')
    parser.add_argument('--report', type=Path, default=ROOT/'build/power-review/validation.json')
    args = parser.parse_args()
    report = verify_package(args.input_directory)
    data = history(args.input_directory/'NASA_POWER_ORIGINAL_PRIVADO.csv')
    for path, value in [(args.output, data), (args.report, report)]:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)+'\n')
    print(f"Verified {report['days']} days and {report['comparedValues']} derived values; exported {len(data['observations'])} coordinate-free monthly observations.")


if __name__ == '__main__':
    main()
