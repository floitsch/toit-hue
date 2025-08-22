import encoding.json
import net
import pet-store
import http
import openapi

print-response response/http.Response:
  print response.status-code
  print response.status-message
  data := response.body.read-all
  print data.to-string

main:
  network := net.open

  auth := openapi.OAuth "foo"
  client := pet-store.ApiClient network
      --base-path="http://localhost:4010"
      --authentication=auth
  api := pet-store.Api --api-client=client
  encoded := json.encode {
    "name": "flocki",
    "photoUrls": [],
  }
  r/http.Response? := null
  r = api.pet.add-pet --raw encoded
  print-response r
  r = api.pet.find-pets-by-status --raw
  print-response r
