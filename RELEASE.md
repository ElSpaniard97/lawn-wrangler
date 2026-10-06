# Releasing Lawn Wrangler

## Release checklist

Each item from the improvement plan's release checklist, and what covers it.
"Test" means `godot/tests/run_tests.gd`, which runs before every deploy.

| Check | Covered by |
| --- | --- |
| Drive along fences and tree rings without passing through | Tests: mower stays in the yard, walker blocked by tree ring and parked mower |
| Safe dismount spot and remount range | Tests: hop off beside the mower, too far to hop on, hop back on when close |
| Cutting each cell counts once; blocked cells never count | Tests: cutting counts each cell once, blocked cells never count |
| 99% completion finishes once and saves the record | Test: finish once and record survives reload |
| Restart gives a fresh yard | Test: restart starts a fresh yard |
| Lost focus pauses and shows the pause screen | Test: lost focus pauses with pause screen |
| Blocked storage does not break finishing | Test: blocked storage still finishes |
| Resize keeps controls on screen | Test: resize keeps touch buttons on screen |
| Tampered save or settings files are ignored | Tests: saved record rejects bad data, bad settings fall back to defaults |
| No outside requests, no Content Security Policy violations | Browser check in Chromium before each release |
| Latest Chrome, Firefox and Safari on real hardware | By hand, see below |

### By hand, on the live site

Do these on a desktop browser and on a phone, after the deploy finishes:

1. The page loads, the game starts, and clicking or tapping inside it gives
   it the keyboard or touch.
2. Fullscreen from the button works, and leaving fullscreen restores the page.
3. Mow a few stripes, hop off, trim, hop back on, then press R or tap
   Restart.
4. Finish the yard, reload the page, and check the best time is still there.
5. Switch to another tab and back: the game is paused.
6. Press Q (desktop) and check the quality changes and stays after a reload.
7. In a private window, finish once more: the game should still finish and say
   the record lasts this session if the browser blocks saving.

## Rollback

Every push to `main` redeploys the site, so rolling back is a revert:

1. On GitHub, open the merged pull request that caused the problem and press
   **Revert**, then merge the revert pull request. The site redeploys the
   previous version once its tests pass.
2. Faster, without code changes: in **Actions**, open the last good
   "Publish game to GitHub Pages" run on `main` and choose **Re-run all
   jobs**. That rebuilds and redeploys that commit.

Known-good points to return to:

- `v1.0.0`: the first Godot release (tag it on the merge commit of the
  release pull request).
- `legacy-pygame-v1`: commit `cbd462d`, the last version with the original
  Python game at `/play/`. Its build needs `requirements.txt`, pygame-ce and
  pygbag as described in that commit's README.

To create a tag on GitHub: **Releases > Draft a new release > Choose a tag**,
type the tag name, pick the target commit, and publish.
