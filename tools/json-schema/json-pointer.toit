import encoding.url

class JsonPointer:
  segments/List

  constructor:
    segments = [""]

  constructor.with-segments .segments:

  operator + segment/string:
    escaped := escape_ segment
    new-segments := segments.copy
    new-segments.add escaped
    return JsonPointer.with-segments new-segments

  operator [] segment/any:
    if segment is string:
      return this + segment
    else if segment is int:
      return this + "$segment"
    else:
      throw "Invalid segment type"

  static escape_ str/string -> string:
    str = str.replace --all "~" "~0"
    str = str.replace --all "/" "~1"
    return str

  to-string -> string:
    return segments.join "/"

  to-fragment-string -> string:
    return (segments.map: url.encode it).join "/"

  stringify -> string:
    return to-string
