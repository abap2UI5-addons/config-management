---
layout: home

hero:
  name: "Config Management"
  text: "Keep the settings of the abap2UI5 page in tables, not in code."
  image:
    src: /favicon.png
    alt: abap2UI5
  actions:
    - theme: brand
      text: Get started
      link: /guide
    - theme: alt
      text: GitHub
      link: https://github.com/abap2UI5-addons/config-management
    - theme: alt
      text: All addons
      link: https://abap2ui5-addons.github.io/

features:
  - title: "Configurable parameters: THEME, APP_TITLE, UI5_SRC, DEBUG_MODE, STYLES_CSS, CSP_POLICY"
  - title: "Configuration popup app z2ui5_cl_config_app with real-time theme preview"
  - title: "User-specific and global configuration with in-memory caching"
  - title: "Admin-only fields and a master user concept for UI5_SRC and CSP_POLICY"
  - title: "Authorization object Z2UI5_CONF with fields ACTVT and Z2UI5_CTYP"
  - title: "Theme compatibility matrix by UI5 version (table Z2UI5_T_30)"
---

## What it does

Theme, UI5 bootstrap source, custom CSS and Content-Security-Policy are kept in database tables and edited in a popup app; a user exit of your own applies them to every page abap2UI5 serves. It is for abap2UI5 administrators who want to change those settings at runtime without touching the HTTP handler. The service caches the configuration, supports user-specific and global values and keeps the abap2UI5 default wherever nothing is stored.

## Requirements

- Standard ABAP 7.50 or higher; NetWeaver 7.02 - 7.40 through the downported branch 702
- abap2UI5 1.145.0 or later
- ABAP Cloud: no (Standard ABAP only)
- UI5 1.118 or later for the theme preview; on older releases the saved theme applies with the next page load

## Installation

With [abapGit](https://abapgit.org), from [the repository](https://github.com/abap2UI5-addons/config-management):

- Install with abapGit in this order: abap2UI5, then this repository (branch main) next to abap2UI5; the HTTP handler stays as it is
- Implement the user exit interface z2ui5_if_ui5_exit in a class of your own and read the stored values via z2ui5_cl_config_service; abap2UI5 finds the class by the interface
- If a class implementing z2ui5_if_ui5_exit already exists, add the lines to that class, abap2UI5 calls one exit only
- Start the configuration app with ?app_start=z2ui5_cl_config_app; it fills the configuration tables with defaults on first start

The [Guide](/guide) has every step.

## A first app

```abap
METHOD z2ui5_if_ui5_exit~set_config_http_get.

  DATA(lv_theme) = z2ui5_cl_config_service=>get_current_theme( ).
  IF lv_theme IS NOT INITIAL.
    cs_config-theme = lv_theme.
  ENDIF.

  DATA(lv_src) = z2ui5_cl_config_service=>get_config( `UI5_SRC` ).
  IF lv_src IS NOT INITIAL.
    cs_config-src = lv_src.
  ENDIF.

ENDMETHOD.
```

## Links

- [The repository](https://github.com/abap2UI5-addons/config-management) - issues and pull requests welcome
