CLASS z2ui5_cl_app_icf_config DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_theme,
        theme TYPE string,
      END OF ty_s_theme.
    TYPES ty_t_themes TYPE STANDARD TABLE OF ty_s_theme WITH EMPTY KEY.

    DATA mv_ui5_version TYPE string.
    DATA client         TYPE REF TO z2ui5_if_client.
    DATA:
      BEGIN OF ms_config,
        theme      TYPE string,
        debug_mode TYPE abap_bool,
        ui5_src    TYPE string,
        app_title  TYPE string,
        styles_css TYPE string,
        csp_policy TYPE string,
      END OF ms_config.

    DATA mt_all_configs TYPE z2ui5_cl_config_service=>ty_t_config.
    " the items of the theme Select - the themes of the running UI5 release
    DATA mt_themes      TYPE ty_t_themes.

    CLASS-METHODS factory
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_app_icf_config.

    METHODS z2ui5_on_init.
    METHODS z2ui5_on_event.
    METHODS view_display_popup.
    METHODS view_display_config_popup.
    METHODS save_all_configs.

  PROTECTED SECTION.
    DATA mv_config_popup_active TYPE abap_bool.

    METHODS ui5_version_read.
    METHODS themes_read.

    METHODS theme_apply
      IMPORTING iv_theme TYPE string.

    METHODS leave_deferred.

ENDCLASS.


