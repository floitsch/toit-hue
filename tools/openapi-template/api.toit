import http
import net
import .lib.auth as openapi

/**
The client that does the actual requests.
*/
class ApiClient:
  client_/http.Client? := ?

  constructor network/net.Client:
    client_ = http.Client network

  close:
    if client_:
      client_.close
      client_ = null

// MUSTACHE: ServiceName={{api-name}} provided by the user not the document.
class ServiceName:
  api-client_/ApiClient? := ?

  constructor --api-client/ApiClient:
    api-client_ = api-client

  constructor network/net.Client:
    api-client_ = ApiClient network

  close -> none:
    if not api-client_: return
    api-client_.close
    api-client_ = null

  // MUSTACHE: {{#apis}} Enter apis.
  // MUSTACHE: api-name={{field-name}}
  // MUSTACHE: ApiClassName={{class-name}}
  api-name_/ApiClassName? := null
  api-name -> ApiClassName:
    if not api-name_: api-name_ = ApiClassName api-client_
    return api-name_

  // MUSTACHE: {{/apis}} Leave apis

// MUSTACHE: {{#apis}} Enter apis.
// MUSTACHE: ApiClassName={{class-name}}
// MUSTACHE: BASE-PATH={{{base-path}}}
class ApiClassName:
  authentication/openapi.Authentication?

  api-client_/ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:

  // MUSTACHE: {{#operations}} Enter operations.
  // MUSTACHE: op-name={{name}}
  /**
  // MUSTACHE: op-toit-doc={{description}}
  op-toit-doc
  // MUSTACHE: {{#deprecated}}
  Deprecated.
  // MUSTACHE: {{/deprecated}}
  // MUSTACHE: {{#parameters}}
  // MUSTACHE: op-arg={{name}}
  // MUSTACHE: param-description={{param-description}}
  - $op-arg: param-description
  // MUSTACHE: {{/parameters}}
  */
  op-name
  // MUSTACHE: {{#parameters}} Enter parameters
  // MUSTACHE: {{#required}}
  // MUSTACHE: op-arg={{name}}
      --op-arg
  // MUSTACHE: {{/required}}
  // MUSTACHE: {{^required}}
  // MUSTACHE: op-other-arg={{name}}
      --op-other-arg=null
  // MUSTACHE:: {{/required}}
  // MUSTACHE: {{/parameters}} Leave parameters
  :
    // TODO.

  // MUSTACHE: {{/operations}} Leave operations

// MUSTACHE: {{/apis}} Exit apis.
