// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import http
import certificate-roots
import encoding.json
import net

class Bridge:
  id/string
  name/string?
  internal-ip/string
  mac-address/string?

  constructor --.id --.name --.internal-ip --.mac-address:

  constructor.from-map map/Map:
    id = map["id"]
    name = map.get "name"
    internal-ip = map["internalipaddress"]
    mac-address = map.get "macaddress"

  stringify -> string:
    result := "Bridge(id: " + id + ", internal_ip: " + internal-ip
    if name:
      result += ", name: " + name
    if mac-address:
      result += ", mac_address: " + mac-address
    return result + ")"

class Hue:
  client_/http.Client? := ?
  network_/net.Client? := ?

  constructor:
    network_ = net.open
    client_ = http.Client.tls network_
        --root-certificates=[certificate-roots.GTS-ROOT-R1]

  close:
    if client_:
      client_.close
      client_ = null
    if network_:
      network_.close
      network_ = null

  local-bridges -> List:
    response := client_.get --host="discovery.meethue.com" --path="/"
    decoded := json.decode-stream response.body
    return decoded.map: Bridge.from-map it


main:
  hue := Hue
  print hue.local-bridges
  hue.close

