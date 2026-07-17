# Security Policy

## Reporting a vulnerability

If you discover a security issue, use the repository's
**Security → Advisories → Report a vulnerability** workflow.

Before disclosure, please include:

- A short description of the issue
- Steps to reproduce (if applicable)
- Version/build you tested on
- Potential impact

Please avoid posting sensitive security details in public issues until we can review it.
Do not include credentials, prompts, replies, attachments, raw session rows,
or complete app-server responses in a report.

## Scope

Codex Limit Peek starts the local `codex app-server` executable to request current rate limits. The Codex CLI uses its existing signed-in context; Codex Limit Peek does not read or manage credentials directly.

When the app-server is unavailable, Codex Limit Peek may read recent quota records from:

- `~/.codex/logs_2.sqlite`
- `~/.codex/sessions`
- `~/.codex/archived_sessions`

Codex Limit Peek does not read `auth.json`, Keychain items, browser cookies, prompt bodies, replies, or attachments. It does not log raw app-server responses, SQLite rows, or JSONL lines, and it does not make direct HTTP requests.
