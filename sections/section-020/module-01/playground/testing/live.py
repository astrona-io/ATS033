node=NODE
assert command([ENGINE,'exec',node,'id','-u','training-reader']).stdout.strip()!='0', 'Keep a non-root identity'
assert '0' not in command([ENGINE,'exec',node,'id','-G','training-reader']).stdout.split(), 'Do not grant the root group'
assert command([ENGINE,'exec',node,'runuser','-u','training-reader','--','cat','/var/lib/training-identity/public-report']).stdout.strip()=='disposable-report', 'Grant only the required read'
result=command([ENGINE,'exec',node,'runuser','-u','training-reader','--','cat','/var/lib/training-identity/private-report'],success=False)
assert result.returncode!=0 and 'Permission denied' in result.stderr, 'Preserve the private file boundary'
assert set(command([ENGINE,'exec',node,'id','-Gn','training-reader']).stdout.split())=={'training-reader','training-readers'}, 'Keep only the required account groups'
assert command([ENGINE,'exec',node,'stat','-c','%U:%G:%a','/var/lib/training-identity/public-report']).stdout.strip()=='root:training-readers:640', 'Preserve the scoped report ownership and mode'
assert command([ENGINE,'exec',node,'stat','-c','%U:%G:%a','/var/lib/training-identity/private-report']).stdout.strip()=='root:root:600', 'Keep private evidence root-only'
