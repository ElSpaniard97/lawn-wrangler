# Security

Lawn Wrangler is a static browser game: no accounts, no server, and the only
things it stores are your best time and your quality and sound settings, in
your own browser.

## Reporting a problem

If you find a security issue, please report it privately through
[GitHub's private vulnerability reporting](https://github.com/ElSpaniard97/lawn-wrangler/security/advisories/new)
instead of opening a public issue.

## How the project is protected

- GitHub Actions are pinned to full commit SHAs, and Dependabot proposes
  updates.
- Godot and its web export template are downloaded from the official release
  and checked against pinned SHA-512 sums before every build.
- Tests must pass before the site builds and deploys.
- The landing page sets a Content Security Policy that only allows its own
  inline script and the game frame from this site.
- The saved best time is plain JSON and is ignored unless it is a positive,
  finite number.
- Saved settings are JSON too; any value that is not one of the expected
  choices is ignored.
- No third-party assets or Godot add-ons are used: every model and sound is
  generated in code. Any added later must be listed with source and license.
