interface zif_aha_http_agent
  public.

  constants version type string value 'v2.0.0-alpha'.
  constants origin type string value 'https://github.com/sbcgua/abap-http-agent'.
  constants license type string value 'MIT'.

  types ty_http_method type string.
  constants:
    begin of c_methods,
      get    type ty_http_method value 'GET',
      post   type ty_http_method value 'POST',
      put    type ty_http_method value 'PUT',
      delete type ty_http_method value 'DELETE',
      patch  type ty_http_method value 'PATCH',
    end of c_methods.

  types:
    begin of ty_multipart,
      name         type string,
      filename     type string,
      content_type type string,
      data         type xstring,
    end of ty_multipart.
  types:
    tt_multipart type standard table of ty_multipart with key name.
  types:
    begin of ty_key_value,
      key type string,
      val type string,
    end of ty_key_value,
    tty_key_value type standard table of ty_key_value with key key.

  methods request
    importing
      !iv_uri     type string    " URI, not URL ! without host
      !iv_method  type ty_http_method default c_methods-get
      !io_query   type ref to zcl_abap_string_map optional
      !io_headers type ref to zcl_abap_string_map optional
      !iv_payload type any optional " can be string, xstring, tt_multipart, ajson
    returning
      value(ri_response) type ref to zif_aha_http_response
    raising
      zcx_aha_error.

endinterface.
