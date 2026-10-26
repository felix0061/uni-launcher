#!/usr/bin/env python3
"""Offline regression for district/city/province forecast matching."""
from pathlib import Path
import subprocess
import tempfile
from test_official_car import executable

root = Path(__file__).resolve().parents[1]
javac = executable(None, 'javac')
java = executable(str(javac.parent / 'java'), 'java')
with tempfile.TemporaryDirectory(prefix='uni-weather-') as directory:
    subprocess.run([str(javac), '--release', '8', '-encoding', 'UTF-8', '-d', directory,
                    str(root / 'android/src/xyz/i4o/uni/launcher/integration/WeatherLocationResolver.java'),
                    str(root / 'android/test-weather/WeatherLocationResolverTest.java')], check=True)
    subprocess.run([str(java), '-cp', directory, 'WeatherLocationResolverTest'], check=True)
