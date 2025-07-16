# config-management

This enhancement replaces hard-coded HTTP handler configurations with a flexible, database-driven configuration system that allows runtime customization of UI5 application settings.  

## Installation

Use in your abap2UI5 http handler the following handler class:
```abap
CLASS zcl_my_abap2UI5_http_handler DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

ENDCLASS.

CLASS zcl_my_abap2UI5_http_handler IMPLEMENTATION.
  METHOD if_http_extension~handle_request.

    z2ui5_cl_http_handler_icf_config=>run( server ).

  ENDMETHOD.
ENDCLASS.
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
