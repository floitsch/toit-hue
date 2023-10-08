import host.file
import monitor
import encoding.json

import .xml-parser

interface ParseValue:
  opens tag-name/string --klass/string?=null -> bool
  closes tag-name/string -> bool

class TagOpen implements ParseValue:
  name/string
  attributes/Map
  self-closing/bool

  constructor .name --.attributes --.self-closing:

  stringify -> string:
    return "<$name $attributes $(self-closing ? '/' : "")>"

  klass -> string?:
    return attributes.get "class"

  opens tag-name/string --klass/string?=null -> bool:
    if tag-name != name: return false
    return matches-class klass

  closes tag-name/string -> bool:
    return false

  matches-class klass/string? -> bool:
    if not klass: return true
    this-class := attributes.get "class"
    if not this-class: return false
    haystack-classes := this-class.split " "
    needle-classes := klass.split " "
    needle-classes.do:
      if not haystack-classes.contains it: return false
    return true

class TagClose implements ParseValue:
  name/string

  constructor .name:

  opens tag-name/string --klass/string?=null -> bool:
    return false

  closes tag-name/string -> bool:
    return tag-name == name

  stringify -> string:
    return "</$name>"

class Text implements ParseValue:
  text/string

  constructor .text:

  opens tag-name/string --klass/string?=null -> bool:
    return false

  closes tag-name/string -> bool:
    return false

  stringify -> string:
    return text


class HueApi:
  endpoints/List // of HueEndpoint.

  constructor .endpoints:

  to-json -> Map:
    return {
      "endpoints": endpoints.map: it.to-json
    }

class HueEndpoint:
  path/string
  description/string

  methods/List // of HueMethod.

  constructor --.path --.description --.methods:

  to-json -> Map:
    return {
      "path": path,
      "description": description,
      "methods": methods.map: it.to-json
    }

class HueMethod:
  method/string
  signature/string

  request/HueRequest?
  responses/List // of HueResponse.

  constructor --.method --.signature --.request --.responses:

  to-json -> Map:
    result := {
      "method": method,
      "signature": signature,
      "responses": responses.map: it.to-json
    }
    if request:
      result["request"] = request.to-json
    return result

class HueRequest:
  parameters/List
  body/HueBody?

  constructor --.parameters --.body:

  to-json -> Map:
    result := {
      "parameters": parameters
    }
    if body:
      result["body"] = body.to-json
    return result

class HueResponse:
  status-code/string
  body/HueBody

  constructor --.status-code --.body:

  to-json -> Map:
    return {
      "status-code": status-code,
      "body": body.to-json
    }

class HueBody:
  media-type/string  // Always "application/json".
  type/string
  properties/Map  // from string to HueProperty.

  constructor --.media-type --.type --.properties:

  to-json -> Map:
    return {
      "media-type": media-type,
      "type": type,
      "properties": properties.map: | _ value | value.to-json,
    }

class HueProperty:
  type/string
  description/string
  required/bool
  is-array-type/bool
  properties/Map?  // from string to HueProperty.

  constructor --.type --.description --.required --.is-array-type --.properties:

  to-json -> Map:
    result := {
      "type": type,
      "description": description,
      "required": required
    }
    if properties:
      result["properties"] = properties.map: | _ value | value.to-json
    return result

