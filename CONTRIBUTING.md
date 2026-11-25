# Contributing

Thank you for helping to improve this course. Every fix makes the material better for the next learner, whether it is a typo, a step that does not work, or a whole new lab.

This course is created and maintained by Astrona.io. Contributions come back into this repository, and Astrona.io keeps the course in one place for everyone.

## Report a mistake

You do not need to write any code to help. If you find an error, a step that does not work or a sentence that is hard to understand, open an issue:
https://github.com/astrona-io/ATS033/issues

Please include:

- the page or the lab (its file path or its title),
- the sentence or the command you mean,
- what you expected and what happened instead,
- for a playground or a lab that failed: its name and the exact error message.

## Change the material

1. Fork the repository and create a branch for your change.
2. Read [CLAUDE.md](CLAUDE.md). It holds the writing style and the rules for pages, labs and playgrounds: plain English, real technical terms, no links between course pages, and YAML saved to a file before it is applied.
3. Make your change. Keep one topic per pull request.
4. Run the checks below.
5. Open a pull request. Say what you changed and why, and how you tested it.

Commands, configuration files and command output on the pages must come from a real run. Never make up command output. If you shorten it, say so on the page.

## Run the checks

The CI scripts need Python 3 and the packages in `scripts/ci/requirements.txt`:

```sh
python3 -m venv .venv
.venv/bin/pip install -r scripts/ci/requirements.txt
.venv/bin/python scripts/ci/check-course-structure.py
.venv/bin/python scripts/ci/test-course-structure.py
.venv/bin/python scripts/ci/check-assessments.py
.venv/bin/python scripts/ci/check-authors.py
```

When you change a lab or a playground, also check and test it with the `astrona` CLI:

```sh
astrona validate <lab-dir>
astrona test <lab-dir> --accept-terms --headless
```

`astrona test` starts the lab, runs the reference solution, grades it and removes it again. It needs a running container engine, and QEMU for the virtual machine labs. CI runs the same test on every lab you change.

## Licenses and credit

This repository uses two licenses. The details are in [NOTICE](NOTICE).

- Course content (pages, images, diagrams, questions): [CC BY-NC-SA 4.0](LICENSE-CONTENT).
- Code (scripts, lab and playground configuration, graders): [AGPL v3](LICENSE).

By opening a pull request, you agree that:

- your contribution is your own work, or you have the right to submit it;
- your contribution is licensed under the license of the files it changes;
- Astrona.io may also license your contribution under other terms, including a commercial license.

You keep the credit for your work. Add your name to the Contributors section of [AUTHORS.md](AUTHORS.md) in your pull request. Do not remove or change the names that are already there.

When you become an author or a maintainer, add yourself to that section of [AUTHORS.md](AUTHORS.md) as `- Name (GitHub: handle)`, and add yourself under "About the authors" in `sections/intro/30-how-this-course-is-made.md`, after the people already there:

```html
<table>
  <tr>
    <td align="center" valign="top" width="120"><img src="images/author/your-handle.png" alt="Your Name" width="120"></td>
    <td><strong>Your Name</strong><br>Two or three sentences about you: what you work on and why you care about this topic.<br><a href="https://github.com/your-handle">GitHub</a> · <a href="https://www.linkedin.com/in/your-name">LinkedIn</a></td>
  </tr>
</table>
```

Only the name is bold. The LinkedIn link is optional: leave out ` · ` and the second link if you do not want it.

Leave one empty line between two authors.

Your role goes only in AUTHORS.md. Save your photo as a square 320 × 320 pixel PNG at `sections/intro/images/author/<your-handle>.png`. The page shows it at 120 × 120, so it stays sharp on high-resolution screens. CI fails when the page and AUTHORS.md do not list the same people.
