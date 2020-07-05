class ltcl_if_http_client_mock definition
  for testing
  risk level harmless
  duration short
  final.

  public section.
    interfaces:
      if_http_client,
      if_http_request,
      if_http_response.

    types:
      begin of ty_header_fields,
        name type string,
        value type string,
      end of ty_header_fields,
      tt_header_fields type standard table of ty_header_fields.

    data mv_send_called type i.
    data mv_recv_called type i.
    data mv_last_data type xstring.
    data mt_req_header_fields type tt_header_fields.
    data mt_req_form_fields type tt_header_fields.
    data mv_method type string.
    data mv_content_type type string.
    data mt_multi type table of ref to ltcl_if_http_client_mock.

    data mv_resp_cdata type string.
    data mv_resp_data type xstring.
    data mv_resp_code type i.

    class-methods create
      returning
        value(ro_instance) type ref to ltcl_if_http_client_mock.

  private section.
endclass.

class ltcl_if_http_client_mock implementation.
  method create.
    create object ro_instance.
    ro_instance->if_http_client~request = ro_instance.
    ro_instance->if_http_client~response = ro_instance.
  endmethod.

  " if_http_client
  method if_http_client~send.
    mv_send_called = mv_send_called + 1.
  endmethod.
  method if_http_client~receive.
    mv_recv_called = mv_recv_called + 1.
  endmethod.
  method if_http_client~get_last_error.
  endmethod.

  " if_http_request
  method if_http_request~get_last_error.
  endmethod.
  method if_http_request~set_content_type.
    mv_content_type = content_type.
  endmethod.
  method if_http_request~set_data.
    mv_last_data = data.
  endmethod.
  method if_http_request~add_multipart.
    data mp like line of mt_multi.
    create object mp.
    append mp to mt_multi.
    entity = mp.
  endmethod.
  method if_http_request~set_version.
  endmethod.
  method if_http_request~set_method.
    mv_method = method.
  endmethod.
  method if_http_request~set_form_field.
    field-symbols <f> like line of mt_req_form_fields.
    append initial line to mt_req_form_fields assigning <f>.
    <f>-name  = name.
    <f>-value = value.
  endmethod.
  method if_http_request~set_header_field.
    field-symbols <f> like line of mt_req_header_fields.
    append initial line to mt_req_header_fields assigning <f>.
    <f>-name  = name.
    <f>-value = value.
  endmethod.

  " if_http_response
  method if_http_response~get_data.
    data = mv_resp_data.
  endmethod.
  method if_http_response~get_status.
    code = mv_resp_code.
  endmethod.
  method if_http_response~get_cdata.
    data = mv_resp_cdata.
  endmethod.
  method if_http_response~get_header_fields.
  endmethod.

endclass.

**********************************************************************

class ltcl_http_agent_test definition
  for testing
  risk level harmless
  duration short
  final.

  private section.

    data mo_client_mock type ref to ltcl_if_http_client_mock.

    methods setup.
    methods get for testing raising zcx_aha_error.
*    methods get_json for testing raising zcx_aha_error.
    methods post for testing raising zcx_aha_error.
    methods post_multipart for testing raising zcx_aha_error.

endclass.

class ltcl_http_agent_test implementation.

  method setup.
    mo_client_mock = ltcl_if_http_client_mock=>create( ).
    lcl_client_factory=>inject_http_client( mo_client_mock ).
  endmethod.

  method get.

    data lt_query type zif_aha_http_agent=>tty_key_value.
    data lt_header type zif_aha_http_agent=>tty_key_value.
    field-symbols <e> like line of lt_query.

    append initial line to lt_query assigning <e>.
    <e>-key = 'A'.
    <e>-val = 'B'.
    append initial line to lt_header assigning <e>.
    <e>-key = 'X'.
    <e>-val = 'Y'.

    data lo_cut type ref to zif_aha_http_agent.
    data li_resp type ref to zif_aha_http_response.
    lo_cut = zcl_aha_http_agent=>create( iv_destination = '???' ).

    li_resp = lo_cut->request(
      iv_uri     = 'service/1'
      it_query   = lt_query
      it_headers = lt_header ).

    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_method
      exp = 'GET' ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_send_called
      exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_recv_called
      exp = 1 ).

    " Query
    data lt_exp_pairs type ltcl_if_http_client_mock=>tt_header_fields.
    field-symbols <f> like line of lt_exp_pairs.
    append initial line to lt_exp_pairs assigning <f>.
    <f>-name = 'A'.
    <f>-value = 'B'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mt_req_form_fields
      exp = lt_exp_pairs ).

    " Headers
    clear lt_exp_pairs.
    append initial line to lt_exp_pairs assigning <f>.
    <f>-name = '~request_uri'.
    <f>-value = 'service/1'.
    append initial line to lt_exp_pairs assigning <f>.
    <f>-name = 'x'.
    <f>-value = 'Y'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mt_req_header_fields
      exp = lt_exp_pairs ).

    " Responce
    mo_client_mock->mv_resp_code = 202.
    mo_client_mock->mv_resp_data = '102030'.
    cl_abap_unit_assert=>assert_equals(
      act = li_resp->data( )
      exp = '102030' ).
    cl_abap_unit_assert=>assert_equals(
      act = li_resp->code( )
      exp = 202 ).
    cl_abap_unit_assert=>assert_equals(
      act = li_resp->is_ok( )
      exp = abap_true ).

    " Failure code
    mo_client_mock->mv_resp_code = 404.
    cl_abap_unit_assert=>assert_equals(
      act = li_resp->is_ok( )
      exp = abap_false ).

  endmethod.

