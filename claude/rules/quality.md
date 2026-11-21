# Quality

## Code

- Simplest thing that works (KISS, YAGNI); data structures first; remove duplication when it is real, not speculative.
- Idiomatic for the language: its naming, error handling and mutability conventions. Prefer immutable data where the language makes it natural.
- Early returns over deep nesting; named constants over magic numbers; focused functions (~50 lines) and cohesive files (~400 lines, 800 max).
- Handle errors explicitly; never swallow them. Validate untrusted input at system boundaries.
- Comments: default to none. Write one only for a why the code cannot show: a constraint, an invariant, a non-obvious trade-off. Never narrate what the code does or how it changed. Never excuse a shortcut in a comment (`TODO`, `HACK`, "for now", "workaround"): fix it, or report it as an open issue. Agents copy what they see, so a shortcut comment already in the code is a defect to remove, not a pattern to follow.

## Tests

- Every behavior change ships with a test that fails without the change; bug fixes start with the failing regression test.
- Test behavior, not implementation; no tests for cases that cannot happen. No global coverage quota: judge coverage of the changed code.
- Run the relevant tests (or `.claude/check`) before claiming done. Report failures with their output; never hide or skip them.
- If fixes start stacking on fixes, stop patching: re-read the failure from scratch and bring the root-cause question to the user.
