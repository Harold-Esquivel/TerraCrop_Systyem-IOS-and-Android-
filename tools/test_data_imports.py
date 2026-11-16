"""Run with python3 -m unittest discover -s tools -p 'test_*.py'."""
import json
import tempfile
import unittest
from pathlib import Path
from import_agronomy import ROOT, import_data, read_workbook
from import_agronomy_json import months
from import_environment import build, import_gpm, import_smap, import_power


class DataImportsTest(unittest.TestCase):
    def test_excel_full_roundtrip_and_units(self):
        data = import_data(ROOT/'data/agronomy/TerraCrop_base_para_app.xlsx')
        # The workbook remains importable; the active asset now uses JSON 2.1.
        self.assertEqual(len(data['rawTables']), 8)
        self.assertEqual(sum(len(r['cells']) for t in data['rawTables'] for r in t['rows']), 2102)
        self.assertEqual(len(data['formulaCells']), 113)
        self.assertEqual(len(data['crops']), 13)
        self.assertEqual(len(data['compatibility']), 169)
        self.assertEqual(len({(r['previousId'], r['nextId']) for r in data['compatibility']}), 169)
        self.assertEqual(len(data['sequences']), 3)
        self.assertEqual(len(data['sequenceDetails']), 12)
        self.assertEqual(len(data['microorganisms']), 9)
        self.assertEqual(len(data['soilRules']), 13)
        alfalfa = next(c for c in data['crops'] if c['id']=='C004')
        self.assertIsNone(alfalfa['periodMin'])
        self.assertIn('año', alfalfa['waterUnit'])
        for c in data['crops']:
            self.assertLessEqual(c['waterMin'], c['waterMax'])
        self.assertIn('P2O5', data['source']['nutrientUnit'])

    def test_json_full_roundtrip_and_supplemental_tables(self):
        path = ROOT/'data/agronomy/TerraCrop_base_para_app_v2.json'
        data = import_data(path)
        self.assertEqual(data, json.loads((ROOT/'assets/data/agronomy.json').read_text()))
        self.assertEqual(data['rawDocument'], json.loads(path.read_text()))
        self.assertEqual(len(data['crops']), 14)
        self.assertEqual(len(data['compatibility']), 196)
        self.assertEqual(len(data['sources']), 40)
        self.assertEqual(len(data['calendars']), 14)
        self.assertEqual(data['crops'][0]['extractionN'], 141)
        self.assertEqual(data['crops'][0]['nMin'], 150)

    def test_json_rejects_corrupt_relations_duplicates_and_numbers(self):
        raw = json.loads((ROOT/'data/agronomy/TerraCrop_base_para_app_v2.json').read_text())
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)/'input.json'
            for mutate in [
                lambda d: d['compatibilidad'].pop(),
                lambda d: d['compatibilidad'].__setitem__(1, d['compatibilidad'][0]),
                lambda d: d['alertas_preventivas'][0].__setitem__('advertencias_ids', 'W99'),
                lambda d: d['cultivos'][0].__setitem__('demanda_hidrica_min', float('nan')),
                lambda d: d['calendario_la_joya'][0].__setitem__('meses_de_siembra_trasplante_112', '13'),
            ]:
                bad = json.loads(json.dumps(raw))
                mutate(bad)
                p.write_text(json.dumps(bad))
                with self.assertRaises(ValueError): import_data(p)
            p.write_text('{"meta": {}, "meta": {}}')
            with self.assertRaises(ValueError): import_data(p)

    def test_unknown_months_are_not_invented(self):
        self.assertEqual(months('Por confirmar'), [])
        self.assertEqual(months('Cortes todo el año'), [])
        self.assertEqual(months('12;1'), [12, 1])

    def test_environment_reproducible(self):
        asset = json.loads((ROOT/'assets/data/environment.json').read_text())
        smap_path = ROOT/'data/environment/SMAP.csv'
        if smap_path.exists():
            self.assertEqual(build(ROOT/'data/environment/GPMyIMERG.csv', smap_path), asset)
        else:
            # The repository contains the SMAP cache, but not its original CSV.
            # Verify every reproducible source without fabricating that file.
            source, rows = import_gpm(ROOT/'data/environment/GPMyIMERG.csv')
            self.assertEqual(source, next(s for s in asset['sources'] if s['id'] == 'gpm'))
            self.assertEqual(rows, [r for r in asset['observations'] if r['source'] == 'gpm'])
        self.assertEqual(len(asset['observations']), 1539)
        self.assertEqual(asset['forecasts'], [])
        self.assertIsNone(asset['enso'])

    def test_gpm_export_is_already_mm_per_month(self):
        source, rows = import_gpm(ROOT/'data/environment/GPMyIMERG.csv')
        self.assertEqual(len(rows), 129)
        self.assertEqual(source['unit'], 'mm/month')
        self.assertAlmostEqual(rows[0]['value'], 5.95200014)
        self.assertEqual(rows[-1]['date'], '2025-09-01')
        self.assertNotEqual(source['bounds'], source['dataBounds'])

    def test_smap_missing_quality_not_invented(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)/'SMAP.csv'
            p.write_text('Date,Latitude,Longitude,soil_moisture_m3_m3\n2020-01-01,-16.75,-71.87,0.0601342\n')
            source, rows = import_smap(p)
        self.assertEqual(len(rows), 1)
        self.assertEqual(source['unit'], 'm³/m³')
        self.assertEqual(rows[0]['value'], .0601342)
        self.assertEqual({r['quality'] for r in rows}, {'not_provided'})
        self.assertIn('No documentada', source['spatialResolution'])

    def test_smap_rejects_missing_invalid_and_duplicate(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'SMAP.csv'
            p.write_text('Date,Latitude,Longitude,soil_moisture_m3_m3\n2020-01-01,-16.75,-71.87,-9999\n2020-01-02,-16.75,-71.87,NaN\n2020-01-03,-16.75,-71.87,1.2\n')
            _, rows=import_smap(p)
            self.assertTrue(all(r['value'] is None for r in rows))
            p.write_text(p.read_text()+'2020-01-03,-16.75,-71.87,.2\n')
            with self.assertRaises(ValueError): import_smap(p)

    def test_optional_power_complete_and_incomplete_months(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'POWER.csv'
            p.with_suffix('.metadata.json').write_text(json.dumps(dict(latitude=-16.75,longitude=-71.87,product='NASA POWER daily',spatialResolution='specified by source',units={'T2M':'°C','PRECTOTCORR':'mm/day'})))
            p.write_text('YEAR,MO,DY,T2M,PRECTOTCORR\n'+''.join(f'2020,2,{d},20,1\n' for d in range(1,30))+'2020,3,1,-999,1\n')
            sources, rows=import_power(p)
            self.assertEqual(len(sources), 2)
            self.assertEqual(next(r['value'] for r in rows if r['source']=='power_PRECTOTCORR' and r['date']=='2020-02-01'), 29)
            self.assertEqual(next(r['value'] for r in rows if r['source']=='power_T2M' and r['date']=='2020-02-01'), 20)
            self.assertTrue(all(r['value'] is None for r in rows if r['date']=='2020-03-01'))
            metadata=json.loads(p.with_suffix('.metadata.json').read_text());metadata['units']['PRECTOTCORR']='mm/hour'
            p.with_suffix('.metadata.json').write_text(json.dumps(metadata))
            with self.assertRaises(ValueError): import_power(p)


if __name__ == '__main__': unittest.main()
