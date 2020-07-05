![abaplint](https://github.com/sbcgua/abap-http-agent/workflows/abaplint/badge.svg)
![abap package version](https://img.shields.io/endpoint?url=https://shield.abap.space/version-shield-json/github/sbcgua/abap-http-agent/src/zif_aha_http_agent.intf.abap)

# AHA - abap http agent

Convenience wrapper over cl_http_client

WIP

TODO:
- url destination
- integrate with json ?
- proxy ?
- resumable password exception ?

## Example

### GET

```abap
data lt_query type zif_aha_http_agent=>tty_key_value.
data lt_header type zif_aha_http_agent=>tty_key_value.
field-symbols <e> like line of lt_query.

append initial line to lt_query assigning <e>.
<e>-key = 'id'.
<e>-val = '1234'.
append initial line to lt_header assigning <e>.
<e>-key = 'content-type'.
<e>-val = 'application/json'.

data lo_agent type ref to zif_aha_http_agent.
data li_resp type ref to zif_aha_http_response.
lo_agent = zcl_aha_http_agent=>create( iv_destination = 'MYDESTINATION' ).

li_resp = lo_agent->request(
    iv_uri     = 'service/1'
    it_query   = lt_query
    it_headers = lt_header ).

if li_resp->is_ok( ) = abap_true.
    do_my_processing( li_resp->data( ) ).
else.
    report_error( li_resp->error( ) ).
endif.
```

headers and query integrates well with [abap-string-map](https://github.com/sbcgua/abap-string-map)

```abap
data lo_query type ref to zcl_abap_string_map.
create object lo_query.

lo_query->set( iv_key = 'id' iv_val = '1234' ).
...
li_resp = lo_agent->request(
    iv_uri     = 'service/1'
    it_query   = lo_query->mt_entries ).
```

### POST

```abap
data lo_agent type ref to zif_aha_http_agent.
lo_agent = zcl_aha_http_agent=>create( iv_destination = 'MYDESTINATION' ).

data lv_payload type xstring value '102030'.

lo_agent->request(
    iv_method  = zif_aha_http_response=>c_methods-post
    iv_uri     = 'service/1'
    iv_payload = lv_payload ).
```

### Multipart payload

```abap
data lt_multipart type zif_aha_http_agent=>tt_multipart.
field-symbols <mp> like line of lt_multipart.
append initial line to lt_multipart assigning <mp>.
<mp>-content_type = 'application/pdf'.
<mp>-data         = 'some binary data here...'.
<mp>-filename     = 'myfile.pdf'.
<mp>-name         = 'myfile'.

lo_cut->request(
    iv_method  = zif_aha_http_response=>c_methods-post
    iv_uri     = 'service/1'
    iv_payload = lt_multipart ).
```

