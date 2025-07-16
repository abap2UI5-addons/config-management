# config-management

This enhancement replaces hard-coded HTTP handler configurations with a flexible, database-driven configuration system that allows runtime customization of UI5 application settings.  

## Installation

Use in your abap2UI5 http handler the following handler class:
```abap
  METHOD if_http_extension~handle_request.
    DATA(ls_config) = VALUE z2ui5_if_types=>ty_s_http_config( ).

    " Load configurations from your service instead of hardcoded defaults
    IF ls_config-title IS INITIAL.
      ls_config-title = z2ui5_cl_config_service=>get_config( 'APP_TITLE' ).
      IF ls_config-title IS INITIAL.
        ls_config-title = 'abap2UI5'. " Final fallback
      ENDIF.
    ENDIF.

    IF ls_config-theme IS INITIAL.
      ls_config-theme = z2ui5_cl_config_service=>get_current_theme( ).
      IF ls_config-theme IS INITIAL.
        ls_config-theme = 'sap_horizon'. " Final fallback
      ENDIF.
    ENDIF.

    IF ls_config-src IS INITIAL.
      ls_config-src = z2ui5_cl_config_service=>get_config( 'UI5_SRC' ).
      IF ls_config-src IS INITIAL.
        ls_config-src = `https://sapui5.hana.ondemand.com/1.120.32/resources/sap-ui-core.js`.
      ENDIF.
    ENDIF.

    IF ls_config-styles_css IS INITIAL.
      ls_config-styles_css = z2ui5_cl_config_service=>get_config( 'STYLES_CSS' ).
    ENDIF.

    IF ls_config-content_security_policy IS INITIAL.
      ls_config-content_security_policy = z2ui5_cl_config_service=>get_config( 'CSP_POLICY' ).
    ENDIF.

    " Initialize default configs if tables are empty
    z2ui5_cl_config_service=>initialize_default_configs( ).

    " Call the HTTP handler with the loaded configuration
    z2ui5_cl_http_handler=>run( server = server
                                config = ls_config ).
  ENDMETHOD.
```

## Demo

![466231499-ebaa079d-8f53-483f-be75-e40e9a4dc7c9](https://github.com/user-attachments/assets/d2b1d0ba-4343-47b1-96f4-ff53c3a5e4d7)


## Information

### Core Configuration Service  
- **z2ui5_cl_config_service**: Central service for managing application configurations  
  - User-specific and global configuration support  
  - In-memory caching for performance  
  - Authority-based access control (master user vs regular user)  
  - Automatic fallback to framework defaults  
  
### Enhanced Startup Application    
- **z2ui5_cl_app_startup**: Extended with configuration management UI  
  - Configuration popup with theme selection via value help  
  - Real-time theme preview with global application  
  - Form-based editing for all configurable parameters  
  - Role-based field visibility (admin-only fields)  
  
### Dynamic HTTP Handler  
- **zcl_abap2ui5_http_handler**: Custom HTTP extension that loads configurations  
  - Replaces hard-coded values with dynamic database lookups  
  - Maintains backward compatibility with existing installations  
  - Automatic initialization of default configurations  
  
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
- **APP_TITLE**: Application title displayed in browser  
- **UI5_SRC**: UI5 bootstrap source URL (admin-only)  
- **DEBUG_MODE**: Debug mode toggle  
- **STYLES_CSS**: Custom CSS injection  
- **CSP_POLICY**: Content Security Policy (admin-only)  
  
## Technical Implementation:  
- ABAP 7.30+ compatible with proper error handling  
- Efficient caching strategy to minimize database calls    
- Theme changes applied immediately via sap.ui.getCore().applyTheme()  
- Value help integration using existing z2ui5_cl_pop_to_select framework  
- Transaction-safe with COMMIT WORK AND WAIT and rollback on errors  
  
## Benefits:  
- Eliminates need to modify HTTP handler code for configuration changes  
- Enables per-user customization (themes, titles, etc.)  
- Provides secure admin-only controls for system-level settings  
- Maintains framework performance through intelligent caching  
- Supports UI5 theme compatibility validation  
  
This enhancement significantly improves the flexibility and maintainability   
of abap2UI5 installations by moving configuration from code to database,  
while maintaining full backward compatibility.  
  
Tested on: ABAP 7.30  
Target: main branch (ABAP 7.5+) with automatic 702 downporting
