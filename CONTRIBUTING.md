# Contributing to MacSpace

Thanks for helping improve MacSpace.

## Before opening an issue

- Check the README and existing issues first.
- Include your macOS version, Mac architecture, and the steps that reproduce
  the problem.
- Never include access tokens, clipboard contents, private screenshots, or
  other sensitive information in an issue.

## Development

MacSpace currently builds with the macOS Swift toolchain:

```bash
./build.sh
```

Run the available checks before opening a pull request:

```bash
./test-caps.sh
./test-e2e.sh
```

These tests require macOS and Accessibility permission. Test only on a
machine where generated keyboard and mouse input is safe.

## Pull requests

- Keep changes focused and explain the user-visible impact.
- Update the README when behavior or setup changes.
- Add or update tests when practical.
- Do not commit tokens, logs, build output, or personal data.
