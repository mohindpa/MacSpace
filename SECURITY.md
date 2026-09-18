# Security Policy

## Scope

MacSpace is a local-network macOS bridge. It can inject keyboard and mouse
events, read and write the Mac clipboard, list running applications, and bring
an application to the front when the user requests those actions.

The bridge uses plain HTTP on the local network and protects control requests
with an access token. Do not expose port `8787` to the public internet or use
MacSpace on an untrusted network.

## Reporting a vulnerability

Please do not disclose security vulnerabilities in a public issue. Contact the
maintainer privately through [@mohindpa](https://github.com/mohindpa) or by
email at `hello@websitespa.net`, including:

- A description of the issue and its impact
- Steps to reproduce it
- A minimal proof of concept, when safe to provide
- Any suggested mitigation

Please allow reasonable time for investigation and a fix before public
disclosure.

## Supported versions

The latest version on the `main` branch is the supported development version.
Older releases may not receive security fixes.
