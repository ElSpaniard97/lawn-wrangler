# Security

Lawn Wrangler is a static browser game: no accounts, no server, and the only
thing it stores is your best time, in your own browser.

## Reporting a problem

If you find a security issue, please report it privately through
[GitHub's private vulnerability reporting](https://github.com/ElSpaniard97/lawn-wrangler/security/advisories/new)
instead of opening a public issue.

## How the project is protected

- GitHub Actions are pinned to full commit SHAs, and Python packages are pinned
  with hashes in `requirements.txt`. Dependabot proposes updates.
- Tests must pass before the site builds and deploys.
- The landing page sets a Content Security Policy that only allows its own
  inline script and the game frame from this site.
- The saved best time is parsed as JSON and ignored unless it is a positive,
  finite number.
