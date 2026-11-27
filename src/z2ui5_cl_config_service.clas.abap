CLASS z2ui5_cl_config_service DEFINITION
PUBLIC FINAL
CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_config TYPE z2ui5_t_29.
    TYPES ty_t_config TYPE STANDARD TABLE OF ty_config WITH DEFAULT KEY.
    TYPES ty_t_themes TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    "! the active rows of the global configuration and of the user the
    "! cache was loaded for (sy-uname) - not those of every user
    CLASS-DATA gt_config_cache TYPE ty_t_config.

    CLASS-METHODS get_config
      IMPORTING iv_key          TYPE clike
                iv_user_id      TYPE clike DEFAULT sy-uname
      RETURNING VALUE(rv_value) TYPE string.

    CLASS-METHODS set_config
      IMPORTING iv_key         TYPE clike
                iv_value       TYPE clike
                iv_user_id     TYPE clike DEFAULT sy-uname
                iv_description TYPE clike OPTIONAL
                iv_type        TYPE clike  DEFAULT 'STRING'
      RAISING   z2ui5_cx_config_error.

    CLASS-METHODS get_all_configs
      IMPORTING iv_user_id       TYPE syuname DEFAULT sy-uname
      RETURNING VALUE(rt_config) TYPE ty_t_config.

    CLASS-METHODS get_theme_list
      IMPORTING iv_ui5_version   TYPE clike
      RETURNING VALUE(rt_themes) TYPE ty_t_themes.

    CLASS-METHODS get_current_theme
      IMPORTING iv_user_id      TYPE clike DEFAULT sy-uname
      RETURNING VALUE(rv_theme) TYPE string.

    CLASS-METHODS is_master_user
      RETURNING VALUE(rv_is_master) TYPE boolean.

    "! deprecated: nothing calls it. The service checks Z2UI5_CTYP = '*'
    "! only (is_master_user): a user's own settings need no authorization,
    "! the system-wide ones need a master user. Kept for compatibility, to
    "! be removed.
    CLASS-METHODS check_config_authority
      IMPORTING iv_config_key        TYPE clike
                iv_activity          TYPE clike DEFAULT '02'
      RETURNING VALUE(rv_authorized) TYPE abap_bool.

    CLASS-METHODS initialize_default_configs
      IMPORTING iv_force_refresh TYPE clike DEFAULT abap_false.

    CLASS-METHODS load_config_cache.

  PRIVATE SECTION.
    "! the user whose rows gt_config_cache holds next to the global ones
    CLASS-DATA gv_cache_user TYPE syuname.

    "! load_config_cache( ) unless the cache holds the rows of sy-uname
    CLASS-METHODS cache_ensure.

    "! The row of a key for a user (empty: the global row) - from the cache
    "! for the global rows and those of sy-uname, from the database for
    "! anyone else's
    CLASS-METHODS config_row_read
      IMPORTING iv_key     TYPE clike
                iv_user_id TYPE clike
      EXPORTING es_config  TYPE ty_config
                ev_found   TYPE abap_bool.

    "! abap_true for the master-user settings UI5_SRC and CSP_POLICY: they
    "! are system-wide - stored once, without a user, locked - and a user
    "! value is never read for them
    CLASS-METHODS is_system_wide
      IMPORTING iv_key        TYPE clike
      RETURNING VALUE(result) TYPE abap_bool.

    "! abap_true for the UI5_SRC row that versions up to 2026-11 seeded on
    "! the first start of the app (the OpenUI5 CDN), as long as nobody has
    "! saved it since - get_config treats it as not set, so the abap2UI5
    "! default applies (ui5.sap.com on ABAP Cloud, whose CSP refuses the
    "! OpenUI5 CDN). The row itself stays where it is.
    CLASS-METHODS is_legacy_seed
      IMPORTING is_config     TYPE ty_config
      RETURNING VALUE(result) TYPE abap_bool.

    "! abap_true when release (e.g. 1.69) is not newer than max (e.g. 1.71);
    "! only the parts max names are compared, so max = 1 takes every 1.x
    CLASS-METHODS check_release_up_to
      IMPORTING release       TYPE clike
                !max          TYPE clike
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS save_config_to_db
      IMPORTING is_config TYPE ty_config
      RAISING   z2ui5_cx_config_error.
ENDCLASS.


