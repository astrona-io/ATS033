import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-playground-020-01"
NODE="astro-ats-033-playground-020-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-playground-020-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)
def put(path,content):
    with tempfile.TemporaryDirectory(prefix='training-node-') as temporary:
        source=Path(temporary)/'content';source.write_text(content)
        run('podman','cp',str(source),NODE+':'+path)

node('groupadd','training-readers')
node('useradd','--user-group','--create-home','--shell','/bin/sh','training-reader')
node('mkdir','-p','/var/lib/training-identity')
put('/var/lib/training-identity/public-report','disposable-report\n')
put('/var/lib/training-identity/private-report','private-disposable-report\n')
node('chown','root:training-readers','/var/lib/training-identity/public-report')
node('chmod','0640','/var/lib/training-identity/public-report')
node('chown','root:root','/var/lib/training-identity/private-report')
node('chmod','0600','/var/lib/training-identity/private-report')

