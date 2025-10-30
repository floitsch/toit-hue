// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import certificate-roots
import http
import encoding.json
import net

interface ResourceLoader:
  load url/string -> any

class HttpResourceLoader implements ResourceLoader:
  constructor:
    certificate-roots.install-all-trusted-roots

  load url/string -> any:
    network := net.open
    client/http.Client? := null
    try:
      client = http.Client network
      response := client.get --uri=url
      if response.status-code != 200:
        throw "HTTP error: $response.status-code $response.status-message"
      result := json.decode-stream response.body
      while response.body.read: null
      return result
    finally:
      if client: client.close
      network.close

