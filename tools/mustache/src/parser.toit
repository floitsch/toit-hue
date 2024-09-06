import .node

/**
A node to indicate that a section was closed.

Only used during parsing.
*/
class CloseNode extends Node:
  name/string

  constructor .name:

  can-be-standalone -> bool: return true

  accept visitor/Visitor -> none:
    unreachable

  stringify -> string:
    return "Close: $name"

/**
Parses the given $template.

Returns a list of $Node instances that can be rendered.

If $strict is true then only tag names with characters
  a-z, A-Z, 0-9, underscore, period and minus are allowed.
*/
parse template/string --strict/bool=false -> List:  // Of Node.
  parser := Parser_ template --strict=strict
  return parser.parse

class Parser_:
  // Delimiters may be changed by the template.
  open-delimiter/ByteArray := #['{', '{']
  close-delimiter/ByteArray := #['}', '}']

  stack := []  // Of SectionNode.

  /** The current position in the template. */
  pos := 0
  /** The starting position of a text node. */
  start-pos := 0
  /** Position of the last newline that was encountered. */
  last-new-line := -1
  /** Position of the last non-witespace character that was encountered. */
  last-non-white := -1

  /** The template that is currently parsed. */
  template/string
  /** Whether to be strict when parsing names. */
  strict/bool

  constructor .template --.strict:

  peek at/int=0 -> int?:
    if pos + at >= template.size:
      return null
    return template.at --raw (pos + at)

  consume --count/int=1 -> none:
    pos += count

  skip-space-or-tab -> none:
    while true:
      c := peek
      if c != ' ' and c != '\t': return
      consume

  is-eof-or-whitespace c/int -> bool:
    return c == null or c == ' ' or c == '\n' or c == '\r' or c == '\t'

  at-opening-delimiter -> bool:
    open-delimiter.size.repeat: | i/int |
      if (peek i) != open-delimiter[i]: return false
    return true

  at-closing-delimiter delimiter/ByteArray=close-delimiter -> bool:
    delimiter.size.repeat: | i/int |
      if (peek i) != delimiter[i]: return false
    return true

  at-eof -> bool:
    return pos >= template.size

  parse -> List:  // Of Node.
    result := []

    add := : | node/Node? |
      if node and node is not CloseNode:
        if stack.is-empty:
          result.add node
        else:
          container-node/ContainerNode := stack.last
          container-node.add-child node --strict=strict

    while true:
      c := peek
      if c == null:
        add.call (build-text-node pos)
        break

      if at-opening-delimiter:
        tag-pos := pos
        // Parse the tag, but don't consume the text yet.
        // We might have a stand-alone tag, in which case the last line of
        // the unhandled text could be part of the tag.
        node := parse-tag
        is-standalone := false
        tag-end-pos := pos
        if not node or node.can-be-standalone:
          if last-non-white <= last-new-line:
            // The tag is not preceded by anything that isn't whitespace.
            skip-space-or-tab
            c = peek
            if c == null or c == '\n' or (c == '\r' and (peek 1) == '\n'):
              // It's only followed by whitespace.
              is-standalone = true

        if is-standalone:
          // Only consume the text up to (and including) the last new-line.
          add.call (build-text-node (last-new-line + 1))
          indentation/string := template[last-new-line + 1..tag-pos]
          if node is PartialNode:
            // The indentation is the same as the partial tag.
            (node as PartialNode).indentation = indentation
          add.call node
          consume-new-line --allow-eof
          start-pos = pos
          last-new-line = pos - 1
          last-non-white = pos - 1
        else:
          add.call (build-text-node tag-pos)
          add.call node
          start-pos = tag-end-pos
          last-non-white = tag-end-pos - 1

        if node is ContainerNode:
          stack.add node
        else if node is CloseNode:
          name := (node as CloseNode).name
          if stack.is-empty or (stack.last as ContainerNode).name != name:
            throw "Unbalanced tags/sections"
          stack.resize (stack.size - 1)
        continue

      if c == '\n':
        last-new-line = pos
      else if not is-eof-or-whitespace c:
        // This can only be whitespace, since we already checked for null above.
        last-non-white = pos

      consume

    if not stack.is-empty:
      open-section-names := stack.map: | section/SectionNode | section.name
      throw "Unclosed tags: $(open-section-names.join ", ")"

    return result

  consume-new-line --allow-eof/bool:
    c := peek
    if c == '\n':
      consume
    else if c == '\r':
      consume
      if peek != '\n': throw "Unexpected character"
      consume
    else if allow-eof:
      if c != null: throw "Unexpected character"
    else:
      throw "Unexpected character"

  build-text-node up-to/int -> Node?:
    if start-pos >= up-to: return null
    text := template[start-pos..up-to]
    return TextNode text

  is-strict-char c/int:
    return 'a' <= c <= 'z' or
        'A' <= c <= 'Z' or
        '0' <= c <= '9' or
        c == '_' or
        c == '.' or
        c == '-'

  parse-name -> string:
    skip-space-or-tab
    result := parse-tag-token
    if strict:
      result.do: | c/int |
        if not is-strict-char c: throw "INVALID_NAME_CHAR"
    skip-space-or-tab
    return result

  parse-tag-token -> string:
    start := pos
    while not at-closing-delimiter and not is-eof-or-whitespace peek:
      consume
    if start == pos: throw "Missing name"
    return template[start..pos]

  parse-tag -> Node?:
    consume --count=open-delimiter.size
    // We remember the current close delimiter, as the tag
    // may change it to something else.
    current-close-delimiter := close-delimiter

    type := peek
    result := ?
    if type == '{' or type == '&':
      result = parse-unescaped
    else if type == '#' or type == '^':
      result = parse-section
    else if type == '>':
      result = parse-partial
    else if type == '$':
      result = parse-block
    else if type == '<':
      result = parse-inheritance
    else if type == '!':
      result = parse-comment
    else if type == '=':
      result = parse-delimiters
    else if type == '/':
      result = parse-close
    else:
      result = parse-variable

    if not at-closing-delimiter current-close-delimiter:
      throw "Unclosed tag"
    consume --count=current-close-delimiter.size
    return result

  parse-unescaped -> Node:
    old-delimiter := close-delimiter
    type := peek
    if type == '{':
      // Temporarily set the closing delimiter to '}'+old-delimiter.
      // The $parse-tag function will undo this change after it consumed the
      // closing delimiters.
      close-delimiter = #['}'] + close-delimiter

    consume

    name := parse-name

    if type == '{':
      if not at-closing-delimiter: throw "Unclosed tag"
      consume
      close-delimiter = old-delimiter

    return VariableNode name --no-escape

  parse-variable -> Node:
    name := parse-name
    return VariableNode name

  parse-section -> Node:
    is-inverted := peek == '^'
    consume
    name := parse-name
    return SectionNode name --inverted=is-inverted

  parse-partial -> Node:
    consume
    skip-space-or-tab
    if peek == '*':
      // A dynamic name.
      consume
      name-entry := parse-name
      return PartialDynamicNode name-entry

    name := parse-name
    return PartialConcreteNode name

  parse-block -> Node:
    consume
    name := parse-name
    return BlockNode name

  parse-inheritance -> Node:
    consume
    name := parse-name
    return PartialInheritanceNode name

  parse-comment -> Node?:
    consume
    while not at-eof and not at-closing-delimiter:
      consume
    return null

  parse-delimiters -> Node?:
    consume
    skip-space-or-tab
    new-open-string := parse-tag-token
    if new-open-string == "": throw "Invalid delimiter tag"
    if peek != ' ': throw "Invalid delimiter tag"
    skip-space-or-tab
    old-delimiter := close-delimiter
    close-delimiter = #['='] + old-delimiter
    new-close-string := parse-tag-token
    if new-close-string == "": throw "Invalid delimiter tag"
    skip-space-or-tab
    if not at-closing-delimiter: throw "Unclosed tag"
    consume // The '='.
    // Set the new open and close tags.
    // The 'parse-tag' function keeps a copy of the original closing
    // delimiter, so we are free to change the delimiters now.
    open-delimiter = new-open-string.to-byte-array
    close-delimiter = new-close-string.to-byte-array
    return null

  parse-close -> CloseNode:
    consume
    section-name := parse-name
    return CloseNode section-name
