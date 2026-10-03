# Contributing

config-management stores abap2UI5's page settings (theme, UI5 bootstrap
source, custom CSS, Content-Security-Policy) in database tables, and brings a
popup app to edit them.

## Before you open a pull request

Run what CI runs:

```sh
npm ci
npm run check
```

`npm run check` runs the same steps as the `abap-standard` workflow on a
pull request, so a green run locally means a green run there. `npm test` is
an alias for it. This repository has no separate unit-test suite: its ABAP is
checked, not executed.

## What the gates are

| Gate | What it proves |
| --- | --- |
| `npm run lint` | abaplint: syntax at ABAP 7.50, checked against the abap2UI5 core's `main` branch and the SAP API stubs |

abaplint does not run the code. Changes to authorization checks, database
access or the configuration app's behaviour still need a test on an SAP
system. Say in the pull request whether you made one.

## Conventions

English for code, comments, commit messages and pull requests. Write commit
subjects in the imperative and describe the outcome, not the mechanics. One
topic per pull request. The rules specific to this repository are in
[AGENTS.md](AGENTS.md). The rules the whole ecosystem follows are in
[abap2UI5's CONVENTIONS.md](https://github.com/abap2UI5/abap2UI5/blob/main/.github/shared/CONVENTIONS.md).
