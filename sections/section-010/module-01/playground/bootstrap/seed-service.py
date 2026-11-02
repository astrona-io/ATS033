import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-playground-010-01"
NODE="astro-ats-033-playground-010-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-playground-010-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)
def put(path,content):
    with tempfile.TemporaryDirectory(prefix='training-node-') as temporary:
        source=Path(temporary)/'content';source.write_text(content)
        run('podman','cp',str(source),NODE+':'+path)

put('/etc/systemd/system/training-extra.service','[Unit]\nDescription=Disposable training service\n[Service]\nExecStart=/bin/sleep 3600\n[Install]\nWantedBy=multi-user.target\n')
node('systemctl','daemon-reload')
node('systemctl','enable','--now','training-extra.service')
