# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Name files in steps of ten.** The folder view shows the reading order.
  A section starts with `00-introduction.md`. Modules are `module-10`,
  `module-20`, `module-30`. In a module, the landing page is `course-000.md`,
  the parts are `course-010-<slug>.md`, `course-020-<slug>.md`, and the
  summary is always `course-100-summary.md`. Lab folders and lab names keep
  their own numbers, and question `id`s never change.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, give the new part a free step-ten
  number (or renumber the parts), fix every "Part N" reference in the module
  and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls`. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-100-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Draw a
  picture wherever it explains a flow, an order, a state change or who does
  what better than text. Prefer a hand-drawn SVG in the module's `images/`
  folder (shown with `![Diagram: what it shows](images/<name>.svg)`): light
  box fills with dark text so it reads on light and dark pages, green for
  allowed, red dashed for dropped, real names in monospace, a `<title>` and
  `<desc>`. Mermaid is still fine for a quick flow. Keep either under about
  12 boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. The part itself ends with `## Common pitfalls`; it has no
  `## Your mission` section or lab commands, because the platform shows the
  lab right after it.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `00-introduction.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `10-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `20-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `30-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, "About the authors" (one HTML
    `<table>` per author or maintainer, no header row: 320 × 320 PNG photo, shown at 120 × 120, from
    `images/author/<handle>.png` beside one cell with three lines split by `<br>`:
    the bold name, a short bio, then the GitHub link and optional LinkedIn link; roles live only in `AUTHORS.md`; the format is in CONTRIBUTING.md;
    it must match `AUTHORS.md`, and `scripts/ci/check-authors.py` checks it),
    how to report a mistake, and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license, and the GitHub and LinkedIn profiles of the authors.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## Exam-ready labs (CKS trainings ATS031–ATS036)

Graded labs in the CKS trainings also run in the full lab exam, where several
labs share one kind cluster. The full convention, with a before and after
example, is `authoring/exam-ready-labs.md` in `astrona-io/astrona-content`.
ATS020 (CNPE: Observability and Operations) is the model training format:
where this repo and ATS020 differ on grader layout, check style or the time
line, follow ATS020. The context guard is the exception: ATS020 has none,
the CKS labs keep theirs. ATS031 applies it to the CKS labs; copy from it. In short:

- **Own namespaces.** Name each namespace `<role>-<training>-<section>-<module>-<lab>`
  from the lab's `metadata.name`: `starfleet-033-040-01-04`,
  `outpost-033-040-01-04`. Never a bare `starfleet`, `outpost` or `dock`.
- **Keep the context guard; no hardcoded cluster.** Every script and helper
  refuses to run unless `kubectl config current-context` is the lab's own
  context, read from `${ASTRONA_KUBE_CONTEXT:-kind-astro-<lab>}` so the guard
  also passes on an exam cluster (a qemu lab falls back to
  `kubernetes-admin@astro-<lab>`). Never remove the guard to make a lab
  portable. Scripts that exec into a node read `ASTRONA_KIND_CLUSTER` and
  `ASTRONA_CONTAINER_ENGINE` with the lab mode value as fallback and run
  `"$engine" exec "$cluster-worker"` (or `"$cluster-control-plane"`), never
  `podman exec astro-<lab>-worker`. A solution page that runs a command on a
  kind node sets `cluster` and `engine` the same way in its first command
  block. `live.py` uses `NODE`, `WORKER`,
  `ENGINE` and `node_exec()`. A qemu lab runs its scripts inside its one-node
  VM: `bootstrap/helpers.sh` (`run_on_node`, `run_on_worker`) and `node_exec()`
  run node commands with `sudo`.
