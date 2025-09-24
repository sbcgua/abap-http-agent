interface zif_aha_http_response
  public.

  methods data
    returning
      value(rv_data) type xstring.
  methods cdata
    returning
      value(rv_data) type string.
  methods json
    returning
      value(ri_json) type ref to zif_ajson
    raising
      zcx_aha_error.

  methods is_ok
    returning
      value(rv_yes) type abap_bool.
  methods code
    returning
      value(rv_code) type i.
  methods error
    returning
      value(rv_message) type string.
  methods headers
    returning
      value(ro_headers) type ref to zcl_abap_string_map.
  methods close. " ?? maybe remove and automate

endinterface.
