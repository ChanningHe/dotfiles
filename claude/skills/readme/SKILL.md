---
name: readme
description: This skill should be used when writing, rewriting or trimming the README.md at the root of a project, including when a finished feature needs to be reflected there. It keeps the README short and aimed at a first-time user instead of a dump of everything known about the code. Not for READMEs in subdirectories, docs/ pages, or module specs (use documentation).
---

# README

A root README answers a first-time visitor, nothing else. The usual failure is writing down everything learned while reading the code; this skill exists to cut that.

## The test

The reader has never seen the project and wants to use it, not maintain it. Every line must help answer one of:

1. What is this?
2. Should I use it?
3. How do I install it?
4. How do I get a first result?

A line that answers none of these does not belong in the README, however true or hard-won it is.

## Skeleton

Keep this order; it follows the reader's decisions, so they can stop as soon as they have their answer. Omit a section that has nothing to say rather than leaving an empty heading.

1. **Title and one sentence**: what it is and who it is for. No "This project aims to…".
2. **One screenshot or output sample**, only if the project produces something visible.
3. **Install**: commands that can be copied as they are.
4. **Quick start**: one minimal working example with the output to expect.
5. **Usage**: the 3–5 most common tasks, each a short example. Not every flag or option.
6. **Configuration**: only the few settings most users change; link to the rest.
7. **Links**: deeper docs, contributing, license. One line each.

Weight by project type: a library leads with the import and a call; a CLI with the commonest invocation; a service with how to run it and reach it; a config or dotfiles repo with what it sets up and how to apply it.

## What stays out

| Content | Where it goes instead |
|---|---|
| Internal architecture, data flow, design rationale | `docs/` (module specs: the `documentation` skill) |
| Complete config, API or CLI reference | a reference page under `docs/`, or `--help` |
| Dev setup, testing, release process | `CONTRIBUTING.md` |
| Change history | `CHANGELOG.md` or git |
| Directory-by-directory tour, implementation details | nowhere; the code is the source |
| Roadmap, internal TODOs, known hacks | the issue tracker |

Also out: badge walls, marketing adjectives, a table of contents for a file this short, FAQ entries nobody has asked.

## Limits

- Budget: about 100 lines. Past that, cut a section down to a link before adding anything.
- Language: English by default, unless the user asks for another.
- Every command and example was run in this session and worked, or is marked as not verified in the report to the user. Never invent a flag, path or output.
- State prerequisites that actually block installation (runtime version, OS); skip the obvious ones.

## Procedure

1. Establish the reader and the project type. Find the real install and run commands from the project (manifest, Makefile, flake, CI), not from memory.
2. If a README exists, read it first. The default job is to cut and reorder, not to rewrite: keep wording that already works.
3. Draft to the skeleton.
4. Deletion pass: for each section and each paragraph, ask whether a first-time user would be stuck without it. If not, remove it.
5. Do not create files to hold what was removed. Delete it from the README and list it in the report: what was cut and where it would belong (per the table above), so the user decides whether to keep it.
6. Report in the chat: the line count, what was cut, and which commands were not verified.
