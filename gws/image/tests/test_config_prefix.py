"""Exercise GWS input selection without cloud services or tenant credentials."""

import json
from pathlib import Path
import runpy
import subprocess
import sys
from types import ModuleType, SimpleNamespace
from unittest.mock import Mock

import pytest


MAIN = Path(__file__).resolve().parents[1] / 'main.py'


@pytest.mark.parametrize('run_type', ['scheduled', 'adhoc'])
@pytest.mark.parametrize('extra_suffix', [None, '-archive/ignored.yaml', '.yaml', ''])
def test_run_uses_only_its_input_directory(tmp_path, monkeypatch, run_type, extra_suffix):
    """Neighboring prefixes cannot abort a run or supply its configurations."""
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv('RUN_TYPE', run_type)
    monkeypatch.setenv('INPUT_BUCKET', 'test-input')
    monkeypatch.setenv('OUTPUT_BUCKETS', '["test-output-one", "test-output-two"]')
    monkeypatch.setenv('OUTPUT_ALL_FILES', 'false')

    downloads = []

    def make_blob(name):
        def download(filename):
            Path(filename).write_text('synthetic configuration', encoding='utf-8')
            downloads.append(name)
        return SimpleNamespace(name=name, download_to_filename=download)

    names = [f'{run_type}/', f'{run_type}/example.org.yaml']
    if extra_suffix is not None:
        names.append(f'{run_type}{extra_suffix}')
    blobs = [make_blob(name) for name in names]
    storage_client = Mock()
    storage_client.list_blobs.side_effect = lambda bucket, prefix: (
        blob for blob in blobs if blob.name.startswith(prefix)
    )
    uploaded = []

    def output_bucket(bucket_name):
        def output_blob(name):
            def upload(filename):
                uploaded.append((bucket_name, name, json.loads(Path(filename).read_text())))
            return SimpleNamespace(id=name, upload_from_filename=upload)
        return SimpleNamespace(blob=output_blob)

    storage_client.bucket.side_effect = output_bucket
    log_client = Mock()

    # Substitute only external SDK modules; execute the complete real entrypoint.
    google = ModuleType('google')
    google.__path__ = []
    cloud = ModuleType('google.cloud')
    cloud.__path__ = []
    storage = ModuleType('google.cloud.storage')
    storage.Client = Mock(return_value=storage_client)
    cloud_logging = ModuleType('google.cloud.logging')
    cloud_logging.Client = Mock(return_value=log_client)
    goggles = ModuleType('scubagoggles')
    goggles.__version__ = 'test'
    google.cloud = cloud
    cloud.storage = storage
    cloud.logging = cloud_logging
    for name, module in {
        'google': google,
        'google.cloud': cloud,
        'google.cloud.storage': storage,
        'google.cloud.logging': cloud_logging,
        'scubagoggles': goggles,
    }.items():
        monkeypatch.setitem(sys.modules, name, module)

    def assess(command, **kwargs):
        assert kwargs == {'check': True, 'capture_output': True, 'text': True}
        assert command == [
            'scubagoggles', 'gws', '--outputpath', 'output/example.org',
            '--config', f'input/{run_type}/example.org.yaml',
            '--usemetadataserverauth', '--quiet',
        ]
        report = Path('output/example.org/report/ScubaResults-example.json')
        report.parent.mkdir(parents=True)
        report.write_text(json.dumps({'MetaData': {'Fixture': 'preserved'}}))
        return subprocess.CompletedProcess(command, 0, stdout='', stderr='')

    runner = Mock(side_effect=assess)
    monkeypatch.setattr(subprocess, 'run', runner)
    runpy.run_path(str(MAIN), run_name='__main__')

    assert downloads == [f'{run_type}/example.org.yaml']
    runner.assert_called_once()
    assert len(uploaded) == 2
    assert {entry[0] for entry in uploaded} == {'test-output-one', 'test-output-two'}
    assert all(entry[2]['MetaData'] == {
        'Fixture': 'preserved', 'RunType': run_type,
    } for entry in uploaded)
    assert not Path(f'input/{run_type}-archive').exists()
    log_client.close.assert_called_once()
