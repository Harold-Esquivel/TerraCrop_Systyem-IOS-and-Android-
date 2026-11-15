"""Run with python3 -m unittest discover -s tools -p 'test_*.py'."""
import json
import tempfile
import unittest
from pathlib import Path
from import_agronomy import ROOT, import_data, read_workbook
from import_environment import build, import_gpm, import_smap, import_power


class DataImportsTest(unittest.TestCase):
    def test_excel_full_roundtrip_and_units(self):
        data = import_data(ROOT/'data/agronomy/TerraCrop_base_para_app.xlsx')
        asset = json.loads((ROOT/'assets/data/agronomy.json').read_text())
        self.assertEqual(data, asset)
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

    def test_environment_reproducible(self):
        data = build(ROOT/'data/environment/GPMyIMERG.csv', ROOT/'data/environment/SMAP.csv')
        self.assertEqual(data, json.loads((ROOT/'assets/data/environment.json').read_text()))
        self.assertEqual(len(data['observations']), 1539)
        self.assertEqual(data['forecasts'], [])
        self.assertIsNone(data['enso'])

    def test_gpm_export_is_already_mm_per_month(self):
        source, rows = import_gpm(ROOT/'data/environment/GPMyIMERG.csv')
        self.assertEqual(len(rows), 129)
        self.assertEqual(source['unit'], 'mm/month')
        self.assertAlmostEqual(rows[0]['value'], 5.95200014)
        self.assertEqual(rows[-1]['date'], '2025-09-01')
        self.assertNotEqual(source['bounds'], source['dataBounds'])

    def test_smap_missing_quality_not_invented(self):
        source, rows = import_smap(ROOT/'data/environment/SMAP.csv')
        self.assertEqual(len(rows), 1410)
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
