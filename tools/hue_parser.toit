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
  has-peeked_/bool := false
  peeked_/any := null

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

  peek_ -> any:
    if done: return null
    if not has-peeked_:
      peeked_ = channel_.receive
      has-peeked_ = true
      if not peeked_:
        done = true
    return peeked_

  next_ -> any:
    o := peek_
    has-peeked_ = false
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
    while tag-stack_.size >= to-height: next_

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

  parse-object object-height/int indent/string="":
    skip-to "ul" --min-height=object-height
    list-height := tag-stack_.size
    while true:
      li := skip-to "li" --min-height=list-height
      if not li: break
      entry-height := tag-stack_.size
      skip-to "strong"
      property-name := get-text
      skip-to-closing_ "strong"
      text := get-text
      if text == ": ":
        // Skip the separator.
      else:
        throw "Expected ': ', got '$text' for property $property-name"
      em := next_
      if em is not TagOpen or (em as TagOpen).name != "em":
        throw "Expected <em> for property $property-name"
      required-or-type := get-text --skip-other-tags
      is-required := false
      type-string := ?
      if required-or-type == "required":
        is-required = true
        type-string = get-text --skip-other-tags
      else:
        type-string = required-or-type
      skip-to-closing_ "em"
      type := type-string[1..type-string.size - 1]
      is-array-type := type.starts-with "array of"
      description := ""
      new-line := peek_
      if new-line is Text:
        next_ // Consume the new-line.
        description-p-tag := peek_
        if description-p-tag is TagOpen and (description-p-tag as TagOpen).name == "p":
          next_ // Consume '<p>'.
          description-text := peek_
          if description-text is not Text:
            if description-text is not TagOpen or (description-text as TagOpen).name != "strong":
              throw "Expected strong for 'Items'"
            // Not a description
          else:
            description = get-text
      // skip-to "p" --min-height=list-height
      // property-description := get-text --skip-other-tags
      if is-array-type:
        strong := skip-to "strong" --min-height=entry-height
        if strong:
          if get-text != "Items": throw "Expected 'Items'"
          nested-name := get-text --skip-other-tags
          parse-object entry-height "$indent  "
      else:
      print "$indent    $property-name: $type (required: $is-required): $description"
      if type == "object":
        parse-object list-height "$indent  "
      skip-to-closing_ "li"

  parse-body entry-height/int:
    skip-to "p" --min-height=entry-height // Media type
    media-type-label := get-text --skip-other-tags
    if media-type-label != "Media type": throw "Expected Media type"
    media-type := get-text --skip-other-tags
    print "    Media type: $media-type"
    skip-to "p" --min-height=entry-height // Type
    type-label := get-text --skip-other-tags
    if type-label != "Type": throw "Expected Type"
    type := get-text --skip-other-tags
    print "    Type: $type"

    skip-to "p" --min-height=entry-height // Properties
    properties-label := get-text --skip-other-tags
    if properties-label != "Properties": throw "Expected Properties"
    parse-object entry-height

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
        body := skip-to-class "modal-body"
        body-height := tag-stack_.size
        nav-tabs := skip-to-class "nav-tabs" --tag="ul"
        nav-height := tag-stack_.size
        tab-entries := []
        while true:
          tab-entry := skip-to "li" --min-height=nav-height
          if not tab-entry: break
          tab-entries.add (get-text --skip-other-tags)
        tab-entries.do: | tab-entry/string |
          pane := skip-to-class "tab-pane" --min-height=body-height
          if not pane: throw "Expected pane"
          pane-height := tag-stack_.size
          if tab-entry == "Request":
            while true:
              header := skip-to "h3" --min-height=pane-height
              if not header: break
              entry-height := tag-stack_.size - 1
              text := get-text
              if text == "URI Parameters":
                skip-to "ul" --min-height=entry-height
                uri-param-height := tag-stack_.size
                while true:
                  li := skip-to "li" --min-height=uri-param-height
                  if not li: break
                  param-name := get-text --skip-other-tags
                  skip-to-closing_ "li"
                  // No need to check for anything. At the moment the URI parameter is
                  // always "id" and required.
                  print "    $param-name"
              else if text == "Body":
                parse-body entry-height
              else:
                throw "Unexpected text: $text"
//              throw "Expected URI Parameters or Body, got $text"




main args:
  (HueParser).parse (file.read-content args[0]).to-string

