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
  done/bool := false

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
    if done: return null
    o := channel_.receive
    if not o:
      done = true
      return o
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

  skip-to tag-name/string --min-height/int=0 -> any:
    looking-for-closing := false
    if tag-name[0] == '/':
      looking-for-closing = true
      tag-name = tag-name[1..]
    while tag-stack_.size >= min-height:
      o := next_
      if not o: return null
      if not looking-for-closing and o is TagOpen and o.name == tag-name: return o
      if looking-for-closing and o is TagClose and o.name == tag-name: return o
    return null

  skip-to-class class-name/string --tag/string="div" --min-height/int=0 -> any:
    while true:
      o := skip-to tag --min-height=min-height
      if not o: return null
      if o is TagOpen:
        classes := o.attributes.get "class" --if-absent=:""
        if (classes.split " ").contains class-name: return o

  get-text --skip-other-tags/bool=false -> string:
    while true:
      o := next_
      if not o or (not skip-other-tags and o is not Text): throw "Expected text"
      if o is Text:
        return (o as Text).text
      continue

  parse xml/string:
    parser := Parser xml --consumer=this
    task:: parser.parse

    // Skip the header:
    skip-to "body"

    while true:
      panel-group := skip-to-class "panel"
      height := tag-stack_.size
      if not panel-group: break
      section-header := skip-to-class "panel-title" --tag="h3"
      section-path := get-text
      skip-to-class "top-resource-description"
      section-description-p := skip-to "p"
      section-description := get-text

      print "$section-path: $section-description"

      while true:
        method-header := skip-to-class "modal-title" --tag="h4" --min-height=height
        if not method-header: break
        span := next_
        method-name := get-text --skip-other-tags
        skip-to-class "parent" --tag="span"
        signature := ""
        tag := next_
        if tag is Text:
          signature = (tag as Text).text
        signature-rest := get-text --skip-other-tags
        signature = "$signature$signature-rest"
        print "  $method-name - $signature"

main args:
  (HueParser).parse (file.read-content args[0]).to-string

