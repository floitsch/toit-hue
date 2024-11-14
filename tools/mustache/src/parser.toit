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

class CommentNode extends Node:
  comment/string

  constructor .comment:

  can-be-standalone -> bool: return true

  accept visitor/Visitor -> any:
    unreachable

  stringify -> string:
    return "Comment: '$comment'"

class DelimiterNode extends Node:
  delimiters/ByteArray

  constructor .delimiters:

  can-be-standalone -> bool: return true

  accept visitor/Visitor -> any:
    unreachable

  stringify -> string:
    return "Delimiters: '$delimiters'"

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

  /** The current position in the template. */
  pos := 0
  /** The starting position of a text node. */
  start-pos := 0

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

  is-whitespace c/int -> bool:
    return c == ' ' or c == '\n' or c == '\r' or c == '\t'

  is-eof-or-whitespace c/int? -> bool:
    return c == null or is-whitespace c

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

  is-whitespace-text-node text-node/TextNode -> bool:
    text-node.text.do: | c/int |
      if not is-whitespace c: return false
    return true

  /**
  A standalone line is a line that only contains whitespace and tags that
    can be standalone.
  */
  is-standalone-line line-nodes/List -> bool:
    if line-nodes.is-empty: return false
    have-seen-standalone-tag := false
    line-nodes.do: | node/Node |
      if node is TextNode:
        if not is-whitespace-text-node (node as TextNode): return false
      else:
        if not node.can-be-standalone: return false
        have-seen-standalone-tag = true
    return have-seen-standalone-tag

  parse -> List:  // Of Node.
    all-nodes := []

    line-nodes := []
    add-to-line := : | node/Node? |
      if node: line-nodes.add node

    finish-line := :
      if not line-nodes.is-empty:
        if is-standalone-line line-nodes:
          indentation := ""
          line-nodes.do: | node/Node |
            if node is TextNode:
              indentation += (node as TextNode).text
            else if node is PartialNode:
              (node as PartialNode).indentation = indentation
          line-nodes.filter --in-place: | node/Node | node is not TextNode
        all-nodes.add-all line-nodes
        line-nodes = []

    this-line-texts := []
    while true:
      c := peek
      if c == null:
        add-to-line.call (build-text-node pos)
        finish-line.call
        break

      if c == '\n':
        consume
        add-to-line.call (build-text-node pos)
        finish-line.call
        start-pos = pos
        continue

      if at-opening-delimiter:
        add-to-line.call (build-text-node pos)
        node := parse-tag
        add-to-line.call node
        start-pos = pos
        continue

      consume

    // Nest all nodes of containers and remove close nodes.
    result := []
    stack := []  // Of ContainerNode.
    all-nodes.do: | node/Node |
      if node is CommentNode: continue.do
      if node is DelimiterNode: continue.do
      if node is CloseNode:
        name := (node as CloseNode).name
        if stack.is-empty or (stack.last as ContainerNode).name != name:
          throw "Unbalanced tags/sections"
        stack.resize (stack.size - 1)
      else:
        if stack.is-empty:
          result.add node
        else:
          (stack.last as ContainerNode).add-child node --strict=strict
      if node is ContainerNode:
        stack.add node

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
    comment-start := pos
    while not at-eof and not at-closing-delimiter:
      consume
    comment := template[comment-start..pos]
    return CommentNode comment

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
    return DelimiterNode open-delimiter

  parse-close -> CloseNode:
    consume
    section-name := parse-name
    return CloseNode section-name
