# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Email security reports to: [your-security-email@example.com](mailto:your-security-email@example.com)
(Replace with a real monitored address before publishing.)

Include:
- Description of the vulnerability
- Steps to reproduce
- Impact assessment
- Any known mitigations

We aim to acknowledge reports within 72 hours and provide a fix timeline within 7 days.

## Production Configuration

This app is designed to be deployed with environment-based secrets. **Never** commit:
- `JWT_SECRET` or any signing keys
- API tokens (Replicate, Supabase, OpenWeather, LLM providers)
- Database connection strings with credentials
- The actual `.env` file (use `.env.example` as a template)

Always:
- Set `JWT_SECRET` to a 32+ byte random value (`openssl rand -hex 32`)
- Use HTTPS in production (the Go API gateway runs HTTP by default; terminate TLS at a reverse proxy)
- Run Docker containers as a non-root user (compose is configured with `user: "1000:1000"`)
- Keep `BEASISWA_LLM_ENDPOINT` and `MCP_TRADE_HTTP_TIMEOUT` set via env, not defaults
