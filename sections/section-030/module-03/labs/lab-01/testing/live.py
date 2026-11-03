import re
kubelet_config=command(['podman','exec','astro-ats-033-lab-030-03-01-worker','cat','/var/lib/kubelet/config.yaml']).stdout
assert re.search(r'^authentication:\n  anonymous:\n    enabled: false$',kubelet_config,re.M),'The kubelet must reject anonymous requests'
assert re.search(r'^authorization:\n  mode: Webhook$',kubelet_config,re.M),'The kubelet authorization mode must be Webhook'
behavior_check({'args':['podman','exec','astro-ats-033-lab-030-03-01-worker','curl','-sk','-o','/dev/null','-w','%{http_code}','https://127.0.0.1:10250/pods'],'equals':'401'})
