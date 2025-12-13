import http
import net
import openapi

// MUSTACHE: {{#NOT_EXIST}}
interface Type:
// MUSTACHE: {{/NOT_EXIST}}

// MUSTACHE: X-ServiceName-x={{api-name}} provided by the user not the document.
class X-ServiceName-x:
  api-client_/openapi.ApiClient? := ?

  constructor --api-client/openapi.ApiClient:
    api-client_ = api-client

  constructor network/net.Client:
    // TODO(florian): provide base-path.
    api-client_ = openapi.ApiClient network --base-path=""

  close -> none:
    if not api-client_: return
    api-client_.close
    api-client_ = null

  // MUSTACHE: {{#apis}} Enter apis.
  // MUSTACHE: x-api-name-x={{field-name}}
  // MUSTACHE: X-ApiClassName-x={{class-name}}
  x-api-name-x_/X-ApiClassName-x? := null
  x-api-name-x -> X-ApiClassName-x:
    if not x-api-name-x_: x-api-name-x_ = X-ApiClassName-x api-client_
    return x-api-name-x_

  // MUSTACHE: {{/apis}} Leave apis

// MUSTACHE: {{#apis}} Enter apis.
// MUSTACHE: X-ApiClassName-x={{class-name}}
class X-ApiClassName-x:
  authentication/openapi.Authentication?

  api-client_/openapi.ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:

  // MUSTACHE: {{#operations}} Enter operations.
  // MUSTACHE: x-op-name-x={{name}}

  /**
  Variant of $x-op-name-x that takes a raw body and
    returns the raw response.
  */
  x-op-name-x --raw/True -> http.Response
  // MUSTACHE: {{#parameters}} Enter parameters
  // MUSTACHE: Type={{type}}
  // MUSTACHE: {{#required}}
  // MUSTACHE: x-op-arg-x={{name}}
      --x-op-arg-x/Type
  // MUSTACHE: {{/required}}
  // MUSTACHE: {{^required}}
  // MUSTACHE: x-op-other-arg-x={{name}}
      --x-op-other-arg-x/Type?=null
  // MUSTACHE: {{/required}}
  // MUSTACHE: {{/parameters}} Leave parameters
  // MUSTACHE: {{#request-body}}
  // MUSTACHE: Type={{type}}
      body-arg/Type
  // MUSTACHE: {{/request-body}}
  :
    // MUSTACHE: x-api-path-x={{{path}}}
    // MUSTACHE: x-api-method-x={{method}}
    path := "x-api-path-x"
    headers := http.Headers
    query-params := []
    cookie-params := []

    // MUSTACHE: {{#parameters}}
    // MUSTACHE: {{#required}}
    if true:
    // MUSTACHE: {{/required}}
    // MUSTACHE: {{^required}}
    if x-op-arg-x != null:
    // MUSTACHE: {{/required}}
      // MUSTACHE: x-orig-arg-x={{{original-name}}}
      // MUSTACHE: {{#in-path}}
      path = path.replace --all "{$("x-orig-arg-x")}" "$x-op-arg-x"
      // MUSTACHE: {{/in-path}}
      // MUSTACHE: {{#in-query}}
      query-params.add-all (openapi.encode-query-param
        "x-orig-arg-x"
        x-op-arg-x
        // MUSTACHE: {{#style}}
        // MUSTACHE: x-style-x={{style}}
        --style="x-style-x"
        // MUSTACHE: {{/style}}
        // MUSTACHE: {{#explode}}
        --explode
        // MUSTACHE: {{/explode}}
      )
      // MUSTACHE: {{/in-query}}
      // MUSTACHE: {{#in-header}}
      openapi.encode-header-param headers "x-orig-arg-x" x-op-arg-x
      // MUSTACHE: {{/in-header}}
      // MUSTACHE: {{#in-cookie}}
      cookie-params.add "x-orig-arg-x=$x-op-arg-x"
      // MUSTACHE: {{/in-cookie}}

    // MUSTACHE: {{/parameters}}
    // MUSTACHE: {{#has-cookie-params}}
    headers.set "Cookie" (cookie-params.join "; ")

    // MUSTACHE: {{/has-cookie-params}}
    // MUSTACHE: {{#request-body}}
    headers.set "Content-Type" "application/json"

    // MUSTACHE: {{/request-body}}
    return api-client_.invoke-api
        --path=path
        --method="x-api-method-x"
        --query-params=query-params
        // MUSTACHE: {{#request-body}}
        --body=body-arg
        // MUSTACHE: {{/request-body}}
        --header-params=headers
        --form-params={:}
        --content-type=null

  /**
  // MUSTACHE: x-op-toit-doc-x={{{description}}}
  x-op-toit-doc-x
  // MUSTACHE: {{#deprecated}}
  Deprecated.
  // MUSTACHE: {{/deprecated}}
  // MUSTACHE: {{#parameters}}
  // MUSTACHE: x-op-arg-x={{name}}
  // MUSTACHE: x-param-description-x={{{description}}}
  - $x-op-arg-x: x-param-description-x
  // MUSTACHE: {{/parameters}}
  // MUSTACHE: {{#request-body}}
  // MUSTACHE: x-body-arg-x={{name}}
  // MUSTACHE: x-body-description-x={{{description}}}
  - $body-arg: x-body-description-x
  // MUSTACHE: {{/request-body}}
  */
  x-op-name-x
      // MUSTACHE: {{#parameters}} Enter parameters
      // MUSTACHE: Type={{type}}
      // MUSTACHE: {{#required}}
      // MUSTACHE: x-op-arg-x={{name}}
      --x-op-arg-x/Type
      // MUSTACHE: {{/required}}
      // MUSTACHE: {{^required}}
      // MUSTACHE: x-op-other-arg-x={{name}}
      --x-op-other-arg-x/Type=null
      // MUSTACHE: {{/required}}
      // MUSTACHE: {{/parameters}} Leave parameters
      // MUSTACHE: {{#request-body}}
      // MUSTACHE: Type={{type}}
      body-arg/Type
      // MUSTACHE: {{/request-body}}
  :
    // TODO.
    raw := x-op-name-x --raw
        // MUSTACHE: {{#parameters}}
        --x-op-arg-x=x-op-arg-x
        // MUSTACHE: {{/parameters}}
        // MUSTACHE: {{#request-body}}
        body-arg
        // MUSTACHE: {{/request-body}}
    // TODO.

  // MUSTACHE: {{/operations}} Leave operations

// MUSTACHE: {{/apis}} Exit apis.
