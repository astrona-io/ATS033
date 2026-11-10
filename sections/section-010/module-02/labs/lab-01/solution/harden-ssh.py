import json,os,subprocess,sys,tempfile
from pathlib import Path
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-033-lab-010-02-01'
CLUSTER = os.environ.get('ASTRONA_KIND_CLUSTER') or 'astro-ats-033-lab-010-02-01'
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
def user_exists(user):
    return subprocess.run([ENGINE,'exec',NODE,'id',user],capture_output=True,timeout=30).returncode==0

node('sed','-i','s/^PermitRootLogin .*/PermitRootLogin no/','/etc/ssh/sshd_config')
node('sed','-i','s/^PasswordAuthentication .*/PasswordAuthentication no/','/etc/ssh/sshd_config.d/50-cloud-init.conf')
if 'AllowUsers' not in node('cat','/etc/ssh/sshd_config'):
    node('sh','-c',"printf 'AllowUsers opsadmin\\n' >> /etc/ssh/sshd_config")
node('usermod','--shell','/usr/sbin/nologin','--lock','olduser')
