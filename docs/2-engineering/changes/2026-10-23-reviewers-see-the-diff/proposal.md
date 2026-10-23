---
title: The task reviewers see the task's diff
status: proposed
date: 2026-10-23
related: [delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-22-gallery-runtime/proposal.md, ../../../3-using/operations/proof-runs.md]
style: spec
---

# The task reviewers see the task's diff

**Proposed 2026-10-23, after run 1 (v0-H20) stopped at its first task.** It fixes backlog B-170. Run 1 starts again
when this change is merged.

**What merging this approves:** Odin gives each task reviewer the diff of its task, and the three reviewer prompts
read it from there. The reviewers keep no shell. The founder chose this way on 2026-10-23, over two others (see
"Options").

## What happened

Run 1 (`20261023-205334-ce5329`) passed the design, spec and plan gates. It stopped at an escalation in task t001:
`reviewer-unreadable`, twice in a row.

- **The task was small.** t001 changed 8 files, with 314 lines added and 12 removed, in `repos/api`.
- **The spec-compliance reviewer never saw that change.** Its prompt (`voluspa/software/prompts/reviewer-spec.md`)
  says `git diff $(git merge-base HEAD main) HEAD` shows the change. But a read-only session has no shell:
  - opencode gets `"bash": "deny"` (`gleipnir/opencode/opencode.go:139-140`);
  - Claude Code gets `--tools Read,Grep,Glob` (`gleipnir/claudecode/claudecode.go:72-73`).
- **So it read the whole leaf instead.** It made 41 tool calls in its 20 turns, almost all `read`s of single
  directories and files, the template included. It ran out of turns (`voluspa/software/graph.yaml:104-116`) before
  it reached a verdict.
- **Its last answer broke the report schema.** opencode made it answer with no tools left, and that answer's
  findings missed the report schema's `status` and `proof`. The retry did the same.

The other two reviewers' prompts (`reviewer-simplicity.md:6`, `reviewer-quality.md:8`) point to the same command.
Nothing else gives a reviewer the diff: Odin's review prompt is the role's prompt, the task block and Jormungandr's
request (`odin/internal/engine/loop.go:215-238`). Earlier real runs got through because their tasks were tiny or a
reviewer read enough by chance.

**The spec says two things.** §3.3 rule 4 says agents "can then read `git log` and `git diff`". §5's adapter table says
read-only roles get read and search tools only. The second is what is built, and it is right: a reviewer that
cannot run commands cannot change the leaf.

## Options

| | Way | For | Against |
| --- | --- | --- | --- |
| **A (chosen)** | **Odin computes the task's diff on the host and puts it in the reviewer's prompt** | every adapter; reviewers stay without a shell; the reviewer reads only what changed | an odin change with tests |
| B | Let read-only sessions run `git diff` and `git log` | small | git runs repo-controlled drivers (`diff.external`, `textconv` in `.gitattributes`): the read-only promise weakens |
| C | Raise the reviewers' `max_turns` from 20 to 40 | one line | reviewers keep reading whole leaves and pay for it, and a bigger leaf runs out again |

## The change

- **The diff's base.** Odin records the leaf's commit when a task's loop starts, before attempt 1, in the run's state,
  so a resume keeps it. The diff goes from that commit to the attempt's commit. It holds only this task's work, never
  the template or the tasks that landed before. A leaf's `main` is not the base: in run 1, the template commit was on
  the run's branch, so `merge-base HEAD main` would have shown the whole template.
- **How Odin runs git.** Odin runs git on the host with hooks off (spec §3.3 rule 5). It also turns off external diff
  drivers and text conversion (`--no-ext-diff --no-textconv`, `-c diff.external=`) and colour. Nothing in the leaf
  can make that git run a command.
- **What the reviewer gets.** A section "The change" goes after the task block:
  - the changed files with their line counts (`--stat`);
  - then the diff itself, up to a cap (about 200 KB).
  - A diff over the cap is cut at a file boundary. The section then says which files are left out and that they are
    in the leaf to read. Binary files are named, not shown.
- **Who gets it.** The three task reviewers. The conformance and reuse reviewers do not change: they read documents,
  not a task's work.
- **The prompts.** The three reviewer prompts say the change is in "The change" below. They tell the reviewer to read
  it first, then only the code it touches. The `git diff` line goes.
- **What does not change.** The reviewers' `max_turns` (20) and timeouts (10m). A reviewer still has no shell, and
  Odin still checks that it changed nothing (`checkReadOnly`).

## Risks

- **A large diff costs tokens in every review.** The cap bounds it, and the file list is always there.
- **A diff is data from an agent, in a reviewer's prompt.** That is already true of every file the reviewer reads, and
  reviewers treat repository content as data (`AGENTS.md`, invariant 8). The section says so in one line.

## History

- 2026-10-23: proposed after run 1 stopped at t001. The founder chose option A.
