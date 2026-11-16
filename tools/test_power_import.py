"""POWER integration tests use synthetic private originals, never real coordinates."""
import json
from pathlib import Path
import tempfile
import unittest

from import_environment import import_power
from import_power_package import ROOT, history, read_native


HEADER = '''-BEGIN HEADER-
NASA/POWER Source Native Resolution Daily Data
Dates (month/day/year): 02/01/2020 through 02/29/2020 in LST
Location: latitude  -10.1234567   longitude -70.7654321
parameter(s):
T2M MERRA-2 Temperature at 2 Meters (C)
T2M_MAX MERRA-2 Temperature at 2 Meters Maximum (C)
T2M_MIN MERRA-2 Temperature at 2 Meters Minimum (C)
PRECTOTCORR MERRA-2 Precipitation Corrected (mm/day)
RH2M MERRA-2 Relative Humidity at 2 Meters (%)
ALLSKY_SFC_SW_DWN CERES SYN1deg All Sky Surface Shortwave Downward Irradiance (MJ/m^2/day)
WS2M MERRA-2 Wind Speed at 2 Meters (m/s)
-END HEADER-
YEAR,DOY,T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,RH2M,ALLSKY_SFC_SW_DWN,WS2M
'''


class PowerImportTest(unittest.TestCase):
    def source(self, folder, mutate=lambda text: text):
        path = Path(folder)/'POWER.csv'
        path.write_text(mutate(HEADER+''.join(f'2020,{d},20,25,15,1,75,18,2\n' for d in range(32, 61))))
        return path

    def test_native_doy_leap_year_units_and_privacy(self):
        with tempfile.TemporaryDirectory() as folder:
            path = self.source(folder)
            daily, meta = read_native(path)
            self.assertEqual(len(daily), 29)
            self.assertEqual(meta['timeStandard'], 'LST')
            data = history(path)
            sources, rows = import_power(path)
            self.assertEqual(sources, data['sources'])
            self.assertEqual(rows, data['observations'])
            self.assertEqual(next(r['value'] for r in rows if r['source']=='power_PRECTOTCORR'), 29)
            self.assertEqual(next(r['value'] for r in rows if r['source']=='power_ALLSKY_SFC_SW_DWN'), 5)
            self.assertEqual(next(r['value'] for r in rows if r['source']=='power_WS2M'), 2)
            self.assertTrue(all(s['latitude'] is None and s['longitude'] is None and s['scope']=='regional_reference' for s in sources))
            self.assertNotIn('-10.1234567', json.dumps(data))
            self.assertNotIn('-70.7654321', json.dumps(data))

    def test_missing_day_invalid_value_and_missing_month_not_filled(self):
        with tempfile.TemporaryDirectory() as folder:
            path = self.source(folder, lambda t: t.replace('2020,40,20,25,15,1,75,18,2\n',''))
            self.assertTrue(all(r['value'] is None and r['rejected']==1 for r in history(path)['observations']))
            path = self.source(folder, lambda t: t.replace('2020,40,20,25,15,1,75,18,2', '2020,40,20,25,15,1,175,18,2'))
            rows = history(path)['observations']
            self.assertIsNone(next(r['value'] for r in rows if r['source']=='power_RH2M'))
            self.assertEqual(next(r['value'] for r in rows if r['source']=='power_PRECTOTCORR'), 29)
            path = self.source(folder, lambda t: t.replace('02/29/2020', '03/31/2020'))
            march = [r for r in history(path)['observations'] if r['date']=='2020-03-01']
            self.assertEqual(len(march), 7)
            self.assertTrue(all(r['value'] is None and r['samples']==0 and r['rejected']==31 for r in march))

    def test_duplicate_doy_units_and_temperatures_rejected(self):
        for mutate in [
            lambda t: t+'2020,32,20,25,15,1,75,18,2\n',
            lambda t: t.replace('2020,32,', '2020,367,'),
            lambda t: t.replace('(mm/day)', '(mm/hour)'),
            lambda t: t.replace('20,25,15', '20,19,15'),
        ]:
            with tempfile.TemporaryDirectory() as folder:
                with self.assertRaises(ValueError): read_native(self.source(folder, mutate))

    def test_bundled_history_matches_safe_handoff_and_radiation_conversion(self):
        asset = json.loads((ROOT/'assets/data/power_history.json').read_text())
        handoff = json.loads((ROOT/'data/environment/POWER_climatologia_sin_coordenadas.json').read_text())
        self.assertEqual(len(asset['sources']), 7)
        self.assertEqual(len(asset['observations']), 924)
        self.assertTrue(all(r['quality']=='complete' for r in asset['observations']))
        for reference in handoff['climatologia_mensual']:
            for variable in handoff['unidades']:
                rows = [r for r in asset['observations'] if r['source']=='power_'+variable and int(r['date'][5:7])==reference['mes']]
                value = sum(r['value'] for r in rows)/len(rows)
                if variable=='ALLSKY_SFC_SW_DWN': value *= 3.6
                self.assertAlmostEqual(value, reference[variable], delta=.000501)
        rain = sum(r['value'] for r in asset['observations'] if r['source']=='power_PRECTOTCORR')/11
        self.assertAlmostEqual(rain, 83.5236363636, places=6)
        for source in asset['sources']:
            self.assertIsNone(source['latitude'])
            self.assertIsNone(source['longitude'])
            self.assertIsNone(source['bounds'])


if __name__ == '__main__': unittest.main()
