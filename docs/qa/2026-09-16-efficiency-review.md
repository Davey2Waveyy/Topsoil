# Efficiency review — September 16, 2026

## Applied improvements

- Code refreshes coalesce while Git work is outstanding. Results apply only to the same saved-project snapshot and activation generation. Unresolvable bookmarks retain their rows, keeping project actions aligned with storage.
- Git output is drained before waiting for process exit; stderr is discarded. This prevents a large status listing from filling its pipe and blocking forever.
- Launcher output is discarded instead of accumulating in unread pipes. Editor CLI completion and fallback run on a worker queue instead of blocking the main thread.
- Clipboard activation is idempotent, preventing duplicate poll timers. Clipboard and system timers receive scheduling tolerance without changing their nominal intervals.
- Quick Toggles AppleScript actions run off the main thread; repeated actions for the same control are ignored while outstanding. UI changes remain on the main actor, failures restore prior optimistic state, and obsolete mute reads cannot overwrite a newer action. Output drains before exit and nonzero exit codes count as failure. Repeated activation no longer duplicates observers.
- Stocks refresh and discovery cadence changes are documented in the implementation plan and accompanying tests.

## Review scope and retained behavior

Inspected module timers, detached tasks, synchronous process waits, local persistence reads, and folder scans. Media already gates its fallback/elapsed timers, timers schedule around actual work, and clipboard checks change count before fetching data. Local JSON store reads occur at initialization and were left intact; broad persistence rewrites would add risk without measured benefit. Git project probes remain serial within one utility task to avoid launching many processes at once.

No dependencies, features, or data formats were removed. No system toggle actions were executed during review.

## Validation and limits

New process regressions exercise discarded stdout/stderr larger than a pipe buffer and real Git status output from 1,200 long-named untracked files. The parent task coordinates all Swift builds and the full regression run; this review does not claim their results independently.

This is a targeted code review, not an Instruments benchmark or proof of globally optimal performance. OS permission dialogs and AppleScript integrations still depend on the user's system settings. External processes lack a timeout, so an unresponsive Git filesystem or AppleScript service can occupy a worker; coalescing and per-control guards prevent duplicate work but do not cancel the external process. Runtime mute/theme/Focus verification was intentionally left to an explicit user-driven check to avoid changing system settings.
