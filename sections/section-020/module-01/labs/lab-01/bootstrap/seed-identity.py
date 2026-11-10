import json,os,subprocess,sys,tempfile
from pathlib import Path
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-033-lab-020-01-01'
CLUSTER = os.environ.get('ASTRONA_KIND_CLUSTER') or 'astro-ats-033-lab-020-01-01'
ENGINE = os.environ.get('ASTRONA_CONTAINER_ENGINE') or 'podman'
NODE = CLUSTER + '-control-plane'
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
if run('kubectl', 'config', 'current-context') != CONTEXT:
    sys.exit('Refusing to operate on another Kubernetes context')
if run(ENGINE, 'inspect', NODE, '--format', '{{index .Config.Labels "io.x-k8s.kind.cluster"}}') != CLUSTER:
    sys.exit('Refusing an unrelated node container')
def node(*args):return run(ENGINE,'exec',NODE,*args)
def put(path,content):
    with tempfile.TemporaryDirectory(prefix='training-node-') as temporary:
        source=Path(temporary)/'content';source.write_text(content)
        run(ENGINE,'cp',str(source),NODE+':'+path)

node('groupadd','training-readers')
node('useradd','--user-group','--create-home','--shell','/bin/sh','training-reader')
node('mkdir','-p','/var/lib/training-identity')
put('/var/lib/training-identity/public-report','disposable-report\n')
put('/var/lib/training-identity/private-report','private-disposable-report\n')
node('chown','root:training-readers','/var/lib/training-identity/public-report')
node('chmod','0640','/var/lib/training-identity/public-report')
node('chown','root:root','/var/lib/training-identity/private-report')
node('chmod','0600','/var/lib/training-identity/private-report')

