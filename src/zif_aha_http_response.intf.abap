interface zif_aha_http_response
  public .

  methods data
    returning
      value(rv_data) type xstring .
  methods cdata
    returning
      value(rv_data) type string .

*  methods json
*    changing
*      !cv_container type any .
  methods is_ok
    returning
      value(rv_yes) type abap_bool .
  methods code
    returning
      value(rv_code) type i .
  methods error
    returning
      value(rv_message) type string .
  methods headers
    returning
      value(rt_headers) type zif_aha_http_agent=>tty_key_value .
  methods close .

endinterface.
