# Topsoil reliability and workspace plan

Approved direction: softer terminal frame with readable monospaced output and a persistent Today/Week agenda toggle.

Architecture: retain existing SwiftUI modules, native SwiftTerm sessions, and EventKit. Preserve last successful network content on failure, mark stale data explicitly, and keep saved project identity when bookmarks fail. No new dependencies or removals of existing features.

- [ ] Data reliability: StocksModel/StocksModule/StocksViews retain successful per-symbol quotes, distinguish failed versus empty repo results, coalesce refreshes, refresh trends and skill discovery less often, and display loading/stale states. CodeModule preserves unresolved pinned rows and ignores obsolete refresh results.
- [ ] Terminal: CodeViews/NotchTerminal retain native input and scrollback, reduce focus churn, soften framing and labels, and provide accessible scroll-to-bottom control. Verify scrollback and input without submitting agent prompts.
- [ ] Calendar: CalendarModel/CalendarModule/CalendarViews implement calendar-aware Today/Week intervals, a persisted segmented toggle, grouped scrollable agenda, and all-day/ongoing event handling. Compact views remain today summaries.
- [ ] Efficiency: inspect all module timers and blocking work; fix concrete redundant work and Git pipe deadlock, avoiding speculative broad rewrites. Document remaining risks.
- [ ] Validation: regression tests for partial/failed refreshes, selection changes, missing bookmarks, calendar boundaries and terminal scrollback; complete test runner, release build, UI checks where permissions permit.
