---
name: git-workflow
description: Git workflow standards. Apply when committing changes, creating pull requests, or managing branches.
---

# Git Workflow Standards

## Commit Message Format

Follow Conventional Commits strictly:

```
<type>(<scope>): <subject>
```

Subject line only: no body, no footer. Include a scope whenever one fits; it is preferred, not required.

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change without fixing bug or adding feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `chore`: Maintenance tasks
- `build`: Build system or dependency changes
- `ci`: CI/CD configuration changes

**Examples**:
```
feat(auth): add OAuth2 login flow
fix(payment): handle Stripe webhook retries
chore(nix): bump flake inputs
```

## Commit Rules

1. **Subject line max 50 chars**
2. **Imperative mood**: "Add feature" not "Added feature" or "Adds feature"
3. **No period at end of subject**
4. **No body or footer**: the subject says what changed; the why belongs in the PR or the code
5. **Scope preferred**: `fix(auth): …` over `fix: …` when a scope fits

## Enforcement (auto-blocked)

A PreToolUse hook (`~/.claude/hooks/conventional-commit/validate.sh`) validates
the subject line of every `git commit` you run and **blocks it (exit 2)** when it
does not conform. Get the format right on the FIRST attempt — do not commit and
wait to be rejected.

The hook enforces, on the subject line only:

- Pattern `type(scope): description`; scope is preferred but **not enforced** (`feat: ...` passes)
- `type` must be one of: `feat fix refactor chore docs style test build ci perf`
- Subject length **≤ 50 chars**
- **No trailing period**

The hook does not check for a body; leaving it out is on you.
Before committing, mentally check the subject against these four rules.

## Branch Strategy

```
main
  ├─ feature/<feature-name>
  ├─ fix/<bug-description>
  ├─ hotfix/<urgent-fix>
  └─ refactor/<description>
```

**Rules**:
- **main**: commit directly by default; branch only when the work needs isolation or the repo requires a PR
- **feature branches**: optional; delete after merge
- **branch naming**: Lowercase, kebab-case, descriptive
- **branch lifespan**: Max 2 weeks, else split or abandon

## Pull Request Standards

### PR Title
Follow commit format, include PR number:
```
feat(auth): add OAuth2 login flow (#42)
```

### PR Description Template

```markdown
## Summary
[Bullet points, 2-3 lines max]

## Changes
- File A: What changed
- File B: What changed

## Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing done

## Breaking Changes
[List any breaking changes or "None"]

## Screenshots (if applicable)
```

### PR Review Rules

1. **At least 1 reviewer approval** before merge
2. **All checks must pass** (CI/CD, tests, linting)
3. **Address all review comments** before requesting re-review
4. **Squash commits** when merging to main

## Git Best Practices

- **Amend only**: If commit not pushed, use `--amend` to fix typos
- **Never force push to main**
- **Use .gitignore religiously**: Never commit:
  - `.env`, `.env.local`
  - `node_modules/`, `dist/`, `build/`
  - IDE files (`.vscode/`, `.idea/`)
  - OS files (`.DS_Store`, `Thumbs.db`)
- **Rebase before PR**: Keep branch up-to-date with main
- **Atomic commits**: Each commit should be a logical unit, can be reverted independently
