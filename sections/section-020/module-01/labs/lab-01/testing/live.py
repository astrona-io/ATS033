assert command([ENGINE,'exec',NODE,'id','-u','training-reader']).stdout.strip()!='0', 'Keep a non-root identity'
assert '0' not in command([ENGINE,'exec',NODE,'id','-G','training-reader']).stdout.split(), 'Do not grant the root group'
result=command([ENGINE,'exec',NODE,'runuser','-u','training-reader','--','cat','/var/lib/training-identity/private-report'],success=False)
assert result.returncode!=0 and 'Permission denied' in result.stderr, 'Preserve the private file boundary'
assert command([ENGINE,'exec',NODE,'stat','-c','%U:%G:%a','/var/lib/training-identity/public-report']).stdout.strip()=='root:training-readers:640', 'Preserve the scoped report ownership and mode'
assert command([ENGINE,'exec',NODE,'stat','-c','%U:%G:%a','/var/lib/training-identity/private-report']).stdout.strip()=='root:root:600', 'Keep private evidence root-only'
if wants('scoped-group-read'):
    assert command([ENGINE,'exec',NODE,'runuser','-u','training-reader','--','cat','/var/lib/training-identity/public-report'],success=False).stdout.strip()=='disposable-report', 'Let training-reader read public-report through training-readers'
    assert set(command([ENGINE,'exec',NODE,'id','-Gn','training-reader']).stdout.split())=={'training-reader','training-readers'}, 'Keep only the required account groups'
