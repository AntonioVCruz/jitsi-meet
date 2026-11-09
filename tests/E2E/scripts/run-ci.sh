#!/usr/bin/env bash

set -euo pipefail
: "${TESTRIGOR_API_KEY:?Provide the suite CI token through the environment}"
: "${TESTRIGOR_SUITE_ID:?Provide a dedicated suite ID}"
: "${E2E_BRANCH:?Provide the source branch}"
: "${E2E_COMMIT:?Provide the source commit}"

mkdir -p tests/E2E/.run
[[ "$(git rev-parse HEAD)" == "$E2E_COMMIT" ]] || { echo 'Checkout does not match the requested commit.' >&2; exit 2; }
python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import subprocess

root = Path('tests/E2E')
paths = [*root.glob('test-cases/*.yaml'), *root.glob('rules/*.txt'), root / 'variables.json',
         root / 'settings.json', root / 'config/web-config.js', root / 'scripts/run-ci.sh',
         root / 'scripts/install-jitsi-meet.sh', root / 'docker/Dockerfile']
manifest = {
    'applicationCommit': os.environ['E2E_COMMIT'],
    'harnessCommit': os.environ['E2E_COMMIT'],
    'branch': os.environ['E2E_BRANCH'],
    'backendRelease': 'stable-11248-3',
    'mediaVerified': False,
    'images': {service: subprocess.check_output(
        ['docker', 'inspect', '--format', '{{.Image}}',
         os.environ.get('JITSI_E2E_PROJECT', 'jitsi-e2e') + '-' + service + '-1'], text=True).strip()
        for service in ('web', 'prosody', 'jicofo', 'jvb')},
    'fileHashes': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
}
(root / '.run/manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
PY

# Keep the CLI synchronous so its real exit status determines this job's result.
testrigor test-suite run "$TESTRIGOR_SUITE_ID" \
    --localhost --url https://localhost:18443/ \
    --test-cases-path 'tests/E2E/test-cases/*.yaml' \
    --rules-path 'tests/E2E/rules/*.txt' \
    --variables-path tests/E2E/variables.json \
    --settings-path tests/E2E/settings.json \
    --labels jitsi-e2e \
    --branch "$E2E_BRANCH" --commit "$E2E_COMMIT" \
    --junit-report-save-path tests/E2E/.run/junit.xml
