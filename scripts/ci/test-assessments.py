#!/usr/bin/env python3
"""Reject broken question banks, answer references and teaching order."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
import jsonschema
import yaml

ROOT = Path(__file__).resolve().parents[2]
BANK = 'sections/section-010/module-10/quiz.yaml'
spec = importlib.util.spec_from_file_location('assessments', Path(__file__).with_name('check-assessments.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AssessmentTests(unittest.TestCase):
    """Each test breaks one rule in a copy of the course and expects the check to fail."""

    def setUp(self):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        self.root = Path(work.name)
        shutil.copy(ROOT / 'astrona.yaml', self.root)
        for folder in ('sections',):
            shutil.copytree(ROOT / folder, self.root / folder,
                            ignore=shutil.ignore_patterns('labs', 'playground'))

    def load(self, path):
        return yaml.safe_load((self.root / path).read_text())

    def save(self, path, data):
        (self.root / path).write_text(yaml.safe_dump(data, sort_keys=False))

    def test_valid(self):
        module.validate(self.root)

    def test_missing_reading(self):
        bank = self.load(BANK)
        bank['questions'][0]['source_readings'] = ['sections/missing.md']
        self.save(BANK, bank)
        with self.assertRaisesRegex(ValueError, 'missing or unregistered'):
            module.validate(self.root)

    def test_quiz_before_teaching(self):
        course = self.load('astrona.yaml')
        content = next(m['content'] for m in course['modules'] if any(e['path'] == BANK for e in m['content']))
        quiz = next(e for e in content if e['path'] == BANK)
        content.remove(quiz)
        content.insert(0, quiz)
        self.save('astrona.yaml', course)
        with self.assertRaisesRegex(ValueError, 'comes before its teaching'):
            module.validate(self.root)

    def test_invalid_answer(self):
        bank = self.load(BANK)
        # 'd' passes the schema enum but names no option of this three-option question.
        question = bank['questions'][0]
        question['options'] = question['options'][:3]
        question['correct_option'] = 'd'
        self.save(BANK, bank)
        with self.assertRaisesRegex(ValueError, 'answer references'):
            module.validate(self.root)

    def test_stale_manifest_count(self):
        course = self.load('astrona.yaml')
        next(e for m in course['modules'] for e in m['content'] if e['path'] == BANK)['question_count'] += 1
        self.save('astrona.yaml', course)
        with self.assertRaisesRegex(ValueError, 'question_count in astrona.yaml'):
            module.validate(self.root)

    def test_duplicate_id(self):
        bank = self.load(BANK)
        bank['questions'][1]['id'] = bank['questions'][0]['id']
        self.save(BANK, bank)
        with self.assertRaisesRegex(ValueError, 'duplicate question'):
            module.validate(self.root)

    def test_unknown_bank(self):
        shutil.copy(self.root / BANK, self.root / 'sections/extra-quiz.yaml')
        with self.assertRaisesRegex(ValueError, 'not registered'):
            module.validate(self.root)

    def test_schema_bank_size(self):
        bank = self.load(BANK)
        bank['questions'] = bank['questions'][:4]
        self.save(BANK, bank)
        with self.assertRaises(jsonschema.ValidationError):
            module.validate(self.root)


if __name__ == '__main__':
    unittest.main()
