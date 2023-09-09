import host.file

class Parser:
  buffer_/string
  consumer_/Consumer
  pos_/int := 0

  constructor .buffer_ --consumer/Consumer:
    consumer_ = consumer

  parse:
    while pos_ < buffer_.size:
      c := buffer_[pos_]
      if c == '<':
        parse-tag_
      else:
        parse-text_
    consumer_.on-eof

  parse-tag_:
    assert: buffer_[pos_] == '<'
    pos_++
    start := pos_
    attributes := {:}
    is-self-closing := false
    is-closing := false

    if buffer_[pos_] == '!':
      while buffer_[pos_] != '>': pos_++
      consumer_.on-comment buffer_[start..pos_]
          --from=start
          --to=pos_
      pos_++
      return

    if buffer_[pos_] == '/':
      is-closing = true
      pos_++
      start = pos_

    tag-name/string? := null
    while true:
      c := buffer_[pos_]
      if c == ' ' or c == '>':
        tag-name = buffer_[start..pos_]
        break
      pos_++

    while true:
      c := buffer_[pos_]
      if c == ' ':
        pos_++
        continue

      if c == '>':
        if is-closing:
          consumer_.on-tag-close
              tag-name
              --from=start
              --to=pos_
        else:
          consumer_.on-tag-open
              tag-name
              --attributes=attributes
              --from=start
              --to=pos_
              --self-closing=is-self-closing
        pos_++
        break
      if c == '/':
        if is-closing or is-self-closing:
          throw "Unexpected / at position $(pos_)"
        is-self-closing = true
        pos_++
        continue

      // Must be an attribute.
      parse-attribute-into_ attributes

  parse-attribute-into_ attributes/Map:
    assert: buffer_[pos_] != ' '

    start := pos_
    while true:
      c := buffer_[pos_++]
      // In HTML attributes might not have values.
      // We could remove the exception and allow it.
      if c == ' ': throw "Unexpected space in attribute name at position $(pos_ - 1)"
      if c == '=': break
    name := buffer_[start .. pos_ - 1]

    start = pos_
    quote := buffer_[pos_++]
    if quote != '"' and quote != '\'': throw "Unexpected quote at position $(pos_ - 1)"

    while buffer_[pos_] != quote: pos_++
    attributes[name] = buffer_[start+1..pos_]
    pos_++
    return

  parse-text_:
    start := pos_
    while true:
      c := buffer_[pos_]
      if c == '<':
        consumer_.on-text buffer_[start..pos_]
            --from=start
            --to=pos_
        break
      pos_++
    return

interface Consumer:
  on-tag-open tag/string --attributes/Map --from/int --to/int --self-closing/bool
  on-tag-close tag/string --from/int --to/int
  on-comment text/string --from/int --to/int
  on-text text/string --from/int --to/int
  on-eof

class TestConsumer implements Consumer:
  on-tag-open tag/string --attributes/Map --from/int --to/int --self-closing/bool:
    print "on_tag_open: $(tag) $(attributes) $(from) $(to) $(self-closing)"

  on-tag-close tag/string --from/int --to/int:
    print "on_tag_close: $(tag) $(from) $(to)"

  on-comment text/string --from/int --to/int:
    print "on_comment: $(text) $(from) $(to)"

  on-text text/string --from/int --to/int:
    print "on_text: $(text) $(from) $(to)"

  on-eof:
    print "on_eof"

main args:
  content := file.read-content args[0]

  consumer := TestConsumer
  parser := Parser content.to-string --consumer=consumer
  parser.parse
