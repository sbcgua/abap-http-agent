interface zif_aha_http_agent
  public .

  constants:
    version type string value 'v0.0.1'.

  constants:
    begin of c_methods,
      get    type string value 'GET',
      post   type string value 'POST',
      put    type string value 'PUT',
      delete type string value 'DELETE',
      patch  type string value 'PATCH',
    end of c_methods.

  types:
    begin of ty_multipart,
      name type string,
      filename type string,
      content_type type string,
      data type xstring,
    end of ty_multipart .
  types:
    tt_multipart type standard table of ty_multipart with key name .
  types:
    begin of ty_key_value,
      key type string,
      val type string,
    end of ty_key_value,
    tty_key_value type standard table of ty_key_value with key key.

  methods request
    importing
      !iv_uri type string    " URI, not URL ! without host
      !iv_method type string default c_methods-get
      !it_query type any table optional
      !it_headers type any table optional
      !iv_payload type any optional " can be string, xstring, tt_multipart
    returning
      value(ri_response) type ref to zif_aha_http_response
    raising
      zcx_aha_error .

endinterface.
