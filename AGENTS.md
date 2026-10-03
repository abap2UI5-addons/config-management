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
| `z2ui5_cl_config_service` | The service: `get_config` (user value, then global value, then default), `set_config`, `get_current_theme`, `get_theme_list`, `initialize_default_configs`, `is_master_user`, `check_config_authority`. Values are cached in `gt_config_cache` |
| `z2ui5_cl_app_icf_config` | The configuration app (`z2ui5_if_app`), shown as a popup |
| `z2ui5_cx_config_error` | Exception class of the service |
| `Z2UI5_CONFIG` | Configuration table, keyed by client, `CONFIG_KEY` and `USER_ID` (empty = global) |
| `Z2UI5_THEMES` | UI5 themes by UI5 version |
| `Z2UI5_CONF` (MSAG) | Message class |
| `Z2UI5_CONF` (SUSO) | Authorization object, fields `ACTVT` and `CONFIG_TYP` |
| `CONFIG_TYP` (AUTH) | The authorization field, `CHAR10` |

## Rules

- **Keep the name and shape of `z2ui5_cl_app_icf_config`.** abap2UI5's own
  start page opens it by name: `z2ui5_cl_ui5_app_start` holds the constant
  `c_class_icf_config` = `Z2UI5_CL_APP_ICF_CONFIG`, runs
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
  the built-in `THEME` default `sap_horizon`).
- **`UI5_SRC` and `CSP_POLICY` are master-user settings.** The app lets a
  user edit and save them only when `is_master_user( )` passes
  (authorization object `Z2UI5_CONF` with `ACTVT` `02`). Everyone else sees
  them read-only. `set_config` refuses a change to a locked global entry
  from anyone but a master user. Do not widen either.
- **Name the authorization field as the object defines it.**
  `Z2UI5_CONF`'s second field is `CONFIG_TYP` (10 characters, the maximum
  for an authorization field). The two `AUTHORITY-CHECK` statements in
  `z2ui5_cl_config_service` currently name `ID 'CONFIG_TYPE'`. That mismatch
  is known and open. Fix it on a system where the check can be tried, not
  blind.

## Dependencies

- [abap2UI5](https://github.com/abap2UI5/abap2UI5): the framework.
- [abaplint/deps](https://github.com/abaplint/deps): the SAP standard API
  stubs for the syntax check.

`abaplint.jsonc` gives the abap2UI5 dependency **no version pin**, so abaplint
clones its `main` branch. The comment in `abaplint.jsonc` says so on purpose:
the check also notices when an upstream rename breaks this addon. That is
why `abap-standard` also runs weekly, when no pull request is open.

## Build and verify

```sh
npm ci
npm run check   # abaplint ./abaplint.jsonc, at v750, 0 issues expected
```

`npm run check` runs what CI runs: the `abap-standard` workflow
(`.github/workflows/abap-standard.yaml`) runs `npm ci` and
`npx abaplint ./abaplint.jsonc` on every push to `main`, on every pull
request, weekly, and by hand. `npm test` is an alias of `npm run check`: the
ABAP here is checked, not executed.

This repository has no abap2UI5-linter gate, no ABAP Cloud lint and no 702
downport workflow. The README's "automatic 702 downporting" has nothing here
behind it yet.

## Conventions

- All text files are LF-only.
- The ecosystem-wide rules (workflow and npm-script naming, toolchain
  versions, which documentation files exist, commit style) live in
  [CONVENTIONS.md](https://github.com/abap2UI5/abap2UI5/blob/main/.github/shared/CONVENTIONS.md)
  and bind this repository too.
