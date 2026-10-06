# Security

Lawn Wrangler is a static browser game: no accounts, no server, and the only
thing it stores is your best time, in your own browser.

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
- No third-party assets or Godot add-ons are used yet; any added later are
  listed with their source and license.
