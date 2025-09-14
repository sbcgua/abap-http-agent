class ZCL_AHA_UTILS definition
  public
  final
  create public.

  public section.

    class-methods token_request
      importing
        iv_jwt type string
      returning
        value(ro_payload) type ref to zcl_abap_string_map.

    class-methods add_bearer_token
      importing
        iv_token type string
        io_headers type ref to zcl_abap_string_map optional
      returning
        value(ro_headers) type ref to zcl_abap_string_map.

  protected section.
  private section.
ENDCLASS.



CLASS ZCL_AHA_UTILS IMPLEMENTATION.


  method add_bearer_token.

    if io_headers is bound.
      ro_headers = io_headers.
    else.
      ro_headers = zcl_abap_string_map=>create( ).
    endif.

    ro_headers->set(
      iv_key = 'Authorization'
      iv_val = |Bearer { iv_token }| ).

  endmethod.


  method token_request.

    ro_payload = zcl_abap_string_map=>create( ).
    ro_payload->set(
      iv_key = 'grant_type'
      iv_val = 'urn:ietf:params:oauth:grant-type:jwt-bearer' ).
    ro_payload->set(
      iv_key = 'assertion'
      iv_val = iv_jwt ).

  endmethod.
ENDCLASS.
