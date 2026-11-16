#!/usr/bin/env python3
"""Prepare supplied NASA files offline. Never interpolate or invent missing observations."""
import argparse
import calendar
import csv
import hashlib
import io
import json
import math
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def number(raw, low=None, high=None):
    try:
        value = float(raw)
        if not math.isfinite(value) or value <= -999 or (low is not None and value < low) or (high is not None and value > high):
            return None
        return value
    except (TypeError, ValueError):
        return None


def read_rows(path, header):
    lines = path.read_text(encoding='utf-8-sig').splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith(header)), None)
    if start is None:
        raise ValueError(f'{path.name}: missing header {header}')
    metadata = {}
    for row in csv.reader(lines[:start]):
        if len(row) >= 2:
            metadata[row[0].strip().rstrip(':')] = row[1].strip()
    rows = [{k.strip(): v.strip() for k, v in row.items() if k is not None} for row in csv.DictReader(io.StringIO('\n'.join(lines[start:])))]
    return rows, metadata


def provenance(path, **kwargs):
    return dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), **kwargs)


def import_gpm(path):
    rows, meta = read_rows(path, 'time,')
    url = meta.get('URL to Reproduce Results', '')
    if 'GPM_3IMERGM_07_precipitation' not in url or 'mm%2Fmonth' not in url:
        raise ValueError('IMERG export must identify product and mm/month units')
    bbox = [float(v) for v in meta['User Bounding Box'].split(',')]
    data_bbox = [float(v) for v in meta['Data Bounding Box'].split(',')]
    source = provenance(path, id='gpm', institution='NASA', product='GPM_3IMERGM_07 Final Run (Giovanni)', variable='precipitation', unit='mm/month', temporalResolution='monthly', spatialResolution='0.1°; promedio del área exportada', bounds=bbox, dataBounds=data_bbox, latitude=(data_bbox[1]+data_bbox[3])/2, longitude=(data_bbox[0]+data_bbox[2])/2, quality='Estimación satelital; sin bandera de calidad en la exportación', state='historical_estimate', metadata=meta)
    observations, seen = [], set()
    for row in rows:
        day = date.fromisoformat(row['time'][:10])
        key = (day.year, day.month)
        if key in seen:
            raise ValueError('Duplicate GPM month')
        seen.add(key)
        value = number(row['mean_GPM_3IMERGM_07_precipitation'], 0)
        observations.append(dict(source='gpm', date=day.isoformat(), value=value, quality='not_provided' if value is not None else 'missing', samples=1 if value is not None else 0, rejected=0 if value is not None else 1))
    return source, observations


def import_smap(path):
    rows, _ = read_rows(path, 'Date,')
    coords = {(float(r['Latitude']), float(r['Longitude'])) for r in rows}
    if len(coords) != 1:
        raise ValueError('SMAP file must contain one location; split multiple locations first')
    lat, lon = coords.pop()
    if not -90 <= lat <= 90 or not -180 <= lon <= 180:
        raise ValueError('Invalid SMAP coordinates')
    source = provenance(path, id='smap', institution='NASA (según archivo suministrado)', product='SMAP; producto y versión no especificados', variable='surface_soil_moisture', unit='m³/m³', temporalResolution='irregular', spatialResolution='No documentada en el CSV', bounds=None, latitude=None, longitude=None, scope='regional_reference', region='La Joya, Arequipa', quality='No verificable: CSV sin banderas; uso solo contextual', state='historical_estimate')
    seen, observations = set(), []
    for row in rows:
        day = date.fromisoformat(row['Date'])
        if day in seen:
            raise ValueError('Duplicate SMAP date')
        seen.add(day)
        value = number(row['soil_moisture_m3_m3'], 0, 1)
        # No flag schema/product was supplied. Do not assume a bit mask.
        observations.append(dict(source='smap', date=day.isoformat(), value=value, quality='not_provided' if value is not None else 'invalid', samples=1 if value is not None else 0, rejected=0 if value is not None else 1))
    return source, observations


