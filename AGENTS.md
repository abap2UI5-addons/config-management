# AGENTS.md — config-management

Single source of truth for agents working on **config-management**: an addon
that stores abap2UI5's page settings (theme, UI5 bootstrap source, custom CSS,
Content-Security-Policy) in database tables instead of in code. It also
brings a popup app to edit them. `CLAUDE.md` next to this file is a pointer
at it, nothing more.

**Language:** English for code, comments, commit messages, pull requests and
issues.

## What this repository is

A **source** repository in the abap2UI5-addons organisation: humans and agents
edit here. It is installed with abapGit (`.abapgit.xml`: `STARTING_FOLDER`
`/src/`, `FOLDER_LOGIC` `PREFIX`) next to
[abap2UI5](https://github.com/abap2UI5/abap2UI5), which it needs at runtime.
The README says abap2UI5 1.145.0 or later.

The addon does not hook into abap2UI5 by itself. The README tells the user
to write their own class implementing `z2ui5_if_ui5_exit`, and that class
reads the stored values in `set_config_http_get`. The README's example of
that class is the contract with users. A change to what
`z2ui5_cl_config_service` offers is checked against that example and
updated in the same pull request.

## Layout

Everything is in `src/`, one package:

| Object | |
|---|---|
| `z2ui5_cl_config_service` | The service: `get_config` (user value, then global value, then default; global only for `UI5_SRC` and `CSP_POLICY`), `set_config`, `get_current_theme`, `get_theme_list`, `initialize_default_configs`, `is_master_user`, `check_config_authority`. Values are cached in `gt_config_cache` |
| `z2ui5_cl_config_app` | The configuration app (`z2ui5_if_app`), shown as a popup |
| `z2ui5_cx_config_error` | Exception class of the service |
| `Z2UI5_T_29` | Configuration table, keyed by client, `CONFIG_KEY` and `USER_ID` (empty = global) |
| `Z2UI5_T_30` | UI5 themes by UI5 version |
| `Z2UI5_CONF` (MSAG) | Message class |
| `Z2UI5_CONF` (SUSO) | Authorization object, fields `ACTVT` and `Z2UI5_CTYP` |
| `Z2UI5_CTYP` (AUTH) | The authorization field, `CHAR10` |

## Rules

- **Keep the name and shape of `z2ui5_cl_config_app`.** abap2UI5's own
  start page opens it by name: `z2ui5_cl_ui5_app_start` holds the constant
  `c_class_icf_config` = `Z2UI5_CL_CONFIG_APP` (and falls back to
  `Z2UI5_CL_APP_ICF_CONFIG`, the class's name up to 2026-11), runs
  `CREATE OBJECT ... TYPE (c_class_icf_config)` with no parameters, and calls
  `nav_app_call` with the result. The name is listed in abap2UI5's
  `dynamic-name-gate.mjs` as one that ships here. A rename, a mandatory
  constructor parameter or dropping `z2ui5_if_app` silently turns that button
  into "The configuration app is not installed on this system".
- **Use the released abap2UI5 API only.** Views are built with
  `z2ui5_cl_ui5_view_builder`. No frozen classes from abap2UI5's `src/99`
  (`z2ui5_cl_xml_view`, `z2ui5_cl_pop_to_select`, ...). The README promises
  this.
- **No raw JavaScript to the frontend.** The theme preview runs the
  whitelisted frontend action: `client->cs_event-control_global` with
  `THEMING` / `setTheme`. abap2UI5 does not run code such as
  `sap.ui.getCore( ).applyTheme( )`.
- **An unset value keeps abap2UI5's default.** The exit in the README
  replaces a field of `cs_config` only when a value is stored. Keep
  `get_config` returning an empty string for a key nobody set (apart from
  the built-in `THEME` default `sap_horizon`). So `initialize_default_configs`
  seeds neither `UI5_SRC` nor `CSP_POLICY` - the app names abap2UI5's
  default as a placeholder instead. Up to 2026-11 it seeded `UI5_SRC` with
  the OpenUI5 CDN, which the ABAP Cloud CSP refuses; `get_config` ignores
  that row while it is untouched (`is_legacy_seed`) rather than deleting it.
- **`UI5_SRC` and `CSP_POLICY` are master-user settings.** The app lets a
  user edit and save them only when `is_master_user( )` passes
  (authorization object `Z2UI5_CONF` with `ACTVT` `02`). Everyone else sees
  them read-only. `set_config` refuses a change to a locked global entry
  from anyone but a master user. Do not widen either.
- **`UI5_SRC` and `CSP_POLICY` are system-wide.** They decide how every
  page boots, so they exist once, for everybody: `set_config` stores them
  without a user (whatever `iv_user_id` says), keeps them locked and takes
  them from master users only, and `get_config` reads only the global
  value for them. Earlier versions saved a master user's change for that
  master user alone; such a user row is ignored now.
- **Name the authorization field as the object defines it.**
  `Z2UI5_CONF`'s second field is `Z2UI5_CTYP` (10 characters, the maximum
  for an authorization field), and both `AUTHORITY-CHECK` statements in
  `z2ui5_cl_config_service` name `ID 'Z2UI5_CTYP'`. Until
  [#7](https://github.com/abap2UI5-addons/config-management/pull/7) they
  named `ID 'CONFIG_TYPE'`, a field the object does not have: for such a
  field the check is not possible and `sy-subrc` is 4, so every user was
  denied. Up to 2026-11 the field itself was `CONFIG_TYP`, outside the
  customer namespace (a customer authorization field starts with Y or Z).
  Field, object and checks change together, never one of them alone.

## Dependencies

- [abap2UI5](https://github.com/abap2UI5/abap2UI5): the framework.
- [abaplint/deps](https://github.com/abaplint/deps): the SAP standard API
  stubs for the syntax check.

`abaplint.jsonc` gives the abap2UI5 dependency **no version pin**, so abaplint
clones its `main` branch. The comment in `abaplint.jsonc` says so on purpose:
the check also notices when an upstream rename breaks this addon. That is
why `ci` also runs weekly, when no pull request is open.

## Build and verify

```sh
npm ci
npm run check   # abaplint Standard (v750), the 7.02 downport and Cloud, then the abap2UI5-linter - 0 issues expected
```

`npm test` is an alias of `npm run check`: the ABAP here is checked, not
executed.

## CI

CI comes from the shared CI template of abap2UI5-addons (reusable workflows in
[rap-ext](https://github.com/abap2UI5-addons/rap-ext/blob/main/.github/ci/README.md),
pinned by commit in the `uses:` lines and moved by `bump-deps`):

* `ci` - on every push to `main`, every pull request, weekly and by hand,
  one job per check: abaplint against Standard ABAP (`abaplint.jsonc`, v750)
  and ABAP Cloud (`.github/abaplint/abap_cloud.jsonc`, released APIs only),
  and `abap2ui5lint` - the app class and its views (`abap2ui5lint.jsonc`,
  UI5 1.71 floor, render gate on), and `npm run check:702` - the 7.02 gate
  of a pull request (`.github/scripts/check-702.sh` downports a scratch copy
  of `src/` in `build/702` and lints it with `.github/abaplint/abap_702.jsonc`;
  `src/` is never rewritten). On `main` the linter's two README badges
  are published to the branch `badges`. There are no ABAP Unit tests and no
  rename script here, so no `unit` and no `rename` job.
* `ci-702` - on every push to `main` `npm run auto_downport` (against
  `.github/abaplint/abap_702.jsonc`), a force-push of the result to the
  branch `702`, then abaplint on that branch. Never commit to `702` by hand.
* `deploy-pages` (the site), `bump-deps` (monthly; the template pin moves only
  with the `DEPS_TOKEN` secret).

The addon builds on no sibling addon, so there is no `.github/deps.json`.
The required status checks of the branch protection are `check / abaplint
(./abaplint.jsonc)`, `check / abaplint (.github/abaplint/abap_cloud.jsonc)`
and `check / abap2ui5lint` (`check / npm run check:702` is new and not yet
among them).

## Conventions

- All text files are LF-only, enforced by `.gitattributes`.
- `bump-deps.yaml` moves every dependency once a month, on the last Sunday,
  in one pull request (`.github/scripts/update-deps.mjs`). Third-party actions are pinned to a
  commit SHA, with the version in a trailing comment.
- The ecosystem-wide rules (workflow and npm-script naming, toolchain
  versions, which documentation files exist, commit style) live in
  [CONVENTIONS.md](https://github.com/abap2UI5/abap2UI5/blob/main/.github/shared/CONVENTIONS.md)
  and bind this repository too.
