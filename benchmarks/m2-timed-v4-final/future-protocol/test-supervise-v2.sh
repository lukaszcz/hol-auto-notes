#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided scratch directory required}
rm -rf -- "$scratch"
mkdir -p "$scratch"

run() {
  label=$1 expected=$2 timeout=$3 term=$4 post=$5
  shift 5
  rc=0
  python3 "$dir/supervise-v2.py" --timeout "$timeout" \
    --term-grace "$term" --post-kill-grace "$post" --poll 0.01 \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervisor case $label: expected $expected, got $rc" >&2
    exit 1
  }
}

run ordinary 0 2 1 1 /bin/sh -c 'exit 0'
run nonzero 7 2 1 1 /bin/sh -c 'exit 7'
run term_exit 143 2 1 1 /bin/sh -c 'kill -TERM $$'
run term 124 0.1 1 1 /bin/sh -c 'sleep 30'

python3 - "$scratch/resistant.py" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text('''import os, signal, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
if os.fork() == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    while True: time.sleep(1)
while True: time.sleep(1)
''')
PY
run kill 124 0.1 0.15 1 python3 "$scratch/resistant.py"

python3 - "$scratch/delayed.py" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text('''import os, signal, time
if os.fork() == 0:
    def delayed(sig, frame):
        time.sleep(.25)
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, delayed)
    while True: time.sleep(1)
while True: time.sleep(1)
''')
PY
run delayed 124 0.1 1 1 python3 "$scratch/delayed.py"

# A zero post-KILL budget is a real bounded-protocol failure: the stopped,
# TERM-resistant group is known present at KILL and no post-KILL wait is
# available to prove disappearance. The supervisor classifies it uncleared.
python3 - "$scratch/stopped.py" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text('''import os, signal, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
if os.fork() == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    os.kill(os.getpid(), signal.SIGSTOP)
os.kill(os.getpid(), signal.SIGSTOP)
while True: time.sleep(1)
''')
PY
run uncleared 125 0.1 0.05 0 python3 "$scratch/stopped.py"

python3 - "$scratch" <<'PY'
import json, pathlib, signal, sys
d = pathlib.Path(sys.argv[1])
def load(name): return json.loads((d / (name + '.json')).read_text())
assert load('ordinary')['classification'] == 'completed_exit_0'
assert load('nonzero')['classification'] == 'completed_exit_nonzero'
te = load('term_exit')
assert te['classification'] == 'completed_exit_nonzero'
assert te['leader_returncode'] == -signal.SIGTERM
assert load('term')['classification'] == 'timeout_term_group_cleared'
k = load('kill')
assert k['classification'] == 'timeout_kill_group_cleared'
assert k['kill_result'] == 'sent' and k['subreaper']
assert {r['role'] for r in k['reaps']} == {'leader', 'descendant'}
assert all(r['signal'] == signal.SIGKILL for r in k['reaps'])
q = load('delayed')
assert q['classification'] == 'timeout_term_group_cleared'
assert q['kill_result'] is None and q['elapsed_seconds'] >= .25
assert {r['role'] for r in q['reaps']} == {'leader', 'descendant'}
u = load('uncleared')
assert u['classification'] == 'failure_group_uncleared_after_kill'
assert not u['group_gone'] and u['kill_result'] == 'sent'
assert u['group_probes'][-1]['phase'] == 'post-kill'
PY

# Directly exercise the benign ESRCH race paths on an absent process group.
PYTHONDONTWRITEBYTECODE=1 python3 - "$dir/supervise-v2.py" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('supervise_v2', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
class Child: pid = 99999999
s = module.Session(Child(), 99999999, .01)
assert s.send(15) == 'ESRCH'
assert s.group_gone('esrch-test')
assert s.probes[-1]['error'] == 'ESRCH'
PY

echo 'supervise-v2 ordinary/nonzero/TERM/KILL/delay/ESRCH/uncleared: PASS'
