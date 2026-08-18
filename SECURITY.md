# Security Policy

## Reporting a Vulnerability

Do **not** open a public issue for security vulnerabilities. Report them
privately via GitHub's Security Advisories: open **Security → Report a
vulnerability** on this repository, or email the maintainers at
`security@devstroop.example.com` (replace with the real address).

Please include:

- The action version affected (or the commit SHA)
- A minimal reproduction
- Impact description

We aim to acknowledge reports within 2 business days and ship a fix in the
next release.

## Security properties of this action

- Every download is verified against the SHA-512 hash published in the
  official dotnetcli release metadata before extraction. Do not disable or
  bypass this check.
- The action is a composite script (`scripts/*`) with no third-party code
  executed; only the official `actions/cache` actions are invoked.
- Inputs (including `version`) are used as configuration, not shell input.