CLASS z2ui5_cl_app_icf_config IMPLEMENTATION.
  METHOD factory.
    result = NEW #( ).
  ENDMETHOD.

  METHOD save_all_configs.
    TRY.
        " Save theme from bound form field
        IF ms_config-theme IS NOT INITIAL.
          theme_apply( ms_config-theme ).
          z2ui5_cl_config_service=>set_config( iv_key   = 'THEME'
                                               iv_value = ms_config-theme ).
        ENDIF.

        " Save debug mode from bound form field
        DATA lv_debug_string TYPE string.
        IF ms_config-debug_mode = abap_true.
          lv_debug_string = 'X'.
        ELSE.
          lv_debug_string = ''.
        ENDIF.
        z2ui5_cl_config_service=>set_config( iv_key   = 'DEBUG_MODE'
                                             iv_value = lv_debug_string ).

        " Save application title from bound form field
        IF ms_config-app_title IS NOT INITIAL.
          z2ui5_cl_config_service=>set_config( iv_key   = 'APP_TITLE'
                                               iv_value = ms_config-app_title ).
        ENDIF.

        " Save custom CSS from bound form field
        z2ui5_cl_config_service=>set_config( iv_key   = 'STYLES_CSS'
                                             iv_value = ms_config-styles_css ).

        " Save other configurations if user has authority
        DATA lv_is_master TYPE boolean.
        lv_is_master = z2ui5_cl_config_service=>is_master_user( ).

        " Save UI5 source (admin only)
        IF lv_is_master = abap_true.
          IF ms_config-ui5_src IS NOT INITIAL.
            z2ui5_cl_config_service=>set_config( iv_key   = 'UI5_SRC'
                                                 iv_value = ms_config-ui5_src ).
          ENDIF.

          " Save CSP policy (admin only)
          z2ui5_cl_config_service=>set_config( iv_key   = 'CSP_POLICY'
                                               iv_value = ms_config-csp_policy ).
        ENDIF.

        " Commit all changes to database
        COMMIT WORK AND WAIT.

        " Clear cache to force reload
        z2ui5_cl_config_service=>load_config_cache( ).

        client->message_toast_display( 'Configuration saved successfully' ).

      CATCH cx_root INTO DATA(lx_error).
        ROLLBACK WORK.
        client->message_box_display( text = |Error saving configuration: { lx_error->get_text( ) }|
                                     type = 'error' ).
    ENDTRY.
  ENDMETHOD.

  METHOD view_display_config_popup.
    DATA lv_is_master   TYPE boolean.
    DATA lv_debug_value TYPE string.

    mv_config_popup_active = abap_true.

    " Check if user is master user
    lv_is_master = z2ui5_cl_config_service=>is_master_user( ).

    " Initialize default configs if needed
    z2ui5_cl_config_service=>initialize_default_configs( ).

    " Only refresh configurations if they haven't been loaded yet or if explicitly requested
    " This keeps unsaved input - a theme picked for the preview - when the popup is displayed again
    IF ms_config-theme IS INITIAL.
      ms_config-theme = z2ui5_cl_config_service=>get_current_theme( ).
    ENDIF.

    IF ms_config-app_title IS INITIAL.
      ms_config-app_title = z2ui5_cl_config_service=>get_config( 'APP_TITLE' ).
    ENDIF.

    IF ms_config-ui5_src IS INITIAL.
      ms_config-ui5_src = z2ui5_cl_config_service=>get_config( 'UI5_SRC' ).
    ENDIF.

    IF ms_config-styles_css IS INITIAL.
      ms_config-styles_css = z2ui5_cl_config_service=>get_config( 'STYLES_CSS' ).
    ENDIF.

    IF ms_config-csp_policy IS INITIAL.
      ms_config-csp_policy = z2ui5_cl_config_service=>get_config( 'CSP_POLICY' ).
    ENDIF.

    " Debug mode handling
    lv_debug_value = z2ui5_cl_config_service=>get_config( 'DEBUG_MODE' ).
    IF lv_debug_value = 'X' OR lv_debug_value = 'true' OR lv_debug_value = '1'.
      ms_config-debug_mode = abap_true.
    ELSE.
      ms_config-debug_mode = abap_false.
    ENDIF.

    " the items of the theme Select
    themes_read( ).

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`       v = `sap.m`
        )->a( n = `xmlns:core`  v = `sap.ui.core`
        )->a( n = `xmlns:form`  v = `sap.ui.layout.form`

        )->ele( `Dialog`
            )->a( n = `title`          v = `Configuration Settings`
            )->a( n = `afterClose`     v = client->_event( `CLOSE_CONFIG` )
            )->a( n = `contentWidth`   v = `60%`
            )->a( n = `contentHeight`  v = `70%` ).

    DATA(form) = dialog->ele( `content`
        )->ele( n = `SimpleForm` ns = `form`
            )->a( n = `editable`  v = `true`
            )->a( n = `layout`    v = `ResponsiveGridLayout`
            )->ele( n = `content` ns = `form` ).

    " Theme configuration section - picking a theme previews it (THEME_CHANGE)
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `Theme Settings` ).
    form->tag( `Label`
        )->a( n = `text`  v = `Theme` ).
    form->ele( `Select`
        )->a( n = `selectedKey`  v = client->_bind( ms_config-theme )
        )->a( n = `items`        v = client->_bind( mt_themes )
        )->a( n = `change`       v = client->_event( `THEME_CHANGE` )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`   v = `{THEME}`
                )->a( n = `text`  v = `{THEME}` ).

    " Debug mode section
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `Debug Settings` ).
    form->tag( `Label`
        )->a( n = `text`  v = `Debug Mode` ).
    form->tag( `CheckBox`
        )->a( n = `selected`  v = client->_bind( ms_config-debug_mode ) ).

    " UI5 Source configuration (admin only)
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `UI5 Bootstrap Settings` ).
    form->tag( `Label`
        )->a( n = `text`  v = `UI5 Source URL` ).
    IF lv_is_master = abap_true.
      form->tag( `Input`
          )->a( n = `value`  v = client->_bind( ms_config-ui5_src ) ).
    ELSE.
      form->tag( `Text`
          )->a( n = `text`  t = ms_config-ui5_src ).
      form->tag( `Text`
          )->a( n = `text`  v = `(Admin only)` ).
    ENDIF.

    " Application Title configuration
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `Application Settings` ).
    form->tag( `Label`
        )->a( n = `text`  v = `Application Title` ).
    form->tag( `Input`
        )->a( n = `value`  v = client->_bind( ms_config-app_title ) ).

    " Custom CSS configuration
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `Style Settings` ).
    form->tag( `Label`
        )->a( n = `text`  v = `Custom CSS` ).
    form->tag( `TextArea`
        )->a( n = `value`  v = client->_bind( ms_config-styles_css )
        )->a( n = `rows`   v = `5` ).

    " Content Security Policy (admin only)
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `Security Settings` ).
    form->tag( `Label`
        )->a( n = `text`  v = `Content Security Policy` ).
    IF lv_is_master = abap_true.
      form->tag( `TextArea`
          )->a( n = `value`  v = client->_bind( ms_config-csp_policy )
          )->a( n = `rows`   v = `3` ).
    ELSE.
      form->tag( `Text`
          )->a( n = `text`  t = ms_config-csp_policy ).
      form->tag( `Text`
          )->a( n = `text`  v = `(Admin only)` ).
    ENDIF.

    " Buttons
    dialog->ele( `buttons`
        )->tag( `Button`
            )->a( n = `text`   v = `Save`
            )->a( n = `press`  v = client->_event( `CONFIG_SAVE` )
            )->a( n = `type`   v = `Emphasized`
        )->tag( `Button`
            )->a( n = `text`   v = `Cancel`
            )->a( n = `press`  v = client->_event( `CLOSE_CONFIG` ) ).

    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.

  METHOD view_display_popup.

    " the frontend reports its UI5 runtime with every request
    ui5_version_read( ).

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`       v = `sap.m`
        )->a( n = `xmlns:core`  v = `sap.ui.core`
        )->a( n = `xmlns:form`  v = `sap.ui.layout.form`

        )->ele( `Dialog`
            )->a( n = `title`       v = `abap2UI5 - System Information`
            )->a( n = `afterClose`  v = client->_event( `CLOSE` ) ).

    DATA(form) = dialog->ele( `content`
        )->ele( n = `SimpleForm` ns = `form`
            )->a( n = `editable`                 v = `true`
            )->a( n = `layout`                   v = `ResponsiveGridLayout`
            )->a( n = `labelSpanXL`              v = `4`
            )->a( n = `labelSpanL`               v = `3`
            )->a( n = `labelSpanM`               v = `4`
            )->a( n = `labelSpanS`               v = `12`
            )->a( n = `adjustLabelSpan`          v = `false`
            )->a( n = `emptySpanXL`              v = `0`
            )->a( n = `emptySpanL`               v = `4`
            )->a( n = `emptySpanM`               v = `0`
            )->a( n = `emptySpanS`               v = `0`
            )->a( n = `columnsXL`                v = `1`
            )->a( n = `columnsL`                 v = `1`
            )->a( n = `columnsM`                 v = `1`
            )->a( n = `singleContainerFullSize`  v = `false`
            )->ele( n = `content` ns = `form` ).

    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `Frontend` ).
    form->tag( `Label`
        )->a( n = `text`  v = `UI5 Version` ).
    form->tag( `Text`
        )->a( n = `text`  v = client->_bind( mv_ui5_version ) ).
    form->tag( `Label`
        )->a( n = `text`  v = `Launchpad active` ).
    form->tag( `CheckBox`
        )->a( n = `selected`  b = client->get( )-check_launchpad_active
        )->a( n = `enabled`   v = `false` ).

    " The draft count and the ABAP for Cloud flag are gone from here: the
    " released API (src/02) answers neither, only core internals do. The
    " abap2UI5 start page shows both in its own System Information popup.
    form->ele( `Toolbar`
        )->tag( `Title`
            )->a( n = `text`  v = `abap2UI5` ).
    form->tag( `Label`
        )->a( n = `text`  v = `Version` ).
    form->tag( `Text`
        )->a( n = `text`  v = z2ui5_if_app=>version ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`   v = `close`
            )->a( n = `press`  v = client->_event( `CLOSE` )
            )->a( n = `type`   v = `Emphasized` ).

    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.

  METHOD z2ui5_if_app~main.
    me->client = client.

    IF client->check_on_init( ).
      z2ui5_on_init( ).
      view_display_config_popup( ).
    ELSEIF client->check_on_navigated( ).
      " a restored draft (bookmark, browser Back/Forward) - the popup is the
      " only view this app has, so it is displayed again
      view_display_config_popup( ).
    ELSEIF client->check_on_event( ).
      z2ui5_on_event( ).
    ENDIF.
  ENDMETHOD.

  METHOD z2ui5_on_event.
    DATA li_app TYPE REF TO z2ui5_if_app.

    CASE client->get( )-event.

      WHEN `CLOSE`.
        client->popup_destroy( ).
        client->nav_app_leave( ).

      WHEN `OPEN_DEBUG`.
        client->message_box_display( `Press CTRL+F12 to open the debugging tools` ).

      WHEN 'SET_CONFIG'.
        view_display_config_popup( ).

      WHEN `THEME_CHANGE`.
        " preview - the Select has written the picked theme into ms_config-theme
        theme_apply( ms_config-theme ).

      WHEN 'CONFIG_SAVE'.
        save_all_configs( ).
        leave_deferred( ).

      WHEN 'CLOSE_CONFIG'.
        " Reset theme to saved value if user cancels without saving
        DATA(lv_saved_theme) = z2ui5_cl_config_service=>get_current_theme( ).

        IF ms_config-theme <> lv_saved_theme.
          " Revert to saved theme
          theme_apply( lv_saved_theme ).
          ms_config-theme = lv_saved_theme.
        ENDIF.
        mv_config_popup_active = abap_false.
        leave_deferred( ).

      WHEN `CONFIG_LEAVE`.
        " fired by the timer leave_deferred( ) started
        client->popup_destroy( ).
        client->nav_app_leave( ).

      WHEN `OPEN_INFO`.
        view_display_popup( ).
        RETURN.

    ENDCASE.
  ENDMETHOD.

  METHOD ui5_version_read.

    mv_ui5_version = client->get( )-s_ui5-version.
    IF mv_ui5_version IS INITIAL.
      mv_ui5_version = '1.120.32'. " Default fallback version
    ENDIF.

  ENDMETHOD.

  METHOD themes_read.

    IF mv_ui5_version IS INITIAL.
      ui5_version_read( ).
    ENDIF.

    DATA(lt_theme_names) = z2ui5_cl_config_service=>get_theme_list( mv_ui5_version ).
    mt_themes = VALUE #( FOR lv_theme_name IN lt_theme_names ( theme = lv_theme_name ) ).

    " the current theme stays selectable even when the list of the running
    " release does not carry it - the Select forces a selection, and would
    " otherwise put its first entry into ms_config-theme and save that
    IF ms_config-theme IS NOT INITIAL AND NOT line_exists( mt_themes[ theme = ms_config-theme ] ). "#EC CI_SORTSEQ
      INSERT VALUE #( theme = ms_config-theme ) INTO mt_themes INDEX 1.
    ENDIF.

  ENDMETHOD.

  METHOD theme_apply.

    " The whitelisted frontend action for the theme (GLOBAL_TARGETS-THEMING
    " in the abap2UI5 frontend) - follow_up_action( ) no longer runs raw
    " JavaScript such as sap.ui.getCore( ).applyTheme( ). THEMING is the lazily
    " required sap/ui/core/Theming, which exists from UI5 1.118 on: on an older
    " release the frontend logs "not available" and the preview stays out,
    " while a saved theme still applies with the next page load (user exit).
    client->follow_up_action( val   = client->cs_event-control_global
                              " abap2ui5lint-disable-next-line frontend-action-too-new -- live preview only; below UI5 1.118 the saved theme applies on the next page load
                              t_arg = VALUE #( ( `THEMING` ) ( `setTheme` ) ( iv_theme ) ) ).

  ENDMETHOD.

  METHOD leave_deferred.

    " The frontend actions an app queues do not survive its own
    " nav_app_leave( ) - the app it returns to starts with an empty queue - so
    " the theme, its revert on Cancel and the toast of the save cannot share a
    " roundtrip with the leave. This roundtrip sends them; the client timer
    " fires CONFIG_LEAVE right after it has been rendered, and that roundtrip
    " closes the popup and leaves.
    client->follow_up_action( val   = client->cs_event-start_timer
                              t_arg = VALUE #( ( `CONFIG_LEAVE` ) ( `0` ) ) ).

  ENDMETHOD.

  METHOD z2ui5_on_init.

    " the UI5 version the browser runs - it selects the theme list
    ui5_version_read( ).

    " Initialize default configs early
    z2ui5_cl_config_service=>initialize_default_configs( ).

    " Load current configurations into ms_config structure
    ms_config-theme = z2ui5_cl_config_service=>get_current_theme( ).
    DATA lv_debug_value TYPE string.
    lv_debug_value = z2ui5_cl_config_service=>get_config( 'DEBUG_MODE' ).
    IF lv_debug_value = 'X' OR lv_debug_value = 'true' OR lv_debug_value = '1'.
      ms_config-debug_mode = abap_true.
    ELSE.
      ms_config-debug_mode = abap_false.
    ENDIF.

    " Load other configuration values
    ms_config-ui5_src    = z2ui5_cl_config_service=>get_config( 'UI5_SRC' ).
    ms_config-app_title  = z2ui5_cl_config_service=>get_config( 'APP_TITLE' ).
    ms_config-styles_css = z2ui5_cl_config_service=>get_config( 'STYLES_CSS' ).
    ms_config-csp_policy = z2ui5_cl_config_service=>get_config( 'CSP_POLICY' ).
  ENDMETHOD.
ENDCLASS.
