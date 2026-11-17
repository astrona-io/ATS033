#!/usr/bin/env python3
"""Check registration, module order and the exam-ready lab layout."""
from pathlib import Path
import json
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[2]
SHARED = Path(__file__).resolve().parent / 'lab-files'
# Files every lab carries unchanged; the key is the path inside the lab.
SHARED_FILES = {
    'testing/check.py': 'check.py',
    'testing/verify-start.sh': 'verify-start.sh',
    'testing/wait-solved.sh': 'wait-solved.sh',
}
LIFECYCLE = ['testing/verify-start.sh', 'solution/apply.sh', 'testing/wait-solved.sh']
MAX_MINUTES = 20
# The exam-style question shape: these headings, in this order.
QUESTION_PARTS = ('Solve this question on: `terminal`', '## Tasks', '## Constraints', '## How the answer is checked')
DESTROY = '<!-- astrona:playground:destroy -->'


def lab_suffix(name):
    match = re.fullmatch(r'ats-033-lab-(\d{3})-(\d{2})-(\d{2})', name)
    if not match:
        raise ValueError(f'{name}: lab name must be ats-033-lab-<section>-<module>-<lab>')
    return '033-' + '-'.join(match.groups())


def check_sources(config, cfg):
    for stage in ('bootstrap', 'testing', 'teardown', 'validation'):
        block = cfg.get(stage) or {}
        items = block.get('init', []) + block.get('scripts', [])
        if block.get('script'):
            items.append(block['script'])
        for item in items:
            if item.get('type') in ('file', 'folder') and not (config.parent / item['source']).exists():
                raise ValueError(f'{config}: missing {stage} source {item["source"]}')


def check_lab(root, lab, entry):
    directory = root / lab
    cfg = yaml.safe_load((directory / 'config.yaml').read_text())
    name = cfg['metadata']['name']
    suffix = lab_suffix(name)
    runtime = cfg['runtime']['type']
    init = [item.get('source') for item in cfg.get('testing', {}).get('init', [])]
    if init != LIFECYCLE:
        raise ValueError(f'{lab}: testing.init must be {LIFECYCLE}')
    scripts = cfg.get('validation', {}).get('scripts', [])
    if not scripts or cfg['validation'].get('script'):
        raise ValueError(f'{lab}: validation needs one scripts entry per outcome')
    wrapper = (SHARED / 'validate-outcome.sh').read_bytes()
    for grader in scripts:
        if not grader.get('description') or not isinstance(grader.get('points'), int):
            raise ValueError(f'{lab}: grader {grader.get("name")} needs a description and points')
        if grader['source'] != f'validation/validate-{grader["name"]}.sh':
            raise ValueError(f'{lab}: grader {grader["name"]} must use validation/validate-{grader["name"]}.sh')
        if (directory / grader['source']).read_bytes() != wrapper:
            raise ValueError(f'{lab}: {grader["source"]} differs from scripts/ci/lab-files/validate-outcome.sh')
    listed = {grader['source'] for grader in scripts}
    present = {str(path.relative_to(directory)) for path in directory.glob('validation/*')}
    if listed != present:
        raise ValueError(f'{lab}: validation/ files and config.yaml differ: {sorted(listed ^ present)}')
    for path, shared in SHARED_FILES.items():
        if (directory / path).read_bytes() != (SHARED / shared).read_bytes():
            raise ValueError(f'{lab}: {path} differs from scripts/ci/lab-files/{shared}')
    requirements = json.loads((directory / 'testing/requirements.json').read_text())
    outcomes = {grader['name'] for grader in scripts}
    tagged = {item['outcome'] for key in ('resources', 'behavior') for item in requirements.get(key, []) if 'outcome' in item}
    live = directory / 'testing/live.py'
    computed = False
    if live.exists():
        text = live.read_text()
        tagged |= set(re.findall(r"wants\('([\w-]+)'\)", text))
        # wants(host + '-ingress') names outcomes at run time; only literal names can be compared.
        computed = bool(re.search(r"wants\((?!')", text))
    if not tagged <= outcomes or (not computed and tagged != outcomes):
        raise ValueError(f'{lab}: graded outcomes and config.yaml differ: {sorted(tagged ^ outcomes)}')
    if not requirements['namespace'].endswith('-' + suffix):
        raise ValueError(f'{lab}: namespace must end with -{suffix}')
    if runtime == 'kind' and (requirements['context'], requirements['cluster']) != (f'kind-astro-{name}', f'astro-{name}'):
        raise ValueError(f'{lab}: requirements.json context and cluster must name astro-{name}')
    for script in ['validate.sh', 'solution/apply.sh']:
        if 'ASTRONA_KUBE_CONTEXT' not in (directory / script).read_text():
            raise ValueError(f'{lab}: {script} needs the context guard')
    question = (directory / 'question.md').read_text()
    minutes = re.search(r'^Allow about (\d+) minutes for the tasks\.( Cluster startup adds time\.)?$', question, re.M)
    if not minutes or int(minutes.group(1)) > MAX_MINUTES:
        raise ValueError(f'{lab}: question.md needs "Allow about N minutes for the tasks." with N <= {MAX_MINUTES}')
    if entry.get('estimated_duration') != f'{minutes.group(1)}m':
        raise ValueError(f'{lab}: estimated_duration in astrona.yaml must be {minutes.group(1)}m to match question.md')
    positions = [question.find(part) for part in QUESTION_PARTS]
    if min(positions) < 0 or positions != sorted(positions):
        raise ValueError(f'{lab}: question.md needs, in order: ' + ', '.join(QUESTION_PARTS))
    tasks = len(re.findall(r'^\d+\.\s', question.split('## Tasks', 1)[-1].split('## Constraints', 1)[0], re.M))
    if not 2 <= tasks <= 4:
        raise ValueError(f'{lab}: question.md needs 2-4 tasks, found {tasks}')
    if re.search(r'^draft:\s*true', question, re.M) or re.search(r'\bdraft\b', entry.get('title', ''), re.I):
        raise ValueError(f'{lab}: a registered lab must not be marked draft')
    if entry.get('examScope') and runtime != 'kind':
        raise ValueError(f'{lab}: only kind labs fit the exam profile')
    return name


