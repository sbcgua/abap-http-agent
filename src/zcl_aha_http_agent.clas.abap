class zcl_aha_http_agent definition
  public
  final
  create private.

  public section.

    interfaces zif_aha_http_agent.

    class-methods create_for_rfc_destination
      importing
        !iv_destination type c
      returning
        value(ri_instance) type ref to zif_aha_http_agent
      raising
        zcx_aha_error.

    class-methods create_for_url
      importing
        !iv_url type csequence
      returning
        value(ri_instance) type ref to zif_aha_http_agent
      raising
        zcx_aha_error.

    methods constructor
      importing
        !iv_url type csequence optional
        !iv_destination type c optional
      raising
        zcx_aha_error.

  protected section.
  private section.

    data mv_destination type rfcdest.
    data mv_url type string.

    class-methods is_multipart_tab
      importing
        io_type type ref to cl_abap_typedescr
      returning
        value(rv_yes) type abap_bool.

    class-methods is_ajson
      importing
        io_type type ref to cl_abap_typedescr
        iv_payload type any
      returning
        value(rv_yes) type abap_bool.

    class-methods attach_payload
      importing
        ii_request type ref to if_http_request
        iv_payload type any
      raising
        zcx_aha_error.

    class-methods is_method_w_body
      importing
        iv_method type zif_aha_http_agent=>ty_http_method
      returning
        value(rv_yes) type abap_bool.

ENDCLASS.