POWER_UNITS = {'T2M': '°C', 'T2M_MIN': '°C', 'T2M_MAX': '°C', 'RH2M': '%', 'PRECTOTCORR': 'mm/month', 'ALLSKY_SFC_SW_DWN': 'kWh/m²/day'}


def import_power(path):
    """Optional explicit daily POWER CSV, with declared metadata sidecar.

    Sidecar: latitude, longitude, units (per NASA variable), product,
    spatialResolution. Daily precipitation mm/day is summed only for complete
    months; temperatures/radiation/RH averaged only for complete months.
    """
    if '-BEGIN HEADER-' in path.read_text(encoding='utf-8-sig')[:200]:
        from import_power_package import history
        data = history(path)
        return data['sources'], data['observations']
    meta = json.loads(path.with_suffix('.metadata.json').read_text())
    rows, _ = read_rows(path, 'YEAR,MO,DY,')
    lat, lon = float(meta['latitude']), float(meta['longitude'])
    if not -90 <= lat <= 90 or not -180 <= lon <= 180:
        raise ValueError('Invalid POWER coordinates')
    sources, observations = [], []
    for variable, out_unit in POWER_UNITS.items():
        if not rows or variable not in rows[0]:
            continue
        expected = 'mm/day' if variable == 'PRECTOTCORR' else out_unit
        if meta['units'].get(variable) != expected:
            raise ValueError(f'POWER incompatible unit for {variable}; expected {expected}')
        sid = 'power_' + variable
        sources.append(provenance(path, id=sid, institution='NASA POWER', product=meta['product'], variable=variable, unit=out_unit, temporalResolution='monthly (from complete daily records)', spatialResolution=meta['spatialResolution'], bounds=None, latitude=lat, longitude=lon, quality='Validación de integridad y valores faltantes; no validación de campo', state='historical_estimate'))
        groups = defaultdict(dict)
        for row in rows:
            day = date(int(row['YEAR']), int(row['MO']), int(row['DY']))
            group = groups[(day.year, day.month)]
            if day.day in group:
                raise ValueError('Duplicate POWER day')
            low = 0 if variable in ('PRECTOTCORR', 'RH2M', 'ALLSKY_SFC_SW_DWN') else None
            high = 100 if variable == 'RH2M' else None
            group[day.day] = number(row[variable], low, high)
        for (year, month), days in sorted(groups.items()):
            values = [v for v in days.values() if v is not None]
            complete = len(values) == calendar.monthrange(year, month)[1]
            value = (sum(values) if variable == 'PRECTOTCORR' else sum(values)/len(values)) if complete else None
            observations.append(dict(source=sid, date=date(year, month, 1).isoformat(), value=value, quality='complete' if complete else 'incomplete', samples=len(values), rejected=calendar.monthrange(year, month)[1]-len(values)))
    return sources, observations


def build(gpm, smap, power=None):
    sources, observations = [], []
    for fn, path in [(import_gpm, gpm), (import_smap, smap)]:
        source, records = fn(path)
        sources.append(source)
        observations.extend(records)
    if power:
        ps, po = import_power(power)
        sources.extend(ps); observations.extend(po)
    return dict(schemaVersion=1, region='La Joya, Arequipa', sources=sources, observations=observations, forecasts=[], enso=None, limitations=['Serie histórica disponible; no es una normal climática de 30 años ni un pronóstico.', 'SMAP carece de producto/versión y banderas de calidad: no permite confirmar humedad radicular ni estrés de una parcela.', 'POWER no incluido en este recurso.' if not power else 'POWER agregado solo en meses completos.', 'Sin pronóstico estacional ni boletín ENSO regional suministrados.', 'SMAP: punto de consulta omitido por privacidad; usar únicamente como referencia seleccionada explícitamente.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gpm', type=Path, default=ROOT/'data/environment/GPMyIMERG.csv')
    parser.add_argument('--smap', type=Path, default=ROOT/'data/environment/SMAP.csv')
    parser.add_argument('--power', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT/'assets/data/environment.json')
    args = parser.parse_args()
    data = build(args.gpm, args.smap, args.power)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False)+'\n')
    print(f"Imported {len(data['observations'])} observations from {len(data['sources'])} sources")


if __name__ == '__main__':
    main()
