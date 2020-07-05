class zcl_aha_http_agent definition
  public
  final
  create private .

  public section.

    interfaces zif_aha_http_agent .

    class-methods create
      importing
        !iv_destination type c
      returning
        value(ri_instance) type ref to zif_aha_http_agent .

    methods constructor
      importing
        !iv_destination type c.

  protected section.
  private section.

    data mv_destination type rfcdest.

    class-methods is_multipart_tab
      importing
        io_type type ref to cl_abap_typedescr
      returning
        value(rv_yes) type abap_bool.

    class-methods attach_payload
      importing
        ii_request type ref to if_http_request
        iv_payload type any
      raising
        zcx_aha_error.

ENDCLASS.



CLASS ZCL_AHA_HTTP_AGENT IMPLEMENTATION.


  method attach_payload.

    data lo_type type ref to cl_abap_typedescr.
    lo_type = cl_abap_typedescr=>describe_by_data( iv_payload ).

    if lo_type->type_kind = cl_abap_typedescr=>typekind_xstring.
      ii_request->set_data( iv_payload ).

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
        lo_part->set_header_field(
          name  = 'content-disposition'
          value = |form-data; name="{ <part>-name }"; filename="{ <part>-filename }"| ).
        lo_part->set_content_type( <part>-content_type ).
        lo_part->set_data( <part>-data ).
      endloop.

    else.
      zcx_aha_error=>raise( |Unexpected payload type { lo_type->absolute_name }| ).
    endif.

  endmethod.


  method constructor.

    mv_destination = iv_destination.

  endmethod.


  method create.

    create object ri_instance type zcl_aha_http_agent
      exporting
        iv_destination = iv_destination.

  endmethod.


  method is_multipart_tab.

    data lt_multipart_dummy type zif_aha_http_agent=>tt_multipart.
    rv_yes = boolc( io_type->type_kind = cl_abap_typedescr=>typekind_table
      and io_type->absolute_name = cl_abap_typedescr=>describe_by_data( lt_multipart_dummy )->absolute_name ).

  endmethod.


  method zif_aha_http_agent~request.

    data li_client type ref to if_http_client.

    li_client = lcl_client_factory=>create_http_client_by_dest( mv_destination ).
    li_client->request->set_version( if_http_request=>co_protocol_version_1_1 ).
    li_client->request->set_method( iv_method ).

    cl_http_utility=>set_request_uri(
      request = li_client->request
      uri     = iv_uri ).

    if lines( it_query ) > 0.
      field-symbols <p> type zif_aha_http_agent=>ty_key_value.
      loop at it_query assigning <p> casting.
        li_client->request->set_form_field(
          name  = <p>-key
          value = <p>-val ).
      endloop.
    endif.

    if lines( it_headers ) > 0.
      field-symbols <h> type zif_aha_http_agent=>ty_key_value.
      loop at it_headers assigning <h> casting.
        li_client->request->set_header_field(
          name  = to_lower( <h>-key )
          value = <h>-val ).
      endloop.
    endif.

    if iv_method = zif_aha_http_agent=>c_methods-post
      or iv_method = zif_aha_http_agent=>c_methods-put
      or iv_method = zif_aha_http_agent=>c_methods-patch.
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
