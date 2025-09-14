# Dev notes over JWT generation in ABAP

## Useful links

- [Call Google Cloud APIs from ABAP (on-premise) using a signed JWT](https://jacekw.dev/blog/2022/google-cloud-api-call-from-abap-on-premise/)
- [Connect from AS ABAP to Google Cloud Platform App-Engine resource secured with Google Identity-Aware Proxy](https://community.sap.com/t5/application-development-and-automation-blog-posts/connect-from-as-abap-to-google-cloud-platform-app-engine-resource-secured/ba-p/13395891)
- [Using OAuth 2.0 for Server to Server Applications](https://developers.google.com/identity/protocols/oauth2/service-account#httprest)
- [JWT With RSA256 Encryption ABAP Stack](https://community.sap.com/t5/application-development-and-automation-discussions/jwt-with-rsa256-encryption-abap-stack/m-p/13658691)
- [ABAP JWT Generator](https://github.com/abapChaoLiu/abap_jwt_generator)
- [RSA Encryption in ABAP](https://sapabapcentral.blogspot.com/2021/04/rsa-encryption-in-abap.html)

- [JWT creator](https://www.jwt.io/)
- [Epoch time](https://www.epochconverter.com/)

## Happy path for google api 2025

### Convert service account JSON key file to P12

- copy `private_key` field to text file (.pem), replace `\n` with real enter
- goto url from `client_x509_cert_url`, extract certificate with the `private_key_id` to another pem-file
- `openssl pkcs12 -inkey private.key -in certificate.pem -export -out certificateWithKey.pfx`
- convert pfx to pse
  - one of the blog posts above say that pfx can be imported to SAP directly but didn't work for me
  - [Converting P12 to PSE and uploading in STRUST on ABAP](https://community.sap.com/t5/technology-q-a/converting-p12-to-pse-and-uploading-in-strust-on-abap/qaq-p/6164287)
  - [2148457 - How to convert the keypair of a PKCS#12 / PFX container into a PSE file](https://me.sap.com/notes/0002148457)
  - download sapcryptolib from [SAP Software](https://support.sap.com/en/my-support/software-downloads.html) -> Installations & Upgrades -> By Category -> SAP Cryptographic Software -> SAPCRYPTOLIB -> COMMONCRYPTOLIB 8
  - `sapgenpse.exe import_p12 -p cert.pse certificateWithKey.pfx`

### Import this to SAP

- SE16N table SSFAPPLIC: add new entry, e.g. GAPI, select everything except B_INCCERTS, B_DETACHED, B_ASKPWD.
- SSFA: "New Entries". In the dropdown there should be a new option that we just created in table SSFAPPLIC.
  - Security product: SAPSECULIB
  - SSF Format: PKCS1-V1.5
  - Hash: SHA256
  - Enc: AES256-CBC
  - all other - defaults
- STRUST:
  - Right click on the newly appeared node (GAPI), Create, Algo - RSA with SHA256, Key - 2048
  - Menu -> PSE -> Import - choose certificate created above (cert.pse)
  - Menu -> PSE -> Save As - SSF Application "GAPI"
  - Don't forget to add `googleapis.com` certificate to anonymous node

### Google service account

- add Cloud Resource Manager API
- add Role that contains `resourcemanager.projects.get`

### Testing from SAP

```abap
  " Get PSE name
  data lv_ssf_profilename type ssfprof.
  lv_ssf_profilename = zcl_ede_jwt=>ssfappl_to_profile_name( 'GAPI' ).

  " Build JWT
  data lv_jwt type string.
  lv_jwt = zcl_aha_jwt=>create_rs256_jwt(
    i_ssf_profilename = lv_ssf_profilename
    i_iss             = '<service account email>'
    i_kid             = '<key id from json>'
    i_aud             = 'https://oauth2.googleapis.com/token'
    i_scope           = 'https://www.googleapis.com/auth/cloud-platform' ).

  data client type ref to zif_aha_http_agent.
  data res type ref to zif_aha_http_response.
  data lo_headers type ref to zcl_abap_string_map.
  data lo_payload type ref to zcl_abap_string_map.

  " Get token
  lo_payload = zcl_aha_utils=>token_request( lv_jwt ).
  client = zcl_aha_http_agent=>create_for_url( 'https://oauth2.googleapis.com/token' ).
  res = client->request(
    iv_method  = zif_aha_http_agent=>c_methods-post
    iv_payload = lo_payload ).

  " Request API
  lo_headers = zcl_aha_utils=>add_bearer_token( res->json( )->get( '/access_token' ) ).
  client = zcl_aha_http_agent=>create_for_url( 'https://cloudresourcemanager.googleapis.com' ).
  res = client->request(
    io_headers = lo_headers
    iv_uri     = '/v3/projects/<project name>' ).

  write: / res->json( )->stringify( ).
```
