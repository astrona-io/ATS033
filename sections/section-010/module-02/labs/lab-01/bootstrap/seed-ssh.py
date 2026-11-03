import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-lab-010-02-01"
NODE="astro-ats-033-lab-010-02-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-lab-010-02-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)
def put(path,content):
    with tempfile.TemporaryDirectory(prefix='training-node-') as temporary:
        source=Path(temporary)/'content';source.write_text(content)
        run('podman','cp',str(source),NODE+':'+path)
def user_exists(user):
    return subprocess.run(['podman','exec',NODE,'id',user],capture_output=True,timeout=30).returncode==0
MAIN = 'Include /etc/ssh/sshd_config.d/*.conf\nPort 22\nPermitRootLogin yes\nPubkeyAuthentication yes\nPasswordAuthentication no\nUsePAM yes\n'
node('mkdir','-p','/etc/ssh/sshd_config.d')
put('/etc/ssh/sshd_config',MAIN)
put('/etc/ssh/sshd_config.d/50-cloud-init.conf','PasswordAuthentication yes\n')
for user in ('opsadmin','olduser'):
    if not user_exists(user):
        node('useradd','--create-home','--shell','/bin/bash',user)
