#!/usr/bin/env python3
"""Check question banks against the schema, the bank index and the teaching order."""
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
    schema = json.loads((root / 'schemas/question-bank.schema.json').read_text())
    # The final domain quiz is registered but not indexed, so the 5-15 bank size does not apply.
    registered_only = json.loads(json.dumps(schema))
    registered_only['properties']['questions'].pop('maxItems')
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    entries = [entry for module in course['modules'] for entry in module.get('content', [])]
    readings = {entry['path']: index for index, entry in enumerate(entries) if entry['type'] == 'reading'}
    quizzes = {entry['path']: (index, entry) for index, entry in enumerate(entries) if entry['type'] == 'quiz'}
    index_banks = yaml.safe_load((root / 'assessments/index.yaml').read_text())['banks']
    indexed = {bank['path']: bank for bank in index_banks}
    actual = {str(path.relative_to(root)) for pattern in ('sections/**/*quiz.yaml', 'assessments/*.yaml')
              for path in root.glob(pattern) if path.name != 'index.yaml'}
    if set(quizzes) | set(indexed) != actual:
        raise ValueError(f'banks on disk are neither registered nor indexed: {sorted(actual - set(quizzes) - set(indexed))}')
    ids, banks, count = set(), set(), 0
    for path in sorted(actual):
        bank = yaml.safe_load((root / path).read_text())
        jsonschema.validate(bank, schema if path in indexed else registered_only)
        if bank['id'] in banks:
            raise ValueError(f'duplicate bank id: {bank["id"]}')
        banks.add(bank['id'])
        size = len(bank['questions'])
        # A registered quiz sits at its manifest position; an indexed bank sits after its reading.
        if path in quizzes:
            anchor, entry = quizzes[path]
            if entry.get('question_count') != size:
                raise ValueError(f'{path}: question_count in astrona.yaml differs from bank length')
        if path in indexed:
            listed = indexed[path]
            if (listed['id'], listed['question_count']) != (bank['id'], size):
                raise ValueError(f'{path}: assessments/index.yaml id or question_count differs from the bank')
            if bank.get('placement') and bank['placement'] != listed['placement']:
                raise ValueError(f'{path}: placement differs from assessments/index.yaml')
            reading = listed['placement']['reading']
            if reading not in readings:
                raise ValueError(f'{path}: placement reading {reading} is not registered')
            if path not in quizzes:
                anchor = readings[reading]
        count += check_bank(root, path, bank, readings, anchor, ids)
    return len(banks), count


if __name__ == '__main__':
    try:
        banks, questions = validate(Path(__file__).resolve().parents[2])
        print(f'PASS: {questions} questions in {banks} banks match the schema and follow their teaching')
    except (ValueError, KeyError, OSError, jsonschema.ValidationError) as error:
        sys.exit(f'FAIL: {getattr(error, "message", error)}')
