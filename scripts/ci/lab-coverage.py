#!/usr/bin/env python3
"""Render the registered preparation lessons, tasks and grader contracts."""
from pathlib import Path
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]


def link(title, path):
    return f'[{title.replace("|", "/")}]({path})'


def render():
    course = yaml.safe_load((ROOT / 'astrona.yaml').read_text())
    lines = ['# Lab coverage', '',
             'Generated from course registration and grader descriptions. Run '
             '`python3 scripts/ci/lab-coverage.py --write` after changing either.', '',
             'This map shows assessed outcomes, not a passing test result or a claim that '
             'every reading has a separate assessment. Other readings and playgrounds '
             'provide supporting concepts and ungraded practice. Review those boundaries '
             'when adding an assessable skill.', '',
             '| Preparation | Independent task and starting state | Graded result | Lifecycle |',
             '| --- | --- | --- | --- |']
    for section in course['modules']:
        lesson = None
        for entry in section.get('content', []):
            path = entry.get('path', '')
            if entry.get('type') == 'reading' and '/labs/' not in path:
                lesson = entry
            if entry.get('type') != 'lab':
                continue
            config = yaml.safe_load((ROOT / path / 'config.yaml').read_text())
            validation = config.get('validation', {})
            graders = validation.get('scripts') or [validation['script']]
            descriptions = '; '.join(link(g.get('description') or g['name'], path + '/' + g['source']) for g in graders)
            prep = link(lesson['title'], lesson['path']) if lesson else 'Section integration'
            task = link(entry['title'], path + '/question.md')
            lifecycle = link('Reference lifecycle', path + '/config.yaml')
            lines.append(f'| {prep} | {task} | {descriptions} | {lifecycle} |')
    lines += ['', 'Every module lab runs its unfinished-state check, reference solution, '
              'bounded reconciliation wait and graders. Capstones retain their own '
              'integration lifecycle. The GitHub Actions workflow runs each selected '
              'environment on a separate runner and requires the aggregate '
              '`all environments pass` job.', '']
    return '\n'.join(lines)


if __name__ == '__main__':
    output = ROOT / 'LAB-COVERAGE.md'
    expected = render()
    if '--write' in sys.argv:
        output.write_text(expected)
    elif not output.exists() or output.read_text() != expected:
        sys.exit('FAIL: regenerate LAB-COVERAGE.md with python3 scripts/ci/lab-coverage.py --write')
    else:
        print('PASS: lab coverage map matches the course and grader contracts')
