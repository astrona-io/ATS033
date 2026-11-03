status=kubectl('-n','starfleet','exec','bind-only','--','cat','/proc/1/status')
fields=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
assert fields['CapBnd'].strip()=='0000000000000400' and fields['NoNewPrivs'].strip()=='1' and fields['Seccomp'].strip()=='2', 'Keep only NET_BIND_SERVICE, block escalation and install the seccomp filter'