*  method get_json.
*
*    data lo_cut type ref to zif_aha_http_agent.
*    data li_resp type ref to zif_aha_http_response.
*    lo_cut = zcl_aha_http_agent=>create( iv_destination = '???' ).
*
*    li_resp = lo_cut->request( iv_uri = 'service/1' ).
*
*    " Responce
*
*    types:
*      begin of lty_dummy,
*        a type string,
*        b type string,
*      end of lty_dummy.
*    data ls_act type lty_dummy.
*    data ls_exp type lty_dummy.
*    ls_exp-a = '123'.
*    ls_exp-b = 'qwe'.
*
*    mo_client_mock->mv_resp_data = lcl_utils=>string_to_xstring_utf8( '{ "a": "123", "b": "qwe" }' ).
*    li_resp->json( changing cv_container = ls_act ).
*    cl_abap_unit_assert=>assert_equals(
*      act = ls_act
*      exp = ls_exp ).
*
*  endmethod.

  method post.

    data lo_cut type ref to zif_aha_http_agent.
    constants lv_payload type xstring value '102030'.
    lo_cut = zcl_aha_http_agent=>create( iv_destination = '???' ).

    lo_cut->request(
      iv_method  = 'POST'
      iv_uri     = 'service/1'
      iv_payload = lv_payload ).

    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_method
      exp = 'POST' ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_send_called
      exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_recv_called
      exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_last_data
      exp = lv_payload ).

  endmethod.

  method post_multipart.

    data lo_cut type ref to zif_aha_http_agent.
    data lt_multipart type zif_aha_http_agent=>tt_multipart.

    field-symbols <mp> like line of lt_multipart.
    append initial line to lt_multipart assigning <mp>.
    <mp>-content_type = 'pdf'.
    <mp>-data         = '102030'.
    <mp>-filename     = 'myfile.txt'.
    <mp>-name         = 'myfile'.

    lo_cut = zcl_aha_http_agent=>create( iv_destination = '???' ).

    lo_cut->request(
      iv_method  = 'POST'
      iv_uri     = 'service/1'
      iv_payload = lt_multipart ).

    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_method
      exp = 'POST' ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_send_called
      exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mv_recv_called
      exp = 1 ).

    " Headers
    data lt_exp_pairs type ltcl_if_http_client_mock=>tt_header_fields.
    field-symbols <f> like line of lt_exp_pairs.

    append initial line to lt_exp_pairs assigning <f>.
    <f>-name  = '~request_uri'.
    <f>-value = 'service/1'.
    append initial line to lt_exp_pairs assigning <f>.
    <f>-name  = 'content-type'.
    <f>-value = 'multipart/form-data'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_client_mock->mt_req_header_fields
      exp = lt_exp_pairs ).

    " Multipart
    cl_abap_unit_assert=>assert_equals(
      act = lines( mo_client_mock->mt_multi )
      exp = 1 ).

    data lo_mp like line of mo_client_mock->mt_multi.
    read table mo_client_mock->mt_multi into lo_mp index 1.

    cl_abap_unit_assert=>assert_equals(
      act = lo_mp->mv_last_data
      exp = '102030' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_mp->mv_content_type
      exp = 'pdf' ).

    " part header
    clear lt_exp_pairs.
    append initial line to lt_exp_pairs assigning <f>.
    <f>-name  = 'content-disposition'.
    <f>-value = 'form-data; name="myfile"; filename="myfile.txt"'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_mp->mt_req_header_fields
      exp = lt_exp_pairs ).

  endmethod.

endclass.
