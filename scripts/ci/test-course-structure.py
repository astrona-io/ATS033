#!/usr/bin/env python3
"""Reject broken registration, module order and lab layout."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]
LAB = 'sections/section-020/module-02/labs/lab-01'
spec = importlib.util.spec_from_file_location('structure', Path(__file__).with_name('check-course-structure.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StructureTests(unittest.TestCase):
    """Each test breaks one rule in a copy of the course and expects the check to fail."""

    def setUp(self):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        self.root = Path(work.name)
        shutil.copy(ROOT / 'astrona.yaml', self.root)
        shutil.copytree(ROOT / 'sections', self.root / 'sections')
        self.lab = self.root / LAB

    def course(self):
        return yaml.safe_load((self.root / 'astrona.yaml').read_text())

    def save_course(self, course):
        (self.root / 'astrona.yaml').write_text(yaml.safe_dump(course, sort_keys=False))

    def content_of(self, course, path):
        return next(m['content'] for m in course['modules'] if any(e['path'] == path for e in m['content']))

    def config(self):
        return yaml.safe_load((self.lab / 'config.yaml').read_text())

    def save_config(self, config):
        (self.lab / 'config.yaml').write_text(yaml.safe_dump(config, sort_keys=False))

    def test_valid(self):
        module.validate(self.root)

    def test_unregistered_lab(self):
        course = self.course()
        content = self.content_of(course, LAB)
        content[:] = [e for e in content if not e['path'].startswith(LAB)]
        self.save_course(course)
        with self.assertRaisesRegex(ValueError, 'lab registration mismatch'):
            module.validate(self.root)

    def test_question_must_precede_lab(self):
        course = self.course()
        content = self.content_of(course, LAB)
        question = next(e for e in content if e['path'] == LAB + '/question.md')
        content.remove(question)
        content.insert(0, question)
        self.save_course(course)
        with self.assertRaisesRegex(ValueError, 'question.md must immediately precede'):
            module.validate(self.root)

    def test_summary_must_end_module(self):
        course = self.course()
        content = self.content_of(course, LAB)
        summary = next(e for e in content if e['path'].endswith('-summary.md'))
        content.remove(summary)
        content.insert(1, summary)
        self.save_course(course)
        with self.assertRaisesRegex(ValueError, 'summary must be the last entry'):
            module.validate(self.root)

    def test_summary_needs_destroy_marker(self):
        summary = next((self.root / LAB).parents[1].glob('course-*-summary.md'))
        summary.write_text(summary.read_text().replace(module.DESTROY, ''))
        with self.assertRaisesRegex(ValueError, 'must end with'):
            module.validate(self.root)

    def test_testing_init_order(self):
        config = self.config()
        config['testing']['init'].reverse()
        self.save_config(config)
        with self.assertRaisesRegex(ValueError, 'testing.init'):
            module.validate(self.root)

    def test_edited_shared_file(self):
        with (self.lab / 'testing/check.py').open('a') as handle:
            handle.write('# local change\n')
        with self.assertRaisesRegex(ValueError, 'differs from scripts/ci/lab-files/check.py'):
            module.validate(self.root)

    def test_unlisted_grader(self):
        shutil.copy(next(self.lab.glob('validation/*.sh')), self.lab / 'validation/validate-extra.sh')
        with self.assertRaisesRegex(ValueError, 'validation/ files and config.yaml differ'):
            module.validate(self.root)

    def test_grader_without_points(self):
        config = self.config()
        del config['validation']['scripts'][0]['points']
        self.save_config(config)
        with self.assertRaisesRegex(ValueError, 'needs a description and points'):
            module.validate(self.root)

    def test_bare_namespace(self):
        path = self.lab / 'testing/requirements.json'
        text = path.read_text()
        namespace = module.json.loads(text)['namespace']
        path.write_text(text.replace(f'"{namespace}"', '"starfleet"'))
        with self.assertRaisesRegex(ValueError, 'namespace must end with'):
            module.validate(self.root)

    def test_missing_context_guard(self):
        (self.lab / 'validate.sh').write_text('#!/usr/bin/env bash\npython3 testing/check.py "$@"\n')
        with self.assertRaisesRegex(ValueError, 'context guard'):
            module.validate(self.root)

    def test_long_exam_time(self):
        question = self.lab / 'question.md'
        text = question.read_text()
        question.write_text(module.re.sub(r'Allow about \d+ minutes', 'Allow about 45 minutes', text))
        with self.assertRaisesRegex(ValueError, 'Allow about N minutes'):
            module.validate(self.root)

    def test_duration_drift(self):
        course = self.course()
        next(e for e in self.content_of(course, LAB) if e['path'] == LAB)['estimated_duration'] = '25m'
        self.save_course(course)
        with self.assertRaisesRegex(ValueError, 'estimated_duration'):
            module.validate(self.root)

    def test_question_shape(self):
        question = self.lab / 'question.md'
        question.write_text(question.read_text().replace('## Constraints', '## Limits'))
        with self.assertRaisesRegex(ValueError, 'in order'):
            module.validate(self.root)

    def test_draft_lab(self):
        question = self.lab / 'question.md'
        question.write_text(question.read_text().replace('---\n', '---\ndraft: true\n', 1))
        with self.assertRaisesRegex(ValueError, 'must not be marked draft'):
            module.validate(self.root)


if __name__ == '__main__':
    unittest.main()
