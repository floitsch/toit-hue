import http
import net

import .auth

class ApiClient:
  base-path/string
  authentication/Authentication?

  client_/http.Client? := ?

  constructor network/net.Client
      --.base-path
      --.authentication=null:
    client_ = http.Client network

  close:
    if client_:
      client_.close
      client_ = null

