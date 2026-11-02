status=kubectl('-n','starfleet','exec','restricted-reader','--','cat','/proc/1/status')
fields=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
assert fields['Seccomp'].strip()=='2' and fields['NoNewPrivs'].strip()=='1', 'Install an actual seccomp filter and no-new-privileges boundary'
