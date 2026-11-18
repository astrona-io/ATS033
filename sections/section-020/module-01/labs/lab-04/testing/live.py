RULE = '-w /etc/sudoers.d -p wa -k sudoers-change'
RULE_FILE = '/etc/audit/rules.d/40-sudoers.rules'
MAIN_RULE = '-w /etc/sudoers -p wa -k sudoers-main'
MAIN_RULE_FILE = '/etc/audit/rules.d/30-sudoers-main.rules'
ONCALL_FILE = '/etc/sudoers.d/40-oncall'
ONCALL_COMMAND = '(root) NOPASSWD: /usr/bin/journalctl --unit kubelet'


def on_node(*args, success=True):
    return node_exec(NODE, *args, success=success)


# auditctl -l prints the rules the kernel uses now, in its own normal form.
loaded = [line.strip() for line in on_node('auditctl', '-l').stdout.splitlines()]

# Guard for every outcome: the existing persistent rule on /etc/sudoers stays
# in its file and in the kernel.
assert on_node('grep', '-qxF', '-e', MAIN_RULE, MAIN_RULE_FILE, success=False).returncode == 0, 'Keep ' + MAIN_RULE_FILE + ' and its rule'
assert MAIN_RULE in loaded, 'Keep the loaded rule ' + MAIN_RULE

if wants('watch-persistent'):
    result = on_node('cat', RULE_FILE, success=False)
    assert result.returncode == 0, 'Create ' + RULE_FILE
    assert any('/etc/sudoers.d' in line and 'sudoers-change' in line for line in result.stdout.splitlines()), \
        RULE_FILE + ' must hold a watch rule on /etc/sudoers.d with the key sudoers-change'
    # augenrules --check compares rules.d with the generated /etc/audit/audit.rules,
    # the file auditd loads at every start.
    result = on_node('augenrules', '--check', success=False)
    assert 'No change' in result.stdout + result.stderr, 'Run augenrules --load, so that /etc/audit/audit.rules is built from rules.d'
if wants('watch-loaded'):
    assert RULE in loaded, 'auditctl -l must list ' + RULE
if wants('oncall-rule-added'):
    result = on_node('stat', '-c', '%U:%G:%a', ONCALL_FILE, success=False)
    assert result.returncode == 0, 'Create ' + ONCALL_FILE
    assert result.stdout.strip() == 'root:root:440', ONCALL_FILE + ' must be owned by root:root with mode 440'
    assert on_node('visudo', '-c', success=False).returncode == 0, 'The sudoers files must pass visudo -c'
    # sudo itself answers which commands the account may run.
    assert ONCALL_COMMAND in on_node('sudo', '-l', '-U', 'oncall').stdout, \
        'sudo -l -U oncall must list ' + ONCALL_COMMAND
if wants('change-recorded'):
    # --input-logs: read the audit log, not standard input.
    result = on_node('ausearch', '--input-logs', '-k', 'sudoers-change', '-f', ONCALL_FILE, success=False)
    assert result.returncode == 0, \
        'The audit log has no sudoers-change record for ' + ONCALL_FILE + '; load the watch rule before you write the file'
