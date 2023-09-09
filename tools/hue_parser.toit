import host.file
import monitor

import .xml-parser

class TagOpen:
  name/string
  attributes/Map
  self-closing/bool

  constructor .name --.attributes --.self-closing:

  stringify -> string:
    return "<$name $attributes $(self-closing ? '/' : "")>"

class TagClose:
  name/string

  constructor .name:

  stringify -> string:
    return "</$name>"

class Text:
  text/string

  constructor .text:

  stringify -> string:
    return text

class HueParser implements Consumer:
  channel_/monitor.Channel := monitor.Channel 1
  tag-stack_/List := []

  on-tag-open tag/string --attributes/Map --from/int --to/int --self-closing/bool:
    channel_.send (TagOpen tag --attributes=attributes --self-closing=self-closing)

  on-tag-close tag/string --from/int --to/int:
    channel_.send (TagClose tag)

  on-comment text/string --from/int --to/int:
    // Ignore.

  on-text text/string --from/int --to/int:
    channel_.send (Text text)

  on-eof:
    channel_.send null

  is-singleton-tag tag-name/string -> bool:
    SINGLETON-TAGS ::= ["area", "base", "br", "col", "command", "embed", "hr",
        "img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]
    return SINGLETON-TAGS.contains tag-name

  next_ -> any:
    o := channel_.receive
    if not o: return o
    if o is TagOpen:
      if not o.self-closing and not is-singleton-tag o.name: tag-stack_.add o
      return o
    if o is TagClose:
      if tag-stack_.is-empty or tag-stack_.last.name != o.name:
        // TODO: This is a hack to get around the fact that the Hue docs are
        // broken.
        // print "Unexpected closing tag: $o"
      else:
        tag-stack_.remove-last
      return o
    return o

  skip-to-closing_:
    current-size := tag-stack_.size
    while tag-stack_.size >= current-size: next_

  skip-to tag-name/string -> any:
    looking-for-closing := false
    if tag-name[0] == '/':
      looking-for-closing = true
      tag-name = tag-name[1..]
    while true:
      o := next_
      if not o: return null
      if not looking-for-closing and o is TagOpen and o.name == tag-name: return o
      if looking-for-closing and o is TagClose and o.name == tag-name: return o

  skip-to-class class-name/string --tag/string="div" -> any:
    while true:
      o := skip-to tag
      if not o: return null
      if o is TagOpen and (o.attributes.get "class") == class-name: return o

  parse xml/string:
    parser := Parser xml --consumer=this
    task:: parser.parse

    get-text := :
      o := next_
      if o is not Text:
        print o
        throw "Expected text"
      (o as Text).text

    // Skip the header:
    skip-to "body"

    while true:
      section-header := skip-to-class "panel-title" --tag="h3"
      if not section-header: break
      section-path := get-text.call
      skip-to-class "top-resource-description"
      section-description-p := skip-to "p"
      section-description := get-text.call

      print "$section-path: $section-description"

main args:
  (HueParser).parse (file.read-content args[0]).to-string

