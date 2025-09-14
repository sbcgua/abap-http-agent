class ZCL_AHA_JWT definition
  public
  final
  create public.

  public section.

    class-methods get_iat_unixtime
      returning
        value(rv_iat) type i.
    class-methods hex_str_to_base64
      importing
        !i_hex_str type string
      returning
        value(rv_base64_str) type string.

    class-methods create_rs256_jwt
      importing
        !i_ssf_profilename type ssfprof
        !i_iss type string
        !i_aud type string
        !i_sub type string optional
        !i_kid type string optional
        !i_scope type string optional
        !i_x5t type string optional
        !i_jti type string optional
        !i_expire_in type i default 600
      returning
        value(rv_signed_jwt_base64) type string
      raising
        zcx_aha_error.

    class-methods ssfappl_to_profile_name
      importing
        !i_ssfappl type ssfappl
      returning
        value(rv_profile_name) type ssfpsename
      raising
        zcx_aha_error.

  protected section.
  private section.
ENDCLASS.



CLASS ZCL_AHA_JWT IMPLEMENTATION.


  method create_rs256_jwt.

    data lx_json type ref to zcx_ajson_error.
    data li_json_header type ref to zif_ajson.
    data li_json_payload type ref to zif_ajson.
    data lv_str_header type string.
    data lv_str_payload type string.
    data lv_ts type i.

    try.
      li_json_header = zcl_ajson=>create_empty(
      )->set(
        iv_path = 'alg'
        iv_val  = 'RS256'
      )->set(
        iv_path = 'typ'
        iv_val  = 'JWT' ).

      if i_x5t is not initial.
        li_json_header->set(
          iv_path = 'x5t'
          iv_val  = i_x5t ).
      endif.

      if i_kid is not initial.
        li_json_header->set(
          iv_path = 'kid'
          iv_val  = i_kid ).
      endif.

      lv_ts = get_iat_unixtime( ).

      li_json_payload = zcl_ajson=>create_empty(
      )->set(
        iv_path = 'iss'
        iv_val  = i_iss
      )->set(
        iv_path = 'aud'
        iv_val  = i_aud
      )->set(
        iv_path = 'iat'
        iv_val  = lv_ts
*      )->set(
*        iv_path = 'nbf' " ??? maybe make it optional
*        iv_val  = lv_ts
      )->set(
        iv_path = 'exp'
        iv_val  = lv_ts + i_expire_in ).

      if i_sub is not initial.
        li_json_payload->set(
          iv_path = 'sub'
          iv_val  = i_sub ).
      endif.

      if i_scope is not initial.
        li_json_payload->set(
          iv_path = 'scope'
          iv_val  = i_scope ).
      endif.

      if i_jti is not initial.
        li_json_payload->set(
          iv_path = 'jti'
          iv_val  = i_jti ).
      endif.

      lv_str_header  = li_json_header->stringify( ).
      lv_str_payload = li_json_payload->stringify( ).

      rv_signed_jwt_base64 = lcl_jwt=>create_rs256_signed_jwt(
        iv_jwt_header        = lv_str_header
        iv_jwt_payload       = lv_str_payload
        iv_ssf_profilename   = i_ssf_profilename ).

    catch zcx_ajson_error into lx_json.
      zcx_aha_error=>raise( |JSON error: { lx_json->get_text( ) }| ).
    endtry.

  endmethod.


  method get_iat_unixtime.

    data lv_unix_iat type string.
    data lv_timestamp type timestamp.
    data lv_date type d.
    data lv_time type t.
    data lv_zone type tzonref-tzone value 'UTC'.

    get time stamp field lv_timestamp.
    convert time stamp lv_timestamp time zone lv_zone into date lv_date time lv_time.

    cl_pco_utility=>convert_abap_timestamp_to_java(
      exporting
        iv_date      = lv_date
        iv_time      = lv_time
        iv_msec      = 0
      importing
        ev_timestamp = lv_unix_iat ).

    rv_iat = substring(
      val = lv_unix_iat
      off = 0
      len = strlen( lv_unix_iat ) - 3 ).

  endmethod.


  method hex_str_to_base64.

    data l_x type xstring.
    l_x = i_hex_str.

    call function 'SCMS_BASE64_ENCODE_STR'
      exporting
        input = l_x
      importing
        output = rv_base64_str.

  endmethod.


  method ssfappl_to_profile_name.

    data lx type ref to cx_abap_pse.

    try.
      cl_abap_pse=>get_pse_file_name(
        exporting
          iv_context = 'SSFA'
          iv_application = i_ssfappl
        importing
          ev_psename = rv_profile_name ).
    catch cx_abap_pse into lx.
      zcx_aha_error=>raise( lx->get_text( ) ).
    endtry.

  endmethod.
ENDCLASS.
