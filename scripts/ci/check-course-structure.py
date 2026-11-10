#!/usr/bin/env python3
"""Check course registration, lab boundaries, question shape and local runtime references."""
from collections import Counter
from pathlib import Path
import re
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]
TIME_LINE = re.compile(r"\bAllow\s+(?:about\s+)?(?:\d+\s*[–-]\s*)?\d+\s+minutes\s+(?:for|of)\s+(?:the\s+)?(?:\w+\s+)?tasks?\b")
QUESTION_PARTS = ("Solve this question on: `terminal`", "## Tasks", "## Constraints", "## How the answer is checked")
errors = []


def require(condition, message):
    if not condition:
        errors.append(message)


def read_yaml(path):
    try:
        return yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as error:
        errors.append(f"{path.relative_to(ROOT)}: {error}")
        return {}


def check_question(path):
    question = ROOT / path / "question.md"
    if not question.is_file():
        return
    text = question.read_text()
    positions = [text.find(part) for part in QUESTION_PARTS]
    require(all(position >= 0 for position in positions) and positions == sorted(positions),
            f"{path}: question needs, in order: " + ", ".join(QUESTION_PARTS))
    require(bool(TIME_LINE.search(text)), f"{path}: question needs a time line (Allow about N minutes for the tasks)")
    tasks = re.findall(r"^\d+\.\s+", text, re.M)
    require(2 <= len(tasks) <= 4, f"{path}: expected 2–4 tasks, found {len(tasks)}")


outline = read_yaml(ROOT / "astrona.yaml")
registered = []
for section in outline.get("modules", []):
    content = section.get("content", [])
    for index, item in enumerate(content):
        path = item.get("path", "")
        require(bool(path) and (ROOT / path).exists(), f"Missing course path: {path}")
        if item.get("type") != "lab":
            continue
        registered.append(path)
        require(index > 0 and content[index - 1].get("path") == path + "/question.md",
                f"{path}: lab must follow its question reading")
        check_question(path)
        if "/module-" not in path:
            continue
        require(index > 1 and content[index - 2].get("type") == "reading",
                f"{path}: lab needs a preparation reading")
        if index < 2:
            continue
        lesson = content[index - 2].get("path", "")
        module = str(Path(path).parent.parent)
        require(lesson.startswith(module + "/course-0"),
                f"{path}: place the lab immediately after one of its module's lessons")

counts = Counter(registered)
for path, count in counts.items():
    require(count == 1, f"Duplicate lab registration: {path}")

runtime_names = {}
module_labs = 0
for config in sorted((ROOT / "sections").rglob("config.yaml")):
    environment = config.parent
    if environment.name != "playground" and environment.parent.name != "labs":
        continue
    relative = str(environment.relative_to(ROOT))
    data = read_yaml(config)
    name = data.get("metadata", {}).get("name")
    require(bool(name), f"{relative}: missing runtime name")
    require(name not in runtime_names,
            f"{relative}: runtime name {name} also used by {runtime_names.get(name)}")
    runtime_names[name] = relative
    if environment.parent.name == "labs":
        require(relative in counts, f"Unregistered lab: {relative}")
        validation = data.get("validation", {})
        require(bool(validation.get("scripts") or validation.get("script")), f"{relative}: no graders")
        require(bool(data.get("testing", {}).get("init")), f"{relative}: no reference lifecycle")
        if "/module-" in relative:
            module_labs += 1
            steps = data.get("testing", {}).get("init", [])
            require(bool(steps) and steps[0].get("source") == "testing/verify-start.sh",
                    f"{relative}: verify the starting state before the solution")
    for value in data.get("metadata", {}).get("docs", {}).values():
        require((environment / value).is_file(), f"{relative}: missing document {value}")

    def check_sources(value):
        if isinstance(value, dict):
            if value.get("type") == "file" and "source" in value:
                require((environment / value["source"]).is_file(),
                        f"{relative}: missing source {value['source']}")
            for child in value.values():
                check_sources(child)
        elif isinstance(value, list):
            for child in value:
                check_sources(child)

    check_sources(data)

for quiz in (ROOT / "sections").rglob("*quiz.yaml"):
    for question in read_yaml(quiz).get("questions", []) or []:
        for reading in question.get("source_readings", []):
            require((ROOT / reading).is_file(), f"{quiz.relative_to(ROOT)}: missing reading {reading}")

if errors:
    print("\n".join(f"FAIL: {error}" for error in errors))
    sys.exit(1)
print(f"PASS: {len(registered)} registered labs, {module_labs} module labs, {len(runtime_names)} unique environments")
