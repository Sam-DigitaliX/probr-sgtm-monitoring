# CLAUDE.md — probr-sgtm-monitoring

## What this repo is

Google Tag Manager Community Template Gallery repository for the **Probr Server-Side Listener** tag.
One template, one repo — as required by the GTM Gallery spec.

## Stack

- **Runtime**: GTM Sandboxed JavaScript for Server (not browser JS, not Node)
- **Sandbox APIs used**: `addEventCallback`, `sendHttpRequest`, `getEventData`, `getContainerVersion`, `getTimestampMillis`, `JSON`, `logToConsole`, `templateDataStorage`, `makeInteger`, `makeString`, `getType`
- **No build step, no dependencies, no package manager**
- Template is edited via the GTM Template Editor then exported as `.tpl`

## Repo structure

```
probr-sgtm-monitoring/
├── LICENSE              # Apache 2.0 (required by Gallery, filename ALL CAPS)
├── metadata.yaml        # Gallery metadata: homepage, docs URL, versions + SHA
├── template.tpl         # The exported sGTM tag template
├── images/
│   └── probr_logo.webp  # Logo used in README
└── README.md            # User-facing documentation
```

All files must stay at root level. Only one `template.tpl` per repo. The Gallery scanner reads `main` branch only.

## template.tpl structure

The `.tpl` file is a GTM export format with these sections (in order):

| Section | Content |
|---------|---------|
| `___TERMS_OF_SERVICE___` | Google ToS agreement text (do not modify) |
| `___INFO___` | JSON: type, id, version, brand, description, categories |
| `___TEMPLATE_PARAMETERS___` | JSON array: UI fields shown to the user |
| `___SANDBOXED_JS_FOR_SERVER___` | The tag logic (sandboxed JS) |
| `___SERVER_PERMISSIONS___` | JSON array: required sandbox permissions |

## Tag behavior

1. On every sGTM event, `addEventCallback` fires after all tags execute
2. Collects: tag results (status, exec time), event name, user data presence, ecommerce presence
3. Sends data to the configured Probr endpoint via `sendHttpRequest` POST
4. Two send modes:
   - **Per event** (default): one HTTP request per event, real-time
   - **Batched**: buffers in `templateDataStorage`, flushes at N events (default 50)
5. `data.gtmOnSuccess()` is called immediately — the tag is non-blocking

## Template parameters (UI fields)

| Name | Type | Required | Default |
|------|------|----------|---------|
| `probrEndpoint` | TEXT | Yes | — |
| `probrApiKey` | TEXT | Yes | — |
| `trackUserData` | CHECKBOX | No | `true` |
| `excludeTagIds` | TEXT | No | `""` |
| `sendMode` | SELECT | No | `per_event` |
| `batchSize` | TEXT | No | `"50"` (shown only when sendMode=batched) |

## Permissions declared

`send_http` (any URL), `read_event_data` (any key), `access_template_storage`, `read_container_data`, `logging` (debug).

## Categories

`ANALYTICS`, `UTILITY` — these are the only two. Do NOT use `MONITORING` (not a valid Gallery category).

## metadata.yaml

- `versions[].sha` must point to a commit on `main` that contains the `template.tpl` being published
- After any template change: commit, copy the full SHA, add a new entry at the top of `versions`
- Gallery picks up changes in 2-3 days

## Current state

- **Version**: 1.0.0 (initial release)
- **Gallery submission**: not yet submitted
- **metadata.yaml SHA** (`b2f4213d...`): points to the commit that added `template.tpl` — exists on `main`

### Before Gallery submission (TODO)

1. Add copyright line to `LICENSE`: `Copyright 2025 DigitaliX`
2. Import template in GTM Template Editor, check "Agree to ToS" box, re-export (modifies the file)
3. Update `metadata.yaml` SHA after the re-export commit
4. Verify GitHub Issues are enabled on the repo
5. Submit at tagmanager.google.com/gallery > Submit Template

## Conventions

- **Commit messages**: `feat:`, `fix:`, `docs:` prefixes (conventional commits style)
- **Branch naming**: `claude/<description>-<id>` for Claude Code sessions
- **template.tpl**: never hand-edit the `___TERMS_OF_SERVICE___` or `___INFO___` JSON structure — use the GTM Template Editor, then export
- **Sandboxed JS**: no ES6+ features beyond `const`/`let` — the sandbox is limited. Use `var` in loops. No arrow functions, no destructuring, no template literals.

## Decisions taken

| Decision | Rationale |
|----------|-----------|
| Categories `ANALYTICS` + `UTILITY` instead of `MONITORING` | `MONITORING` is not a valid Gallery category |
| `allowedUrls: "any"` for `send_http` | Endpoint is user-configured, cannot be hardcoded |
| `data.gtmOnSuccess()` called before callback | Tag must be non-blocking — monitoring should never delay other tags |
| Batched mode uses `templateDataStorage` | Only persistence available in sGTM sandbox; scoped per instance, lost on restart |
| Ecommerce checks limited to 4 events | `purchase`, `begin_checkout`, `add_to_cart`, `add_payment_info` are the GA4 events that carry ecommerce data |
