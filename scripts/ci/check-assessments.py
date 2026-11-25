#!/usr/bin/env python3
"""Check question banks against the schema, astrona.yaml and the teaching order."""
from pathlib import Path
import json
import sys
import jsonschema
import yaml


def check_bank(root, path, bank, readings, anchor, ids):
    """Check one bank's answers and that every question follows its teaching."""
    for question in bank['questions']:
        qid = question['id']
        if qid in ids:
            raise ValueError(f'duplicate question id: {qid}')
        ids.add(qid)
        options = [option['id'] for option in question['options']]
        if len(options) != len(set(options)) or question['correct_option'] not in options:
            raise ValueError(f'{qid}: invalid answer references')
        for reading in question['source_readings']:
            if reading not in readings or not (root / reading).is_file():
                raise ValueError(f'{qid}: missing or unregistered reading {reading}')
            if readings[reading] > anchor:
                raise ValueError(f'{qid}: {path} comes before its teaching {reading}')
    return len(bank['questions'])


def validate(root):
    schema = json.loads((Path(__file__).with_name('question-bank.schema.json')).read_text())
    # The final domain quiz covers the whole course, so the 5-15 module bank size does not apply.
    final_quiz = json.loads(json.dumps(schema))
    final_quiz['properties']['questions'].pop('maxItems')
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    entries = [entry for module in course['modules'] for entry in module.get('content', [])]
    readings = {entry['path']: index for index, entry in enumerate(entries) if entry['type'] == 'reading'}
    quizzes = {entry['path']: (index, entry) for index, entry in enumerate(entries) if entry['type'] == 'quiz'}
    actual = {str(path.relative_to(root)) for path in root.glob('sections/**/*quiz.yaml')}
    if set(quizzes) != actual:
        unregistered, missing = sorted(actual - set(quizzes)), sorted(set(quizzes) - actual)
        raise ValueError(f'banks on disk are not registered: {unregistered}; registered but missing: {missing}')
    ids, banks, count = set(), set(), 0
    for path in sorted(actual):
        bank = yaml.safe_load((root / path).read_text())
        jsonschema.validate(bank, schema if Path(path).name == 'quiz.yaml' else final_quiz)
        if bank['id'] in banks:
            raise ValueError(f'duplicate bank id: {bank["id"]}')
        banks.add(bank['id'])
        anchor, entry = quizzes[path]
        if entry.get('question_count') != len(bank['questions']):
            raise ValueError(f'{path}: question_count in astrona.yaml differs from bank length')
        reading = (bank.get('placement') or {}).get('reading')
        if reading and reading not in readings:
            raise ValueError(f'{path}: placement reading {reading} is not registered')
        count += check_bank(root, path, bank, readings, anchor, ids)
    return len(banks), count


if __name__ == '__main__':
    try:
        banks, questions = validate(Path(__file__).resolve().parents[2])
        print(f'PASS: {questions} questions in {banks} banks match the schema and follow their teaching')
    except (ValueError, KeyError, OSError, jsonschema.ValidationError) as error:
        sys.exit(f'FAIL: {getattr(error, "message", error)}')
