"""Check baked art rules against source geometry and actual binary output."""
import importlib.util
import json
from pathlib import Path
import struct
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('blend_baker', ROOT/'tools/build_blend_preview.py')
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)
models = json.loads((ROOT/'assets/scenery/blend_primitives.json').read_text())
for name, source in models.items():
    parts = baker.expand(name, source)
    groups, adjacency = baker.contact_groups(name, parts)
    for group in groups:
        if len(group) < 2:
            continue
        chosen = [parts[i] for i in group]
        assert all(p['eligible'] for p in chosen)
        if name.startswith('person'):
            assert len({tuple(p['colour']) for p in chosen}) == 1
            assert len({p['bone'] for p in chosen}) == 1
        elif name=='hydrant':
            assert len({tuple(p['colour']) for p in chosen}) == 1
    if name.startswith('tree'):
        assert sum(p['eligible'] for p in parts)==16, 'Both green and golden trees blend their entire foliage'
        assert max(map(len,groups))==16
        for p in parts:
            if p['eligible']:
                assert np.max(np.abs(baker.sdf(p, np.asarray(p['raw'])))) < .001, 'Baked leaf must follow its authored rotated surface'
        assert not any(parts[i]['eligible'] is False and len(g) > 1 for g in groups for i in g)
    if name=='hydrant':
        assert sorted(map(len,groups))==[1,2], 'The red barrel and crossbar join, preserving the yellow cap'
    for level in [10,15,25,50,75,100]:
        assert (ROOT/f'assets/scenery/blend_{name}_{level:03}.res').exists()
    data = (ROOT/f'builds/blend/{name}_025.meshbin').read_bytes()
    count, indices = struct.unpack_from('<II', data)
    offset = 8
    for columns in [3, 3, 3, 2]:
        values = np.frombuffer(data, '<f4', count*columns, offset)
        assert np.isfinite(values).all()
        offset += count*columns*4
    offset += count*4*4  # Bone indices
    weights = np.frombuffer(data, '<f4', count*4, offset).reshape(-1, 4)
    assert np.allclose(weights.sum(1), 1)
    if name.startswith('person'):
        assert np.allclose(weights.max(1), 1), 'No cross-joint shirt stretching in gameplay'
    print(f'PASS: {name} respects touching, paint and joint boundaries')
# Identical paint alone cannot turn separated objects into a connecting blob.
a = dict(kind='ellipsoid', centre=[0, 0, 0], radii=[.5]*3, inverse=np.eye(3).tolist(), colour=[1, .7, .2], eligible=True, bone=0, raw=[[.5, 0, 0], [-.5, 0, 0], [0, .5, 0], [0, -.5, 0], [0, 0, .5], [0, 0, -.5]])
b = dict(a, centre=[1.1, 0, 0], raw=(np.asarray(a['raw'])+[1.1, 0, 0]).tolist())
assert len(baker.contact_groups('person', [a, b])[0]) == 2
b = dict(b, centre=[1, 0, 0], raw=(np.asarray(a['raw'])+[1, 0, 0]).tolist())
assert len(baker.contact_groups('person', [a, b])[0]) == 1
b = dict(b, colour=[.7, .3, .1])
assert len(baker.contact_groups('person', [a, b])[0]) == 2
print('PASS: Matching paint joins only touching geometry; different paint stays separate')
