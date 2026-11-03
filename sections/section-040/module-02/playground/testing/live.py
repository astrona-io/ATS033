status=kubectl('-n','starfleet','exec','no-rename','--','cat','/proc/1/status')
fields=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
assert fields['Seccomp'].strip()=='2', 'Install an actual seccomp filter'