class HueParser implements Consumer:
  channel_/monitor.Channel := monitor.Channel 1
  tag-stack_/List := []
  nested-stack/List := []
  done/bool := false
  has-peeked_/bool := false
  peeked_/any := null

  on-tag-open tag/string --attributes/Map --from/int --to/int --self-closing/bool:
    channel_.send (TagOpen tag --attributes=attributes --self-closing=self-closing)

  on-tag-close tag/string --from/int --to/int:
    channel_.send (TagClose tag)

  on-comment text/string --from/int --to/int:
    // Ignore.

  decode-xml text/string:
    text = text.replace "&lt;" "<"
    text = text.replace "&gt;" ">"
    text = text.replace "&amp;" "&"
    text = text.replace "&quot;" "\""
    text = text.replace "&apos;" "'"
    // Replace all '&#[0-9]+;' with the corresponding character.
    last-pos := 0
    while true:
      amp-pos := text.index-of "&#" last-pos
      if amp-pos == -1: break
      last-pos = amp-pos
      semi-pos := text.index-of ";" amp-pos
      if semi-pos == -1: break
      number := int.parse text[amp-pos + 2..semi-pos]
      text = text[..amp-pos] + (string.from-rune number) + text[semi-pos + 1..]

    return text

  on-text text/string --from/int --to/int:
    decoded := decode-xml text
    channel_.send (Text decoded)

  on-eof:
    channel_.send null

  is-singleton-tag tag-name/string -> bool:
    SINGLETON-TAGS ::= ["area", "base", "br", "col", "command", "embed", "hr",
        "img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]
    return SINGLETON-TAGS.contains tag-name

  is-nested_ o/any -> bool:
    if nested-stack.is-empty: return true
    if tag-stack_.size > nested-stack.last: return true
    return o is not TagClose or (o as TagClose).name != tag-stack_.last.name

  peek_ --allow-non-nested/bool=false -> ParseValue?:
    if done: return null
    if not has-peeked_:
      peeked_ = channel_.receive
      has-peeked_ = true
      if not peeked_:
        done = true
    if allow-non-nested: return peeked_
    return (is-nested_ peeked_) ? peeked_ : null

  next_ --allow-non-nested/bool=false -> ParseValue?:
    o := peek_ --allow-non-nested=allow-non-nested
    if o != null:
      has-peeked_ = false
    if o is TagOpen:
      tag-open := o as TagOpen
      if not tag-open.self-closing and not is-singleton-tag tag-open.name:
        tag-stack_.add o
    else if o is TagClose:
      tag-close := o as TagClose
      if tag-stack_.is-empty or tag-stack_.last.name != tag-close.name:
        // TODO: This is a hack to get around the fact that the Hue docs are
        // broken.
        if tag-close.name != "p":
          print "Unexpected closing tag: $o $tag-stack_.last"
      else:
        tag-stack_.remove-last
    return o

  skip-to-closing_ tag/string?=null:
    to-height/int := tag-stack_.size
    if tag:
      to-height = -1
      for i := tag-stack_.size - 1; i >= 0; i--:
        if tag-stack_[i] is TagOpen and tag-stack_[i].name == tag:
          to-height = i + 1
          break
      if to-height == -1:
        throw "Could not find tag $tag"
    else:
      to-height = tag-stack_.size
    while tag-stack_.size >= to-height: next_ --allow-non-nested

  skip-to tag-name/string --klass/string?=null -> any:
    looking-for-closing := false
    if tag-name[0] == '/':
      if klass: throw "Cannot specify class-name when looking for closing tag"
      looking-for-closing = true
      tag-name = tag-name[1..]

    while true:
      o/ParseValue? := next_
      if not o: return null
      if not looking-for-closing and o.opens tag-name --klass=klass: return o
      if looking-for-closing and o.closes tag-name: return o
    return null

  skip-whitespace:
    while true:
      o := peek_
      if not o or o is not Text: break
      if (o as Text).text.trim != "": break
      next_

  get-text --skip-other-tags/bool=false -> string:
    while true:
      o := next_
      if not o or (not skip-other-tags and o is not Text): throw "Expected text"
      if o is Text:
        return (o as Text).text
      continue

  in tag/string --klass/string?=null [block] -> bool:
    o := skip-to tag --klass=klass
    if not o: return false
    nested-stack.add tag-stack_.size
    block.call
    // Close.
    while next_: null
    next_ --allow-non-nested
    nested-stack.remove-last
    return true

  for-each tag/string --klass/string?=null [block]:
    while true:
      found := in tag --klass=klass block
      if not found: break

  parse xml/string -> HueApi:
    parser := Parser xml --consumer=this
    parse-task := task:: parser.parse

    endpoints := []
    in "body":
      for-each "div" --klass="panel panel-default":
        endpoints.add parse-resource-panel

    parse-task.cancel

    return HueApi endpoints

  parse-resource-panel -> HueEndpoint:
    section-header := skip-to "h3" --klass="panel-title"
    section-path := get-text
    section-description/string? := null
    methods := []
    in "div" --klass="panel-body":
      skip-to "div" --klass="top-resource-description"
      section-description-p := skip-to "p"
      section-description = get-text

      for-each "div" --klass="modal-content":
        methods.add parse-modal

    return HueEndpoint
        --path=section-path
        --description=section-description
        --methods=methods

  parse-modal -> HueMethod:
    method-name/string? := null
    signature/string := ""
    request/HueRequest? := null
    responses/List? := null
    in "div" --klass="modal-header":
      skip-to "h4" --klass="modal-title"
      skip-to "span" --klass="badge"
      method-name = get-text

      skip-to "span" --klass="parent"
      tag := next_
      if tag is Text:
        signature = (tag as Text).text
      signature-rest := get-text --skip-other-tags
      signature = "$signature$signature-rest"

    in "div" --klass="modal-body":
      tab-entries := []
      in "ul" --klass="nav nav-tabs":
        for-each "li":
          tab-entries.add (get-text --skip-other-tags)

      tab-entries.do: | tab-name/string |
        in "div" --klass="tab-pane":
          if tab-name == "Request":
            if request: throw "Duplicate request tab"
            request = parse-request-tab
          else if tab-name == "Response":
            if responses: throw "Duplicate response tab"
            responses = parse-response-tab
          else:
            throw "Unexpected tab name: $tab-name"
    return HueMethod
              --method=method-name
              --signature=signature
              --request=request
              --responses=responses

  parse-request-tab -> HueRequest:
    uri-parameters := []
    body/HueBody? := null
    while true:
      header-tag := skip-to "h3"
      if not header-tag: break
      text := get-text
      skip-to "/h3"
      if text == "URI Parameters":
        uri-parameters = parse-uri-parameters
      else if text == "Body":
        body = parse-body
      else:
        throw "Unexpected text: $text"
    return HueRequest
        --parameters=uri-parameters
        --body=body

  parse-uri-parameters -> List:
    result := []
    in "ul":
      for-each "li":
        // Currently it's always "id", a required string.
        param-name := get-text --skip-other-tags
        result.add param-name
    return result

  parse-body -> HueBody:
    media-type/string? := null
    type/string? := null
    properties := {:}
    while true:
      skip-whitespace
      need-to-parse-properties := false
      got-p := peek_ and peek_.opens "p"
      if not got-p:
        // Most likely a new response code or status code.
        break
      in "p":
        if not peek_.opens "strong": throw "Expected <strong> got $peek_"
        section-name := get-text --skip-other-tags
        if section-name == "Properties":
          need-to-parse-properties = true
        else:
          skip-to-closing_ "strong"
          value := get-text --skip-other-tags
          if not value.starts_with ": ": throw "Expected ': '"
          value = value[2..]
          if section-name == "Media type":
            media-type = value
          else if section-name == "Type":
            type = value
          else:
            throw "Unexpected section name: $section-name"
      if need-to-parse-properties:
        properties = parse-object
        need-to-parse-properties = false
    return HueBody
              --media-type=media-type
              --type=type
              --properties=properties

  parse-object -> Map:
    result := {:}
    in "ul":
      for-each "li":
        property-name/string? := null
        in "strong": property-name = get-text --skip-other-tags
        separator := get-text
        if separator != ": ": throw "Expected ': '"
        em := peek_
        if not em.opens "em": throw "Expected <em> for property $property-name"
        is-required := false
        type/string? := null
        in "em":
          type-string/string := ?
          required-or-type := get-text --skip-other-tags
          if required-or-type == "required":
            is-required = true
            type-string = get-text --skip-other-tags
          else:
            type-string = required-or-type
          type = type-string[1..type-string.size - 1]
        is-array-type := type.starts-with "array of"
        description := ""
        new-line := peek_
        if new-line is Text:
          next_ // Consume the new-line.
          description-p-tag := peek_
          if description-p-tag.opens "p":
            next_ // Consume '<p>'.
            description-text := peek_
            if description-text is Text:
              description = get-text
            else if description-text.opens "strong":
              // Doesn't have a description.
            else:
              throw "Expected strong for 'Items'"

        properties/Map? := null
        if type == "object":
          properties = parse-object
        if is-array-type:
          strong := skip-to "strong"
          if strong:
            if get-text != "Items": throw "Expected 'Items'"
            nested-name := get-text --skip-other-tags
            nested-name = nested-name.trim --left ": "
            properties = parse-object

        result[property-name] = HueProperty
                                  --type=type
                                  --description=description
                                  --required=is-required
                                  --is-array-type=is-array-type
                                  --properties=properties
    return result

  parse-response-tab -> List:
    result := []
    while true:
      header-tag := skip-to "h2"
      if not header-tag: break
      text := get-text
      if text != "HTTP status code ":
        throw "Unexpected text: $text"
      a-tag := peek_
      if not a-tag or not a-tag.opens "a": throw "Expected <a>"
      status-code := get-text --skip-other-tags
      skip-to "/h2"
      body-header := skip-to "h3"
      if not body-header: throw "Expected <h3>"
      body-text := get-text --skip-other-tags
      if body-text != "Body": throw "Expected 'Body'"
      skip-to "/h3"
      body := parse-body
      response := HueResponse
                    --status-code=status-code
                    --body=body
      result.add response
    return result

main args:
  api := (HueParser).parse (file.read-content args[0]).to-string
  print (json.stringify api.to-json)