- **One grader per outcome.** `config.yaml` lists `validation.scripts`, one
  per outcome, each with `description` and `points`, sourced from
  `validation/validate-<outcome>.sh` (ATS020's layout; a qemu lab sources the
  generated `vm/validate-<outcome>.sh`, which runs that file inside the VM).
  Each is the same wrapper that runs `validate.sh <outcome>` and
  `testing/check.py`, which prints one `PASS:` or `FAIL:` line (exit 0 or 1).
  When the grader cannot look at the lab at all (a missing tool, an API server
  that does not answer), `check.py` prints `ERROR:` and exits 2 instead, so a
  broken environment is not reported as unfinished work. `check.py`,
  `verify-start.sh`, `wait-solved.sh` and the wrappers are identical in every
  lab and match `scripts/ci/lab-files/`; do not edit them per lab. Tag
  `requirements.json` entries with `"outcome"` and put `live.py` checks under
  `if wants('<id>'):`. Checks without an outcome are guards and run with every
  outcome. Every outcome fails on the unsolved lab and passes for the
  reference solution.
- **`testing.init`.** `testing/verify-start.sh` (every outcome fails at the
  start with exit 1 and a `FAIL:` line; an `ERROR:` or a crash is rejected),
  then `solution/apply.sh`, then `testing/wait-solved.sh`. A qemu lab uses
  the generated `vm/verify-start.sh`, `vm/apply-solution.sh` and
  `vm/wait-solved.sh`, which run the same files inside the VM.
- **Time line.** `question.md` has `Allow about N minutes for the tasks.`
  under its title, as in ATS020: the exam time for a prepared student. Over
  20 minutes cannot join an exam.
- **`examScope`.** Set `namespace` or `cluster` on the lab's `astrona.yaml`
  entry only when its `runtime.kind` fits the exam profile in
  `exams/kubestronaut/cks.yaml` (one control plane, one worker, kindnet).
  Anything that changes nodes, static pods, the kubelet or other cluster-wide
  state is `cluster`.
- **Verify end to end.** `astrona validate <lab-dir>` and
  `astrona test <lab-dir> --accept-terms --headless` must both pass.
- **Hands off** `task_kind`, `tags` and `topic`: other tooling owns them.

## About this repo (ATS033 only)

The course covers **System Hardening**, worth **10%** of
**Certified Kubernetes Security Specialist (CKS)**. It is part of **ATP007**.
The official objectives are listed in `astrona.yaml` and mapped in `CURRICULUM.md`.

### Playground and graded lab scope

The maintainer requested playgrounds and graded labs on 2026-10-13. This supersedes the earlier reading-only instruction. Each active module has one private ungraded environment and guided practice. Register each independent graded task, launch entry and solution directly after the reading it practises. Retain draft technical pages and the existing question banks. Use context guards and bounded waits; node commands may target only this environment's containers. Record static, offline and live evidence separately.

### Teaching structure and depth

Every section begins with its own introduction and measurable learning outcomes.
Every module contains a landing page, developed teaching lessons and a final
`# Summary` page. Put the summary after all its lessons and before the next
module. The summary ends with <!-- astrona:playground:destroy --> on its own line.

Explain mechanisms, responsible components, realistic examples and the limits
of each claim. Include worked reasoning and relevant failure cases. Avoid thin
outlines, repetitive filler and invented command output. Split broad topics when
needed; do not force a fixed number of lessons. The shared plain-English,
self-contained-page and Mermaid rules apply throughout.

### Reusable question data

Write original single-choice questions as YAML banks under section folders and
`assessments/`. Use the versioned contract in `schemas/question-bank.schema.json`
and teaching order in `assessments/index.yaml`. Each bank has 5–15 questions with
stable IDs, one correct option, per-option feedback, a measurable learning
objective and source reading paths for author traceability.

Do not register YAML as a Markdown reading. A future renderer consumes the bank
index and presents the checkpoint after its declared reading, preserving bank
order when several share an anchor. Do not expose answer keys before submission
in a production quiz interface. These public banks are practice material, not
secure or official exam questions.

### Review and authoring checks

Preserve the shared CLAUDE.md prefix copied from ATS015. Keep course IDs, official
domain weights and ATP links unchanged. Technical pages carry no `draft: true`
front matter. The course registration in `astrona-content` is published (ATP007 version 1.0.0, approved 2026-11-21); maturity stays `alpha`.

Primary author sources are recorded in `SOURCES.md`. The objective list was
verified on 2026-10-11. Detailed reading expansions were written on 2026-10-11.
Validate manifest paths, summary ordering, curriculum coverage and question
contracts. Do not claim live verification until the actual runtime result has been recorded.
