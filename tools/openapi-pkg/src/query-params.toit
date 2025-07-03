import encoding.url as url-encoding

class QueryParam:
  key/string
  value/string

  constructor .key .value:
  constructor --.key --.value:

  stringify -> string:
    return "$key=$value"

  url-encode -> string:
    encoded-key := url-encoding.encode key
    encoded-value := url-encoding.encode value
    return "$encoded-key=$encoded-value"
