import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-playground-010-02"
NODE="astro-ats-033-playground-010-02-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-playground-010-02', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)
def put(path,content):
    with tempfile.TemporaryDirectory(prefix='training-node-') as temporary:
        source=Path(temporary)/'content';source.write_text(content)
        run('podman','cp',str(source),NODE+':'+path)
def user_exists(user):
    return subprocess.run(['podman','exec',NODE,'id',user],capture_output=True,timeout=30).returncode==0

node('sed','-i','s/^PermitRootLogin .*/PermitRootLogin no/','/etc/ssh/sshd_config')
node('sed','-i','s/^PasswordAuthentication .*/PasswordAuthentication no/','/etc/ssh/sshd_config.d/50-cloud-init.conf')
if 'AllowUsers' not in node('cat','/etc/ssh/sshd_config'):
    node('sh','-c',"printf 'AllowUsers opsadmin\\n' >> /etc/ssh/sshd_config")
node('usermod','--shell','/usr/sbin/nologin','--lock','olduser')
