**********************************************************************
* CLIENT FACTORY
**********************************************************************

class lcl_client_factory definition final.
  public section.
    class-methods create_http_client_by_dest
      importing
        iv_destination type c
      returning
        value(ri_http_client) type ref to if_http_client .

    class-methods inject_http_client
      importing
        ii_http_client type ref to if_http_client .

  private section.
    class-data gi_http_client type ref to if_http_client.
endclass.

class lcl_client_factory implementation.
  method create_http_client_by_dest.
    if gi_http_client is bound.
      ri_http_client = gi_http_client.
    else.
      cl_http_client=>create_by_destination(
        exporting
          destination = iv_destination
        importing
          client = ri_http_client ).
    endif.
  endmethod.

  method inject_http_client.
    gi_http_client = ii_http_client.
  endmethod.
endclass.

**********************************************************************
* RESPONSE
**********************************************************************

class lcl_http_response definition final friends zif_aha_http_agent.
  public section.

    interfaces zif_aha_http_response.

    class-methods create
      importing
        ii_client type ref to if_http_client
      returning
        value(ri_response) type ref to zif_aha_http_response.

  private section.
    data mi_client type ref to if_http_client.
    data mi_response type ref to if_http_response.
endclass.

class lcl_http_response implementation.

  method create.
    data lo_response type ref to lcl_http_response.
    create object lo_response.
    lo_response->mi_client   = ii_client.
    lo_response->mi_response = ii_client->response.
    ri_response ?= lo_response.
  endmethod.

  method zif_aha_http_response~close.
    mi_client->close( ).
  endmethod.

  method zif_aha_http_response~is_ok.
    data lv_code type i.
    lv_code = zif_aha_http_response~code( ).
    rv_yes = boolc( lv_code >= 200 and lv_code < 300 ).
  endmethod.

  method zif_aha_http_response~data.
    rv_data = mi_response->get_data( ).
  endmethod.

  method zif_aha_http_response~cdata.
    rv_data = mi_response->get_cdata( ).
  endmethod.

  method zif_aha_http_response~code.
    data lv_msg type string ##NEEDED.
    mi_response->get_status(
      importing
        reason = lv_msg " for debug
        code   = rv_code ).
  endmethod.

  method zif_aha_http_response~error.
    rv_message = mi_response->get_cdata( ). " TODO ???
  endmethod.

*  method zif_aha_http_response~json.
*    data lv_xdata type xstring.
*    lv_xdata = mi_response->get_data( ).
*    data lv_data type string.
*    lv_data = cl_abap_codepage=>convert_from( lv_xdata ).
*    zcl_aha_utils=>parse_json(
*      exporting
*        iv_json_string = lv_data
*      importing
*        ev_container = cv_container ).
*  endmethod.

  method zif_aha_http_response~headers.

    data lt_headers type tihttpnvp.
    field-symbols <h> like line of lt_headers.
    field-symbols <pair> like line of rt_headers.

    mi_response->get_header_fields( changing fields = lt_headers ).
    loop at lt_headers assigning <h>.
      append initial line to rt_headers assigning <pair>.
      <pair>-key = <h>-name.
      <pair>-val = <h>-value.
    endloop.

  endmethod.

endclass.

**********************************************************************
* UTILS
**********************************************************************
class lcl_utils definition final.
  public section.

    class-methods string_to_xstring_utf8
      importing
        !iv_str type string
      returning
        value(rv_xstr) type xstring
      raising
        zcx_aha_error.

    class-methods xstring_to_string_utf8
      importing
        !iv_xstr type xstring
      returning
        value(rv_str) type string
      raising
        zcx_aha_error.

endclass.

class lcl_utils implementation.

  method string_to_xstring_utf8.

    data lo_conv type ref to cl_abap_conv_out_ce.

    try.
      lo_conv = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).
      lo_conv->convert(
        exporting
          data = iv_str
        importing
          buffer = rv_xstr ).

    catch cx_parameter_invalid_range
          cx_sy_codepage_converter_init
          cx_sy_conversion_codepage
          cx_parameter_invalid_type.
      zcx_aha_error=>raise( 'conversion failed' ).
    endtry.

  endmethod.

  method xstring_to_string_utf8.

    data lo_conv type ref to cl_abap_conv_in_ce.

    try.
      lo_conv = cl_abap_conv_in_ce=>create( encoding = 'UTF-8' ).
      lo_conv->convert(
        exporting
          input = iv_xstr
        importing
          data = rv_str ).

    catch cx_parameter_invalid_range
          cx_sy_codepage_converter_init
          cx_sy_conversion_codepage
          cx_parameter_invalid_type.
      zcx_aha_error=>raise( 'conversion failed' ).
    endtry.

  endmethod.

endclass.