CLASS ZCL_AHA_HTTP_AGENT IMPLEMENTATION.


  method attach_payload.

    data lo_type type ref to cl_abap_typedescr.
    lo_type = cl_abap_typedescr=>describe_by_data( iv_payload ).

    if lo_type->type_kind = cl_abap_typedescr=>typekind_xstring.
      ii_request->set_data( iv_payload ).

    elseif lo_type->type_kind = cl_abap_typedescr=>typekind_string or lo_type->type_kind = cl_abap_typedescr=>typekind_char.
      ii_request->set_cdata( iv_payload ).

    elseif is_multipart_tab( lo_type ) = abap_true.
      field-symbols <parts> type zif_aha_http_agent=>tt_multipart.
      field-symbols <part> like line of <parts>.
      assign iv_payload to <parts>.

      ii_request->set_header_field(
        name  = 'content-type'
        value = 'multipart/form-data' ).

      loop at <parts> assigning <part>.
        if <part>-name is initial or <part>-filename is initial or <part>-content_type is initial.
          zcx_aha_error=>raise( |multi part [{ sy-tabix }] is incomplete| ).
        endif.

        data lo_part type ref to if_http_entity.
        lo_part = ii_request->add_multipart( ).
        data lv_filename type string.
        lv_filename = cl_http_utility=>if_http_utility~escape_url( <part>-filename ).
        lo_part->set_header_field(
          name  = 'content-disposition'
          value = |form-data; name="{ <part>-name }"; filename*=UTF-8''{ lv_filename }; filename="{ <part>-filename }"| ).
        lo_part->set_content_type( <part>-content_type ).
        lo_part->set_data( <part>-data ).
      endloop.

    elseif is_ajson( io_type = lo_type iv_payload = iv_payload ) = abap_true. " maybe request just "stringifiable ?"
      data li_ajson type ref to zif_ajson.
      data lx_ajson type ref to zcx_ajson_error.
      data lv_xdata type xstring.

      li_ajson ?= iv_payload.

      ii_request->set_header_field(
        name  = 'content-type'
        value = 'application/json; charset=utf-8' ).

      try.
        lv_xdata = lcl_utils=>string_to_xstring_utf8( li_ajson->stringify( ) ).
      catch zcx_ajson_error into lx_ajson.
        zcx_aha_error=>raise( lx_ajson->get_text( ) ).
      endtry.
      ii_request->set_data( lv_xdata ).

    else.
      zcx_aha_error=>raise( |Unexpected payload type { lo_type->absolute_name }| ).
    endif.

  endmethod.


  method constructor.

    mv_destination = iv_destination.
    mv_url = iv_url.

    if boolc( mv_url is initial ) = boolc( mv_destination is initial ).
      zcx_aha_error=>raise( 'Specify only one of url or destination' ).
    endif.

  endmethod.


  method create_for_rfc_destination.

    create object ri_instance type zcl_aha_http_agent
      exporting
        iv_destination = iv_destination.

  endmethod.


  method create_for_url.

    create object ri_instance type zcl_aha_http_agent
      exporting
        iv_url = iv_url.

  endmethod.


  method is_ajson.

    if io_type->type_kind <> cl_abap_typedescr=>typekind_oref.
      return.
    endif.

    try.
      data li_template type ref to zif_ajson.
      li_template ?= iv_payload.
      rv_yes = abap_true.
    catch cx_sy_move_cast_error.
    endtry.

    " TODO maybe make more indirect detection, in case ajson is integrated
    " e.g. by stringify and mt_node_tree

  endmethod.


  method is_method_w_body.

    rv_yes = boolc(
      iv_method = zif_aha_http_agent=>c_methods-post
      or iv_method = zif_aha_http_agent=>c_methods-delete
      or iv_method = zif_aha_http_agent=>c_methods-put
      or iv_method = zif_aha_http_agent=>c_methods-patch ).

  endmethod.


  method is_multipart_tab.

    data lt_multipart_dummy type zif_aha_http_agent=>tt_multipart.
    rv_yes = boolc( io_type->type_kind = cl_abap_typedescr=>typekind_table
      and io_type->absolute_name = cl_abap_typedescr=>describe_by_data( lt_multipart_dummy )->absolute_name ).

  endmethod.


  method zif_aha_http_agent~request.

    data li_client type ref to if_http_client.

    if mv_destination is not initial.
      li_client = lcl_client_factory=>create_http_client_by_dest( mv_destination ).
      cl_http_utility=>set_request_uri(
        request = li_client->request
        uri     = iv_uri ).
    else.
      li_client = lcl_client_factory=>create_http_client_by_url( mv_url ).
      if iv_uri is not initial.
        cl_http_utility=>set_request_uri(
          request = li_client->request
          uri     = iv_uri ).
      endif.
    endif.

    li_client->request->set_version( if_http_request=>co_protocol_version_1_1 ).
    li_client->request->set_method( iv_method ).

    if io_query is bound.
      field-symbols <p> like line of io_query->mt_entries.
      loop at io_query->mt_entries assigning <p>.
        li_client->request->set_form_field(
          name  = <p>-k
          value = <p>-v ).
      endloop.
    endif.

    if io_headers is bound.
      field-symbols <h> like line of io_query->mt_entries.
      loop at io_headers->mt_entries assigning <h>.
        li_client->request->set_header_field(
          name  = to_lower( <h>-k )
          value = <h>-v ).
      endloop.
    endif.

    if iv_payload is not initial and is_method_w_body( iv_method ) = abap_true.
      attach_payload(
        ii_request = li_client->request
        iv_payload = iv_payload ).
    endif.

*    FOR DEBUG
*    data lt_fields type tihttpnvp.
*    mi_client->request->get_header_fields( changing fields = lt_fields ).

    li_client->send(
      exceptions
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        others                     = 5 ).
    if sy-subrc = 0.
      li_client->receive(
        exceptions
          http_communication_failure = 1
          http_invalid_state         = 2
          http_processing_failed     = 3
          others                     = 4 ).
    endif.

    if sy-subrc <> 0.
      data lv_code type i.
      data lv_message type string.
      li_client->get_last_error(
        importing
          code    = lv_code
          message = lv_message ).
      zcx_aha_error=>raise( |HTTP error: [{ lv_code }] { lv_message }| ).
    endif.

    ri_response = lcl_http_response=>create( li_client ).

  endmethod.
ENDCLASS.
