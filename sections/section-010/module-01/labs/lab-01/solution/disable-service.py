import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-lab-010-01-01"
NODE="astro-ats-033-lab-010-01-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-lab-010-01-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

node('systemctl','disable','--now','training-extra.service')