CLASS z2ui5_cl_config_service IMPLEMENTATION.
  METHOD load_config_cache.
    " the exit reads the configuration for every response: only the rows it
    " can need - the global ones and the current user's - not every user's
    CLEAR gt_config_cache.
    gv_cache_user = sy-uname.
    SELECT * FROM z2ui5_t_29
      WHERE is_active = 'X'
        AND ( user_id = @gv_cache_user OR user_id = @space )
       INTO CORRESPONDING FIELDS OF TABLE @gt_config_cache.
  ENDMETHOD.

  METHOD cache_ensure.
    IF gt_config_cache IS INITIAL OR gv_cache_user <> sy-uname.
      load_config_cache( ).
    ENDIF.
  ENDMETHOD.

  METHOD config_row_read.
    CLEAR es_config.
    ev_found = abap_false.

    cache_ensure( ).

    IF iv_user_id IS INITIAL OR iv_user_id = gv_cache_user.
      READ TABLE gt_config_cache INTO es_config WITH KEY config_key = iv_key
                                                         user_id    = iv_user_id.
      IF sy-subrc = 0.
        ev_found = abap_true.
      ENDIF.
      RETURN.
    ENDIF.

    " the full key - at most one row
    DATA lt_config  TYPE ty_t_config.
    DATA lv_key     TYPE z2ui5_t_29-config_key.
    DATA lv_user_id TYPE z2ui5_t_29-user_id.
    lv_key     = iv_key.
    lv_user_id = iv_user_id.
    SELECT * FROM z2ui5_t_29
      WHERE config_key = @lv_key
        AND user_id    = @lv_user_id
        AND is_active  = 'X'
      INTO CORRESPONDING FIELDS OF TABLE @lt_config.
    READ TABLE lt_config INTO es_config INDEX 1.
    IF sy-subrc = 0.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD get_config.
    DATA ls_config TYPE ty_config.
    DATA lv_found  TYPE abap_bool.

    " Try user-specific configuration first - not for a system-wide setting,
    " where a user row (e.g. one saved before these were stored globally)
    " must not override what the master user set for everybody
    IF is_system_wide( iv_key ) = abap_false AND iv_user_id IS NOT INITIAL.
      config_row_read( EXPORTING iv_key     = iv_key
                                 iv_user_id = iv_user_id
                       IMPORTING es_config  = ls_config
                                 ev_found   = lv_found ).
      IF lv_found = abap_true.
        rv_value = ls_config-config_value.
        RETURN.
      ENDIF.
    ENDIF.

    " Fallback to global configuration - not the UI5_SRC an earlier version
    " seeded, which would pin the bootstrap to the OpenUI5 CDN
    config_row_read( EXPORTING iv_key     = iv_key
                               iv_user_id = ''
                     IMPORTING es_config  = ls_config
                               ev_found   = lv_found ).
    IF lv_found = abap_true AND is_legacy_seed( ls_config ) = abap_false.
      rv_value = ls_config-config_value.
      RETURN.
    ENDIF.

    " Fallback to the abap2UI5 defaults - only THEME has one, every other
    " key stays empty so that the user exit keeps abap2UI5's own value
    IF iv_key = 'THEME'.
      rv_value = 'sap_horizon'.
    ENDIF.
  ENDMETHOD.

  METHOD set_config.
    DATA ls_config TYPE ty_config.

    cache_ensure( ).

    " A system-wide setting is the master user's alone, locked or not, and it
    " is stored once for everybody (no user) and stays locked
    DATA(lv_system_wide) = is_system_wide( iv_key ).
    IF lv_system_wide = abap_true AND is_master_user( ) = ''.
      z2ui5_cx_config_error=>raise_config_locked( ).
    ENDIF.
    DATA lv_user_id TYPE z2ui5_t_29-user_id.
    IF lv_system_wide = abap_false.
      lv_user_id = iv_user_id.
    ENDIF.

    " Check if configuration is locked and user is not a master-user
    READ TABLE gt_config_cache INTO DATA(ls_existing) WITH KEY config_key = iv_key
                                                               user_id    = ''.
    IF sy-subrc = 0 AND ls_existing-is_locked = 'X' AND is_master_user( ) = ''.
      z2ui5_cx_config_error=>raise_config_locked( ).
    ENDIF.

    ls_config-config_key   = iv_key.
    ls_config-user_id      = lv_user_id.
    ls_config-config_value = iv_value.
    ls_config-description  = iv_description.
    ls_config-config_type  = iv_type.
    ls_config-is_active    = 'X'.
    ls_config-is_locked    = COND #( WHEN lv_system_wide = abap_true THEN 'X' ).
    ls_config-changed_by   = sy-uname.
    GET TIME STAMP FIELD ls_config-changed_at.

    " MODIFY writes the whole row - keep who created it and when
    DATA ls_saved TYPE ty_config.
    DATA lv_found TYPE abap_bool.
    config_row_read( EXPORTING iv_key     = iv_key
                               iv_user_id = lv_user_id
                     IMPORTING es_config  = ls_saved
                               ev_found   = lv_found ).
    IF lv_found = abap_true.
      ls_config-created_by = ls_saved-created_by.
      ls_config-created_at = ls_saved-created_at.
    ELSE.
      ls_config-created_by = sy-uname.
      GET TIME STAMP FIELD ls_config-created_at.
    ENDIF.

    " the cache holds the global rows and those of sy-uname only
    IF lv_user_id IS INITIAL OR lv_user_id = gv_cache_user.
      DELETE gt_config_cache WHERE config_key = iv_key AND user_id = lv_user_id.
      INSERT ls_config INTO TABLE gt_config_cache.
    ENDIF.

    save_config_to_db( ls_config ).
  ENDMETHOD.

  METHOD save_config_to_db.
    MODIFY z2ui5_t_29 FROM @is_config.
    IF sy-subrc <> 0.
      z2ui5_cx_config_error=>raise_save_failed( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_all_configs.
    cache_ensure( ).
    rt_config = gt_config_cache.
    DELETE rt_config WHERE user_id <> iv_user_id AND user_id <> ''.

    " the cache holds the rows of sy-uname only - another user's are read
    IF iv_user_id IS NOT INITIAL AND iv_user_id <> gv_cache_user.
      SELECT * FROM z2ui5_t_29
        WHERE is_active = 'X'
          AND user_id   = @iv_user_id
        APPENDING CORRESPONDING FIELDS OF TABLE @rt_config.
    ENDIF.
  ENDMETHOD.

  METHOD get_theme_list.
    DATA lv_ui5_version TYPE string.
    DATA lv_result      TYPE string.
    DATA lt_parts       TYPE string_table.
    DATA lv_part1       TYPE string.
    DATA lv_part2       TYPE string.

    " Normalize UI5 version (e.g., '1.71.22' -> '1.71', fallback to '1' for broad match)
    lv_ui5_version = iv_ui5_version.
    IF lv_ui5_version IS INITIAL.
      lv_ui5_version = '1'. " Broad match for all versions
    ELSE.
      lv_ui5_version = condense( val  = lv_ui5_version
                                 from = ` `
                                 to   = `` ). " Remove spaces

      " Split the version string by dots
      SPLIT lv_ui5_version AT '.' INTO TABLE lt_parts.

      " If there are at least 3 parts (e.g., 1.120.32), take the first two
      IF lines( lt_parts ) >= 3.
        READ TABLE lt_parts INTO lv_part1 INDEX 1.
        READ TABLE lt_parts INTO lv_part2 INDEX 2.
        CONCATENATE lv_part1 lv_part2 INTO lv_result SEPARATED BY '.'.
      ELSE.
        lv_result = lv_ui5_version. " No patch version, keep as is
      ENDIF.

      lv_ui5_version = lv_result.
      " Input: '1.120.32' Result: lv_ui5_version = '1.120'
    ENDIF.

    " A row names the release a theme is available from, so the themes of
    " every row up to the running release apply - 1.71 gets what 1.65 and
    " 1.69 list, a release newer than the last row gets them all. (An exact
    " match alone would leave out every theme of an older row.)
    SELECT ui5_version, theme FROM z2ui5_t_30
      WHERE is_active = 'X'
      INTO TABLE @DATA(lt_rows).
    LOOP AT lt_rows INTO DATA(ls_row).
      IF check_release_up_to( release = ls_row-ui5_version
                              max     = lv_ui5_version ) = abap_true
         AND NOT line_exists( rt_themes[ table_line = ls_row-theme ] ).
        APPEND CONV string( ls_row-theme ) TO rt_themes.
      ENDIF.
    ENDLOOP.

    " Fallback to default themes if none found
    IF rt_themes IS INITIAL.
      rt_themes = VALUE #( ( `sap_horizon` ) ( `sap_fiori_3` ) ( `sap_horizon_dark` ) ).
    ENDIF.
  ENDMETHOD.

  METHOD check_release_up_to.
    DATA lt_release TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lt_max     TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lv_release TYPE i.
    DATA lv_max     TYPE i.

    SPLIT condense( release ) AT '.' INTO TABLE lt_release.
    SPLIT condense( max ) AT '.' INTO TABLE lt_max.

    result = abap_true.
    LOOP AT lt_max INTO DATA(lv_max_part).
      DATA(lv_index) = sy-tabix.
      TRY.
          lv_max = lv_max_part.
          READ TABLE lt_release INTO DATA(lv_release_part) INDEX lv_index.
          IF sy-subrc <> 0.
            lv_release_part = `0`.
          ENDIF.
          lv_release = lv_release_part.
        CATCH cx_sy_conversion_error.
          result = abap_false.
          RETURN.
      ENDTRY.
      IF lv_release < lv_max.
        RETURN.
      ELSEIF lv_release > lv_max.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_current_theme.
    rv_theme = get_config( iv_key     = 'THEME'
                           iv_user_id = iv_user_id ).
  ENDMETHOD.

  METHOD is_system_wide.
    result = xsdbool( iv_key = 'UI5_SRC' OR iv_key = 'CSP_POLICY' ).
  ENDMETHOD.

  METHOD is_legacy_seed.
    " what initialize_default_configs wrote: set_config( ) changes
    " changed_at and the description, so a value a master user saved - even
    " the same URL - is no seed
    result = xsdbool( is_config-config_key   = 'UI5_SRC'
                  AND is_config-user_id      IS INITIAL
                  AND is_config-config_value = 'https://sdk.openui5.org/resources/sap-ui-cachebuster/sap-ui-core.js'
                  AND is_config-description  = 'UI5 Bootstrap Source'
                  AND is_config-changed_at   = is_config-created_at ).
  ENDMETHOD.

  METHOD is_master_user.
    " Check for master configuration authority
    AUTHORITY-CHECK OBJECT 'Z2UI5_CONF'
                    ID 'ACTVT' FIELD '02'  " Change authorization
                    ID 'Z2UI5_CTYP' FIELD '*'.
    IF sy-subrc = 0.
      rv_is_master = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD check_config_authority.
    AUTHORITY-CHECK OBJECT 'Z2UI5_CONF'
                    ID 'ACTVT' FIELD iv_activity
                    ID 'Z2UI5_CTYP' FIELD iv_config_key.
    rv_authorized = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD initialize_default_configs.
    DATA lv_timestamp TYPE timestampl.
    DATA lv_count     TYPE i.
    DATA lt_configs   TYPE ty_t_config.
    DATA lt_themes    TYPE STANDARD TABLE OF z2ui5_t_30 WITH EMPTY KEY.

    " Check if already initialized (unless force refresh)
    IF iv_force_refresh = abap_false.
      SELECT COUNT(*) FROM z2ui5_t_29 INTO @lv_count.
      IF lv_count > 0.
        RETURN. " Already initialized
      ENDIF.
    ENDIF.

    GET TIME STAMP FIELD lv_timestamp.

    " global defaults, open for every user's own value. No UI5_SRC and no
    " CSP_POLICY: an unset key keeps the abap2UI5 default, which knows what
    " the running platform needs (a stored OpenUI5 CDN URL stops the page
    " from booting on ABAP Cloud)
    lt_configs = VALUE #(
      ( config_key = 'THEME'      config_value = 'sap_horizon' config_type = 'STRING'  description = 'Default UI5 Theme' )
      ( config_key = 'DEBUG_MODE' config_value = ''            config_type = 'BOOLEAN' description = 'Debug Mode Setting' )
      ( config_key = 'APP_TITLE'  config_value = 'abap2UI5'    config_type = 'STRING'  description = 'Application Title' ) ).
    LOOP AT lt_configs ASSIGNING FIELD-SYMBOL(<ls_config>).
      <ls_config>-is_active  = abap_true.
      <ls_config>-created_by = sy-uname.
      <ls_config>-changed_by = sy-uname.
      <ls_config>-created_at = lv_timestamp.
      <ls_config>-changed_at = lv_timestamp.
    ENDLOOP.
    MODIFY z2ui5_t_29 FROM TABLE @lt_configs.

    " the release each theme is available from - get_theme_list takes every
    " row up to the running release, so one row per theme is enough
    lt_themes = VALUE #(
      ( ui5_version = '1.65'  theme = 'sap_fiori_3' )
      ( ui5_version = '1.96'  theme = 'sap_horizon' )
      ( ui5_version = '1.101' theme = 'sap_horizon_dark' )
      ( ui5_version = '1.101' theme = 'sap_horizon_hcb' )
      ( ui5_version = '1.101' theme = 'sap_horizon_hcw' ) ).
    LOOP AT lt_themes ASSIGNING FIELD-SYMBOL(<ls_theme>).
      <ls_theme>-is_active  = abap_true.
      <ls_theme>-created_by = sy-uname.
      <ls_theme>-changed_by = sy-uname.
      <ls_theme>-created_at = lv_timestamp.
      <ls_theme>-changed_at = lv_timestamp.
    ENDLOOP.
    MODIFY z2ui5_t_30 FROM TABLE @lt_themes.

    COMMIT WORK AND WAIT.
  ENDMETHOD.
ENDCLASS.
