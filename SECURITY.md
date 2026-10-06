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
- No Godot add-ons or outside scripts are used, and every model and sound is
  generated in code. The only outside assets are plain JPEG photo textures,
  each listed with its source in [ASSET_LICENSES.md](ASSET_LICENSES.md); a
  test fails the build if the game uses one that is not listed.
