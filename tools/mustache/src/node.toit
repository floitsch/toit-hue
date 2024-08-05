abstract class Node:
  abstract can-be-standalone -> bool

class TextNode extends Node:
  text/string

  constructor .text:

  can-be-standalone -> bool: return false

  stringify -> string:
    return "Text: '$text'"

class VariableNode extends Node:
  name/string
  escape/bool

  constructor .name --.escape/bool=true:

  can-be-standalone -> bool: return false

  stringify -> string:
    return "Variable: $name"

class SectionNode extends Node:
  name/string
  inverted/bool
  children/List ::= []  // Will be filled by the parser.

  constructor .name --.inverted:

  can-be-standalone -> bool: return true

  stringify -> string:
    return "Section: $name\n  Inverted: $inverted\n  Children: $children"

class PartialNode extends Node:
  name/string
  indentation/string := ""

  constructor .name:

  can-be-standalone -> bool: return true

  stringify -> string:
    return "Partial: $name\n  Indentation: '$indentation'"