def module_of(path):
    match = re.match(r'sections/section-\d+/module-\d+/', path)
    return match.group(0) if match else None


def validate(root):
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    entries = [entry for module in course['modules'] for entry in module.get('content', [])]
    paths = [entry['path'] for entry in entries]
    if len(paths) != len(set(paths)):
        raise ValueError('course content paths must be unique')
    for path in paths:
        if not (root / path).exists():
            raise ValueError(f'missing registered content: {path}')
    labs = {entry['path']: entry for entry in entries if entry['type'] == 'lab'}
    actual = {str(path.parent.relative_to(root)) for path in root.glob('sections/**/labs/lab-*/config.yaml')}
    if set(labs) != actual:
        raise ValueError(f'lab registration mismatch: {sorted(set(labs) ^ actual)}')
    names = set()
    for config in sorted(root.glob('sections/**/config.yaml')):
        cfg = yaml.safe_load(config.read_text())
        name = cfg['metadata']['name']
        if name in names:
            raise ValueError(f'duplicate environment name: {name}')
        names.add(name)
        if cfg['runtime']['type'] not in ('kind', 'qemu'):
            raise ValueError(f'{config}: unsupported runtime')
        check_sources(config, cfg)
    # Report every broken lab at once, not only the first.
    errors = []
    for lab, entry in labs.items():
        position = paths.index(lab)
        try:
            if paths[position - 1] != lab + '/question.md':
                raise ValueError(f'{lab}: question.md must immediately precede its lab')
            if position + 1 >= len(paths) or paths[position + 1] != lab + '/solution.md':
                raise ValueError(f'{lab}: solution.md must immediately follow its lab')
            check_lab(root, lab, entry)
        except (ValueError, KeyError, OSError) as error:
            errors.append(str(error))
    if errors:
        raise ValueError('\n  '.join([f'{len(errors)} labs fail:'] + errors))
    # A module's entries are contiguous and its summary is its last reading.
    seen, previous = set(), None
    for entry in entries:
        # A section quiz may live in a module folder but sits after the section's last module.
        if entry['type'] == 'quiz':
            continue
        module = module_of(entry['path'])
        if module and module != previous:
            if module in seen:
                raise ValueError(f'{module}: entries must be contiguous')
            seen.add(module)
        previous = module or previous
    for module in seen:
        own = [entry for entry in entries if module_of(entry['path']) == module and entry['type'] != 'quiz']
        last = own[-1]['path']
        if not re.fullmatch(re.escape(module) + r'course-\d+-summary\.md', last):
            raise ValueError(f'{module}: the summary must be the last entry, found {last}')
        if (root / last).read_text().rstrip().splitlines()[-1] != DESTROY:
            raise ValueError(f'{last}: must end with {DESTROY}')
    return len(labs), len(names) - len(labs)


if __name__ == '__main__':
    try:
        labs, playgrounds = validate(ROOT)
        print(f'PASS: {labs} labs and {playgrounds} playgrounds have valid registration and lifecycle files')
    except (ValueError, KeyError, OSError) as error:
        sys.exit(f'FAIL: {error}')
