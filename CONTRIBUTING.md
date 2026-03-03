# Contributing to dio_network_toolkit

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repo and clone your fork
2. Run `flutter pub get`
3. Run `flutter test` to make sure everything passes

## Making Changes

1. Create a branch from `main`: `git checkout -b feat/my-feature`
2. Make your changes
3. Add or update tests for your changes
4. Run `dart analyze --fatal-infos` — no warnings allowed
5. Run `flutter test` — all tests must pass
6. Commit with a clear message (e.g. `feat: add timeout config option`)

## Pull Requests

- Keep PRs focused on a single change
- Update CHANGELOG.md under an `## Unreleased` section
- Add dartdoc comments for any new public API
- Link any related issues

## Commit Style

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation only
- `refactor:` code change that neither fixes a bug nor adds a feature
- `test:` adding or updating tests
- `chore:` maintenance (deps, CI, etc.)

## Reporting Bugs

Use the [Bug Report](https://github.com/sagars-sachdev98/dio-network-toolkit/issues/new?template=bug_report.yml) template.

## Questions?

Open a [Discussion](https://github.com/sagars-sachdev98/dio-network-toolkit/discussions) or file an issue.
