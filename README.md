# config-management

This enhancement replaces hard-coded HTTP handler configurations with a flexible, database-driven configuration system that allows runtime customization of UI5 application settings.  

## Installation

Requires abap2UI5 1.145.0 or later. Install this repository with abapGit next to abap2UI5 - the HTTP handler stays as it is.

abap2UI5 reads the settings of its page from its user exit, `z2ui5_if_ui5_exit`. Implement the interface in a class of your own - abap2UI5 finds the class by the interface, there is nothing to register - and let it apply the stored configuration:
```abap
CLASS zcl_my_abap2ui5_exit DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_ui5_exit.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_my_abap2ui5_exit IMPLEMENTATION.

  METHOD z2ui5_if_ui5_exit~set_config_http_get.

    " cs_config arrives filled with the abap2UI5 defaults - a value is only
    " replaced when one is stored, so an empty entry keeps the default
    DATA(lv_theme) = z2ui5_cl_config_service=>get_current_theme( ).
    IF lv_theme IS NOT INITIAL.
      cs_config-theme = lv_theme.
    ENDIF.

    DATA(lv_src) = z2ui5_cl_config_service=>get_config( `UI5_SRC` ).
    IF lv_src IS NOT INITIAL.
      cs_config-src = lv_src.
    ENDIF.

    DATA(lv_styles_css) = z2ui5_cl_config_service=>get_config( `STYLES_CSS` ).
    IF lv_styles_css IS NOT INITIAL.
      cs_config-styles_css = lv_styles_css.
    ENDIF.

    " the complete <meta http-equiv="Content-Security-Policy" ...> tag
    DATA(lv_csp) = z2ui5_cl_config_service=>get_config( `CSP_POLICY` ).
    IF lv_csp IS NOT INITIAL.
      cs_config-content_security_policy = lv_csp.
    ENDIF.

  ENDMETHOD.

  METHOD z2ui5_if_ui5_exit~set_config_http_post.
  ENDMETHOD.

ENDCLASS.
```

- abap2UI5 calls one exit only. If your system already has a class implementing `z2ui5_if_ui5_exit`, add the lines above to that class instead.
- `set_config_http_get` runs for every response, not only for the page request - the response headers come from it too. `z2ui5_cl_config_service` caches the configuration, so that costs one table read per request.
- The fields of `z2ui5_if_ui5_exit=>ty_s_http_config` are `src`, `theme`, `content_security_policy`, `styles_css`, `t_add_config` and `t_security_header`. The `title` field is gone (removed in abap2UI5 1.145.0, the page carries a constant `<title>`), so `APP_TITLE` is not applied by the exit. An app that wants it as its browser tab title sets it while it runs:
```abap
client->follow_up_action( val   = client->cs_event-set_title
                          t_arg = VALUE #( ( z2ui5_cl_config_service=>get_config( `APP_TITLE` ) ) ) ).
```

Open the configuration app like any abap2UI5 app - `?app_start=z2ui5_cl_app_icf_config` on your abap2UI5 ICF path, or its class name on the abap2UI5 start page. It fills the configuration tables with their defaults on its first start.

## Demo

![466231499-ebaa079d-8f53-483f-be75-e40e9a4dc7c9](https://github.com/user-attachments/assets/d2b1d0ba-4343-47b1-96f4-ff53c3a5e4d7)


## Information

### Core Configuration Service  
- **z2ui5_cl_config_service**: Central service for managing application configurations  
  - User-specific and global configuration support  
  - In-memory caching for performance  
  - Authority-based access control (master user vs regular user)  
  - Automatic fallback to framework defaults  
  
### Configuration App  
- **z2ui5_cl_app_icf_config**: The configuration popup  
  - Theme selection from the themes of the running UI5 release (`Z2UI5_THEMES`)  
  - Real-time theme preview with global application, reverted on Cancel  
  - Form-based editing for all configurable parameters  
  - Role-based field visibility (admin-only fields)  
  - Automatic initialization of default configurations  
  
### User Exit  
- **your `z2ui5_if_ui5_exit` class** (see Installation): Applies the stored configuration to every page abap2UI5 serves  
  - Replaces hard-coded values with dynamic database lookups  
  - Keeps the abap2UI5 default wherever nothing is stored  
  
## Database Objects:  
- **Z2UI5_CONFIG**: Main configuration table with user/global scope support  
- **Z2UI5_THEMES**: UI5 theme compatibility matrix by version  
- **Z2UI5_CONF**: Message class for configuration-related messages  
- **Z2UI5_CX_CONFIG_ERROR**: Exception class for configuration errors  
  
## Security & Authorization:  
- **Z2UI5_CONF**: Authorization object with ACTVT and CONFIG_TYPE fields  
- Master user concept for sensitive configurations (UI5_SRC, CSP_POLICY)  
- Configuration locking mechanism for system-critical settings  
  
## Configurable Parameters:  
- **THEME**: UI5 theme with version-specific compatibility  
- **APP_TITLE**: Application title - stored for apps to set as tab title, the exit has no title field (see Installation)  
- **UI5_SRC**: UI5 bootstrap source URL (admin-only)  
- **DEBUG_MODE**: Debug mode toggle  
- **STYLES_CSS**: Custom CSS injection  
- **CSP_POLICY**: Content Security Policy (admin-only) - the complete `<meta http-equiv="Content-Security-Policy" ...>` tag  
  
## Technical Implementation:  
- ABAP 7.30+ compatible with proper error handling  
- Efficient caching strategy to minimize database calls    
- Theme preview through the whitelisted frontend action `THEMING` / `setTheme` (`client->cs_event-control_global`) - abap2UI5 no longer runs raw JavaScript such as `sap.ui.getCore().applyTheme()`. It needs UI5 1.118 or later; on an older release the saved theme applies with the next page load  
- Released abap2UI5 API (`src/02`) only: views built with `z2ui5_cl_ui5_view_builder`, no frozen `src/99` classes such as `z2ui5_cl_xml_view` or `z2ui5_cl_pop_to_select`  
- Transaction-safe with COMMIT WORK AND WAIT and rollback on errors  
  
## Benefits:  
- Eliminates need to modify HTTP handler code for configuration changes  
- Enables per-user customization (themes, custom CSS, etc.)  
- Provides secure admin-only controls for system-level settings  
- Maintains framework performance through intelligent caching  
- Supports UI5 theme compatibility validation  
  
This enhancement significantly improves the flexibility and maintainability   
of abap2UI5 installations by moving configuration from code to database,  
while maintaining full backward compatibility.  
  
Tested on: ABAP 7.30  
Target: main branch (ABAP 7.5+) with automatic 702 downporting
