CLASS z2ui5_cl_config_service DEFINITION
PUBLIC FINAL
CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_config TYPE z2ui5_t_29.
    TYPES ty_t_config TYPE STANDARD TABLE OF ty_config WITH DEFAULT KEY.
    TYPES ty_t_themes TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

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

    CLASS-METHODS check_config_authority
      IMPORTING iv_config_key        TYPE clike
                iv_activity          TYPE clike DEFAULT '02'
      RETURNING VALUE(rv_authorized) TYPE abap_bool.

    CLASS-METHODS initialize_default_configs
      IMPORTING iv_force_refresh TYPE clike DEFAULT abap_false.

    CLASS-METHODS load_config_cache.

  PRIVATE SECTION.
    "! abap_true for the master-user settings UI5_SRC and CSP_POLICY: they
    "! are system-wide - stored once, without a user, locked - and a user
    "! value is never read for them
    CLASS-METHODS is_system_wide
      IMPORTING iv_key        TYPE clike
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
    CLEAR gt_config_cache.
    SELECT * FROM z2ui5_t_29 INTO CORRESPONDING FIELDS OF TABLE gt_config_cache
      WHERE is_active = 'X'
       .
  ENDMETHOD.

  METHOD get_config.
    DATA ls_config TYPE ty_config.

    IF gt_config_cache IS INITIAL.
      load_config_cache( ).
    ENDIF.

    " Try user-specific configuration first - not for a system-wide setting,
    " where a user row (e.g. one saved before these were stored globally)
    " must not override what the master user set for everybody
    IF is_system_wide( iv_key ) = abap_false.
      READ TABLE gt_config_cache INTO ls_config WITH KEY config_key = iv_key
                                                         user_id    = iv_user_id.
      IF sy-subrc = 0.
        rv_value = ls_config-config_value.
        RETURN.
      ENDIF.
    ENDIF.

    " Fallback to global configuration
    READ TABLE gt_config_cache INTO ls_config WITH KEY config_key = iv_key
                                                       user_id    = ''.
    IF sy-subrc = 0.
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
    DATA lv_system_wide TYPE abap_bool.
    DATA lv_user_id TYPE z2ui5_t_29-user_id.
    DATA ls_existing TYPE z2ui5_t_29.
    DATA temp1 LIKE ls_config-is_locked.
    FIELD-SYMBOLS <ls_config> TYPE z2ui5_t_29.

    IF gt_config_cache IS INITIAL.
      load_config_cache( ).
    ENDIF.

    " A system-wide setting is the master user's alone, locked or not, and it
    " is stored once for everybody (no user) and stays locked

    lv_system_wide = is_system_wide( iv_key ).
    IF lv_system_wide = abap_true AND is_master_user( ) = ''.
      z2ui5_cx_config_error=>raise_config_locked( ).
    ENDIF.

    IF lv_system_wide = abap_false.
      lv_user_id = iv_user_id.
    ENDIF.

    " Check if configuration is locked and user is not a master-user

    READ TABLE gt_config_cache INTO ls_existing WITH KEY config_key = iv_key
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

    IF lv_system_wide = abap_true.
      temp1 = 'X'.
    ELSE.
      CLEAR temp1.
    ENDIF.
    ls_config-is_locked    = temp1.
    ls_config-changed_by   = sy-uname.
    GET TIME STAMP FIELD ls_config-changed_at.


    READ TABLE gt_config_cache WITH KEY config_key = iv_key user_id = lv_user_id ASSIGNING <ls_config>.
    IF <ls_config> IS ASSIGNED.
      " MODIFY writes the whole row - keep who created it and when
      ls_config-created_by = <ls_config>-created_by.
      ls_config-created_at = <ls_config>-created_at.
      <ls_config>-config_value = iv_value.
      <ls_config>-description  = iv_description.
      <ls_config>-config_type  = iv_type.
      <ls_config>-is_locked    = ls_config-is_locked.
      <ls_config>-changed_by   = sy-uname.
      GET TIME STAMP FIELD <ls_config>-changed_at.
    ELSE.
      ls_config-created_by = sy-uname.
      GET TIME STAMP FIELD ls_config-created_at.
      INSERT ls_config INTO TABLE gt_config_cache.
    ENDIF.

    save_config_to_db( ls_config ).
  ENDMETHOD.

  METHOD save_config_to_db.
    MODIFY z2ui5_t_29 FROM is_config.
    IF sy-subrc <> 0.
      z2ui5_cx_config_error=>raise_save_failed( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_all_configs.
    IF gt_config_cache IS INITIAL.
      load_config_cache( ).
    ENDIF.
    rt_config = gt_config_cache.
    DELETE rt_config WHERE user_id <> iv_user_id AND user_id <> ''.
  ENDMETHOD.

  METHOD get_theme_list.
    DATA lv_ui5_version TYPE string.
    DATA lv_result      TYPE string.
    DATA lt_parts       TYPE string_table.
    DATA lv_part1       TYPE string.
    DATA lv_part2       TYPE string.
TYPES BEGIN OF temp2.
TYPES ui5_version TYPE z2ui5_t_30-ui5_version.
TYPES theme TYPE z2ui5_t_30-theme.
TYPES END OF temp2.
    TYPES temp1 TYPE STANDARD TABLE OF temp2 WITH DEFAULT KEY.
DATA lt_rows TYPE temp1.
    DATA ls_row LIKE LINE OF lt_rows.
      DATA temp3 LIKE sy-subrc.
        DATA temp4 LIKE LINE OF rt_themes.
      DATA temp5 TYPE z2ui5_cl_config_service=>ty_t_themes.

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



    SELECT ui5_version theme FROM z2ui5_t_30 INTO TABLE lt_rows
      WHERE is_active = 'X'
      .

    LOOP AT lt_rows INTO ls_row.

      READ TABLE rt_themes WITH KEY table_line = ls_row-theme TRANSPORTING NO FIELDS.
      temp3 = sy-subrc.
      IF check_release_up_to( release = ls_row-ui5_version
                              max     = lv_ui5_version ) = abap_true
         AND NOT temp3 = 0.

        temp4 = ls_row-theme.
        APPEND temp4 TO rt_themes.
      ENDIF.
    ENDLOOP.

    " Fallback to default themes if none found
    IF rt_themes IS INITIAL.

      CLEAR temp5.
      INSERT `sap_horizon` INTO TABLE temp5.
      INSERT `sap_fiori_3` INTO TABLE temp5.
      INSERT `sap_horizon_dark` INTO TABLE temp5.
      rt_themes = temp5.
    ENDIF.
  ENDMETHOD.

  METHOD check_release_up_to.
    TYPES temp2 TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
DATA lt_release TYPE temp2.
    TYPES temp3 TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
DATA lt_max     TYPE temp3.
    DATA lv_release TYPE i.
    DATA lv_max     TYPE i.
    DATA lv_max_part LIKE LINE OF lt_max.
      DATA lv_index LIKE sy-tabix.
          DATA lv_release_part TYPE string.

    SPLIT condense( release ) AT '.' INTO TABLE lt_release.
    SPLIT condense( max ) AT '.' INTO TABLE lt_max.

    result = abap_true.

    LOOP AT lt_max INTO lv_max_part.

      lv_index = sy-tabix.
      TRY.
          lv_max = lv_max_part.

          READ TABLE lt_release INTO lv_release_part INDEX lv_index.
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
    DATA temp1 TYPE xsdboolean.
    temp1 = boolc( iv_key = 'UI5_SRC' OR iv_key = 'CSP_POLICY' ).
    result = temp1.
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
    DATA temp2 TYPE xsdboolean.
    AUTHORITY-CHECK OBJECT 'Z2UI5_CONF'
                    ID 'ACTVT' FIELD iv_activity
                    ID 'Z2UI5_CTYP' FIELD iv_config_key.

    temp2 = boolc( sy-subrc = 0 ).
    rv_authorized = temp2.
  ENDMETHOD.

  METHOD initialize_default_configs.
    DATA lv_timestamp       TYPE timestampl.
    DATA lt_default_configs TYPE ty_t_config.
    DATA ls_config          TYPE ty_config.
    DATA lv_count           TYPE i.
    DATA ls_theme_entry TYPE z2ui5_t_30.

    " Check if already initialized (unless force refresh)
    IF iv_force_refresh = abap_false.
      SELECT COUNT(*) FROM z2ui5_t_29 INTO lv_count.
      IF lv_count > 0.
        RETURN. " Already initialized
      ENDIF.
    ENDIF.

    GET TIME STAMP FIELD lv_timestamp.

    " Initialize default configurations based on abap2UI5 documentation

    " Core theme configuration - unlocked for user customization
    ls_config-config_key   = 'THEME'.
    ls_config-config_value = 'sap_horizon'.
    ls_config-config_type  = 'STRING'.
    ls_config-description  = 'Default UI5 Theme'.
    ls_config-is_active    = abap_true.
    ls_config-user_id      = ''.
    ls_config-is_locked    = abap_false.
    ls_config-created_by   = sy-uname.
    ls_config-changed_by   = sy-uname.
    ls_config-created_at   = lv_timestamp.
    ls_config-changed_at   = lv_timestamp.
    APPEND ls_config TO lt_default_configs.

    " Debug mode - unlocked for user customization
    CLEAR ls_config.
    ls_config-config_key   = 'DEBUG_MODE'.
    ls_config-config_value = ''.
    ls_config-config_type  = 'BOOLEAN'.
    ls_config-description  = 'Debug Mode Setting'.
    ls_config-is_active    = abap_true.
    ls_config-user_id      = ''.
    ls_config-is_locked    = abap_false.
    ls_config-created_by   = sy-uname.
    ls_config-changed_by   = sy-uname.
    ls_config-created_at   = lv_timestamp.
    ls_config-changed_at   = lv_timestamp.
    APPEND ls_config TO lt_default_configs.

    " UI5 Bootstrap source - locked for security (master user only)
    CLEAR ls_config.
    ls_config-config_key   = 'UI5_SRC'.
    ls_config-config_value = 'https://sdk.openui5.org/resources/sap-ui-cachebuster/sap-ui-core.js'.
    ls_config-config_type  = 'STRING'.
    ls_config-description  = 'UI5 Bootstrap Source'.
    ls_config-is_active    = abap_true.
    ls_config-user_id      = ''.
    ls_config-is_locked    = abap_true.
    ls_config-created_by   = sy-uname.
    ls_config-changed_by   = sy-uname.
    ls_config-created_at   = lv_timestamp.
    ls_config-changed_at   = lv_timestamp.
    APPEND ls_config TO lt_default_configs.

    " Application title - unlocked for customization
    CLEAR ls_config.
    ls_config-config_key   = 'APP_TITLE'.
    ls_config-config_value = 'abap2UI5'.
    ls_config-config_type  = 'STRING'.
    ls_config-description  = 'Application Title'.
    ls_config-is_active    = abap_true.
    ls_config-user_id      = ''.
    ls_config-is_locked    = abap_false.
    ls_config-created_by   = sy-uname.
    ls_config-changed_by   = sy-uname.
    ls_config-created_at   = lv_timestamp.
    ls_config-changed_at   = lv_timestamp.
    APPEND ls_config TO lt_default_configs.

    " Insert configurations
    MODIFY z2ui5_t_29 FROM TABLE lt_default_configs.

    " Initialize themes based on UI5 compatibility matrix
    " For themes, create a structure and populate it


    " sap_horizon themes (UI5 1.96+)
    ls_theme_entry-ui5_version = '1.96'.
    ls_theme_entry-theme       = 'sap_horizon'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.101'.
    ls_theme_entry-theme       = 'sap_horizon'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.120'.
    ls_theme_entry-theme       = 'sap_horizon'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.136'.
    ls_theme_entry-theme       = 'sap_horizon'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    " sap_horizon_dark themes (UI5 1.101+)
    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.101'.
    ls_theme_entry-theme       = 'sap_horizon_dark'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.120'.
    ls_theme_entry-theme       = 'sap_horizon_dark'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.136'.
    ls_theme_entry-theme       = 'sap_horizon_dark'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    " sap_horizon_hcb themes (UI5 1.101+)
    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.101'.
    ls_theme_entry-theme       = 'sap_horizon_hcb'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.120'.
    ls_theme_entry-theme       = 'sap_horizon_hcb'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.136'.
    ls_theme_entry-theme       = 'sap_horizon_hcb'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    " sap_horizon_hcw themes (UI5 1.101+)
    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.101'.
    ls_theme_entry-theme       = 'sap_horizon_hcw'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.120'.
    ls_theme_entry-theme       = 'sap_horizon_hcw'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.136'.
    ls_theme_entry-theme       = 'sap_horizon_hcw'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    " sap_fiori_3 themes (UI5 1.65+)
    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.65'.
    ls_theme_entry-theme       = 'sap_fiori_3'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    " sap_fiori_3 themes (UI5 1.69+)
    CLEAR ls_theme_entry.
    ls_theme_entry-ui5_version = '1.69'.
    ls_theme_entry-theme       = 'sap_fiori_3'.
    ls_theme_entry-is_active   = abap_true.
    ls_theme_entry-created_by  = sy-uname.
    ls_theme_entry-changed_by  = sy-uname.
    ls_theme_entry-created_at  = lv_timestamp.
    ls_theme_entry-changed_at  = lv_timestamp.
    MODIFY z2ui5_t_30 FROM ls_theme_entry.

    COMMIT WORK AND WAIT.
  ENDMETHOD.
ENDCLASS.
