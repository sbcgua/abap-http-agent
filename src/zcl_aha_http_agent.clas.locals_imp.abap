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

    class-methods to_urlencoded
      importing
        i_map type ref to zcl_abap_string_map
      returning
        value(rv_str) type string.

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

  method to_urlencoded.

    data lt_pairs type string_table.
    data lv_pair type string.
    field-symbols <e> like line of i_map->mt_entries.

    loop at i_map->mt_entries assigning <e>.
      lv_pair = <e>-k && '=' && cl_http_utility=>if_http_utility~escape_url( <e>-v ).
      append lv_pair to lt_pairs.
    endloop.

    rv_str = concat_lines_of( table = lt_pairs sep = `&` ).

  endmethod.

endclass.

**********************************************************************
* CLIENT FACTORY
**********************************************************************

class lcl_client_factory definition final.
  public section.
    class-methods create_http_client_by_dest
      importing
        iv_destination type c
      returning
        value(ri_http_client) type ref to if_http_client.

    class-methods create_http_client_by_url
      importing
        iv_url type string
      returning
        value(ri_http_client) type ref to if_http_client
      raising
        zcx_aha_error.

    class-methods inject_http_client
      importing
        ii_http_client type ref to if_http_client.

    class-methods parse_url
      importing
        iv_url type string
      exporting
        ev_host type string
        ev_uri  type string
      raising
        zcx_aha_error.

  private section.
    class-data gi_http_client type ref to if_http_client.
endclass.

class lcl_client_factory implementation.

  method parse_url.

    find regex '^(https?://[^/]+)(/.*)?$' in iv_url
      submatches ev_host ev_uri.
    if sy-subrc <> 0.
      zcx_aha_error=>raise( 'Mailformed url' ).
    endif.

  endmethod.

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

  method create_http_client_by_url.
    if gi_http_client is bound.
      ri_http_client = gi_http_client.
    else.
      data lv_host type string.
      data lv_uri  type string.

      parse_url(
        exporting
          iv_url = iv_url
        importing
          ev_host = lv_host
          ev_uri  = lv_uri ).

      cl_http_client=>create_by_url(
        exporting
          url    = lv_host
          ssl_id = 'ANONYM' " TODO support other IDs
          " TODO support proxies
        importing
          client = ri_http_client ).

      cl_http_utility=>set_request_uri(
        request = ri_http_client->request
        uri     = lv_uri ).
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
    data mo_headers type ref to zcl_abap_string_map.
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

  method zif_aha_http_response~headers.

    data lt_headers type tihttpnvp.

    if mo_headers is not bound.
      mi_response->get_header_fields( changing fields = lt_headers ).
      create object mo_headers
        exporting
          iv_case_insensitive = abap_true
          iv_from = lt_headers. " the type is compatible
    endif.

    ro_headers = mo_headers.

  endmethod.

  method zif_aha_http_response~json.

    data lv_content_type type string.

    lv_content_type = zif_aha_http_response~headers( )->get( 'content-type' ).

    " TODO check if it is json ?
    " TODO maybe also respect charset
    " 'application/json; charset=utf-8'

    data lv_data type xstring.
    lv_data = mi_response->get_data( ).

    data lv_cdata type string.
    lv_cdata = lcl_utils=>xstring_to_string_utf8( lv_data ).

    data lx_json type ref to zcx_ajson_error.
    try.
      ri_json = zcl_ajson=>parse( lv_cdata ).
    catch zcx_ajson_error into lx_json.
      zcx_aha_error=>raise( lx_json->get_text( ) ).
    endtry.

  endmethod.

endclass.
