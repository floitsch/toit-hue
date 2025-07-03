import http
import io
import net
import http show Headers
import encoding.url as url-encoding

import .auth
import .query-params

export Headers

// https://github.com/OpenAPITools/openapi-generator/blob/master/samples/openapi3/client/petstore/dart2/petstore_client_lib/lib/api_client.dart

class ApiClient:
  base-path/string
  authentication/Authentication?

  client_/http.Client? := ?
  default-header-map_/Map ::= {:}

  constructor network/net.Client
      --.base-path
      --.authentication=null:
    client_ = http.Client network

  close:
    if client_:
      client_.close
      client_ = null

  add-default-header key/string value/string:
    default-header-map_[key] = value

  invoke-api -> http.Response
      --path/string
      --method/string
      --query-params/List  // of QueryParam
      --body/Object?
      --header-params/Headers
      --form-params/Map  // of string to string
      --content-type/string?
  :
    if authentication:
      authentication.apply-to-params
          --query-params=query-params
          --header-params=header-params

    default-header-map_.do: | key value |
      header-params.add key value

    if content-type:
      header-params.set "Content-Type" content-type

    url-encoded-query-params := query-params.map: | param/QueryParam |
      param.url-encode
    query-string := url-encoded-query-params.is-empty
        ? ""
        : "?$(url-encoded-query-params.join "&")"
    uri := "$base-path$path$query-string"

    request := client_.new-request method
        --uri=uri
        --headers=header-params
    msg-body := null
    if content-type == "application/x-www-form-urlencoded":
      msg-body = serialize-form_ form-params
    else if body:
      msg-body = serialize_ body
    if not msg-body.is-empty:
      request.body = io.Reader msg-body

    return request.send

  serialize_ value/Object? -> ByteArray:
    if not value: return #[]
    throw "UNIMPLEMENTED"

  serialize-form_ map/Map -> ByteArray:
    buffer := io.Buffer
    first := true
    map.do: | key value |
      if key is not string: throw "WRONG_OBJECT_TYPE"
      if value is not ByteArray:
        value = value.stringify
        if value is not string: throw "WRONG_OBJECT_TYPE"
      if first:
        first = false
      else:
        buffer.write "&"
      buffer.write
        url-encoding.encode key
      buffer.write "="
      buffer.write
        url-encoding.encode value
    return buffer.bytes
