class lcl_jwt definition
  final
  create public .

  public section.

    " Based on:
    " https://github.com/abapChaoLiu/abap_jwt_generator
    " https://blogs.sap.com/2019/11/10/
    "  connect-from-as-abap-to-google-cloud-platform-app-engine-resource-secured-with-google-identity-aware-proxy

    constants: " include SSFCONST
      c_ssf_sha256_alg type ssfhash value 'SHA256' ##NO_TEXT,
      c_ssf_pkcs1_standard_padding type ssfform value 'PKCS1-V1.5' ##NO_TEXT,
      c_ssf_signer_id_implicit type ssfid value '<implicit>' ##NO_TEXT,
      c_ssf_srresults_undefined type ssfinfo-result value 28. " ssf_srresults const

    class-methods create_rs256_signed_jwt
      importing
        iv_jwt_header type string
        iv_jwt_payload type string
        iv_ssf_profilename type ssfprof
        iv_ssf_id type ssfid default c_ssf_signer_id_implicit
        iv_ssf_result type ssfresult default c_ssf_srresults_undefined
      returning
        value(rv_signed_jwt_base64) type string
      raising
        zcx_aha_error.

    class-methods sign
      importing
        iv_str_to_sign type string
        iv_ssf_profilename type ssfprof
        iv_ssf_id type ssfid default c_ssf_signer_id_implicit
        iv_ssf_result type ssfresult default c_ssf_srresults_undefined
      returning
        value(rv_signature) type string
      raising
        zcx_aha_error.

    class-methods base64_url_encode
      changing
        cv_base64 type string.

  protected section.

  private section.

    types:
      tty_tssfbin type standard table of ssfbin with key table_line.
      " solixtab ? line type raw255

    class-methods string_to_binary_tab
      importing
        iv_string type string
      returning
        value(rt_bin_tab) type tty_tssfbin
      raising
        zcx_aha_error.

    class-methods binary_tab_to_string
      importing
        it_bin_tab type tty_tssfbin
        iv_length  type i
      returning
        value(rv_string) type string
      raising
        zcx_aha_error.

endclass.

class lcl_jwt implementation.

  method base64_url_encode.
    replace all occurrences of '=' in cv_base64 with ''.
    replace all occurrences of '+' in cv_base64 with '-'.
    replace all occurrences of '/' in cv_base64 with '_'.
  endmethod.

  method create_rs256_signed_jwt.

    data lv_jwt_header_base64 type string.
    data lv_jwt_payload_base64 type string.
    data lv_data_base64 type string.
    data lv_signature type string.

    lv_jwt_header_base64 = cl_http_utility=>encode_base64( unencoded = iv_jwt_header ).
    lv_jwt_payload_base64 = cl_http_utility=>encode_base64( unencoded = iv_jwt_payload ).

    lv_data_base64 = |{ lv_jwt_header_base64 }.{ lv_jwt_payload_base64 }|.
    base64_url_encode( changing cv_base64 = lv_data_base64 ).

    lv_signature = sign(
      iv_str_to_sign     = lv_data_base64
      iv_ssf_profilename = iv_ssf_profilename
      iv_ssf_id          = iv_ssf_id
      iv_ssf_result      = iv_ssf_result ).

    lv_signature = cl_http_utility=>encode_base64( unencoded = lv_signature ).
    base64_url_encode( changing cv_base64 = lv_signature ).

    rv_signed_jwt_base64 = |{ lv_data_base64 }.{ lv_signature }|.

  endmethod.

  method sign.

    data lt_input_bin type tty_tssfbin.
    data lt_output_bin type tty_tssfbin.
    data lv_input_length type ssflen.
    data lv_output_length type ssflen.
    data lv_output_crc type ssfreturn.
    data lt_signer type standard table of ssfinfo.
    data ls_signer like line of lt_signer.

    lt_input_bin = string_to_binary_tab( iv_str_to_sign ).
    lv_input_length = strlen( iv_str_to_sign ).

    ls_signer-id      = iv_ssf_id.
    ls_signer-profile = iv_ssf_profilename.
    ls_signer-result  = iv_ssf_result.
    append ls_signer to lt_signer.

    call function 'SSF_KRN_SIGN'
      exporting
        str_format                   = c_ssf_pkcs1_standard_padding
        b_inc_certs                  = abap_false
        b_detached                   = abap_false
        b_inenc                      = abap_false
        ostr_input_data_l            = lv_input_length
        str_hashalg                  = c_ssf_sha256_alg
      importing
        ostr_signed_data_l           = lv_output_length
        crc                          = lv_output_crc    " ssf return code
      tables
        ostr_input_data              = lt_input_bin
        signer                       = lt_signer
        ostr_signed_data             = lt_output_bin
      exceptions
        ssf_krn_error                = 1
        ssf_krn_noop                 = 2
        ssf_krn_nomemory             = 3
        ssf_krn_opinv                = 4
        ssf_krn_nossflib             = 5
        ssf_krn_signer_list_error    = 6
        ssf_krn_input_data_error     = 7
        ssf_krn_invalid_par          = 8
        ssf_krn_invalid_parlen       = 9
        ssf_fb_input_parameter_error = 10.
    if sy-subrc <> 0.
      zcx_aha_error=>raise( |signature_failed [{ sy-subrc }]| ).
    endif.

    " check also FM SSFC_BASE64_ENCODE
    rv_signature = binary_tab_to_string(
      it_bin_tab = lt_output_bin
      iv_length  = lv_output_length ).

  endmethod.

  method string_to_binary_tab.

    data lv_xstring type xstring.
    data lv_len type i.

    call function 'SCMS_STRING_TO_XSTRING'
      exporting
        text     = iv_string
        encoding = '4110'
      importing
        buffer   = lv_xstring
      exceptions
        failed   = 1
        others   = 2.
    if sy-subrc <> 0.
      zcx_aha_error=>raise( 'string_to_binary_tab failed' ).
    endif.

    call function 'SCMS_XSTRING_TO_BINARY'
      exporting
        buffer     = lv_xstring
      importing
        output_length = lv_len
      tables
        binary_tab = rt_bin_tab.

  endmethod.

  method binary_tab_to_string.

    call function 'SCMS_BINARY_TO_STRING'
      exporting
        input_length = iv_length
        encoding     = '4110'
      importing
        text_buffer  = rv_string
      tables
        binary_tab   = it_bin_tab
      exceptions
        failed       = 1
        others       = 2.
    if sy-subrc <> 0.
      zcx_aha_error=>raise( 'binary_tab_to_string failed' ).
    endif.

  endmethod.

endclass.
