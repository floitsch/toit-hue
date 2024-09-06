interface Visitor:
  visit-text node/TextNode -> any

  visit-variable node/VariableNode -> any

  visit-section node/SectionNode -> any

  visit-partial-concrete node/PartialConcreteNode -> any

  visit-partial-dynamic node/PartialDynamicNode -> any

  visit-block node/BlockNode -> any

  visit-partial-inheritance node/PartialInheritanceNode -> any

abstract class Node:
  abstract can-be-standalone -> bool

  abstract accept visitor/Visitor -> any

interface ContainerNode:
  name -> string
  add-child node/Node --strict/bool -> none
  children -> List

class TextNode extends Node:
  text/string := ?

  constructor .text:

  can-be-standalone -> bool: return false

  accept visitor/Visitor -> any:
    return visitor.visit-text this

  stringify -> string:
    return "Text: '$text'"

class VariableNode extends Node:
  name/string
  escape/bool

  constructor .name --.escape/bool=true:

  can-be-standalone -> bool: return false

  accept visitor/Visitor -> any:
    return visitor.visit-variable this

  stringify -> string:
    return "Variable: $name"

class SectionNode extends Node implements ContainerNode:
  name/string
  inverted/bool
  children/List ::= []  // Will be filled by the parser.

  constructor .name --.inverted:

  can-be-standalone -> bool: return true

  add-child node/Node --strict/bool:
    children.add node

  accept visitor/Visitor -> any:
    return visitor.visit-section this

  stringify -> string:
    return "Section: $name\n  Inverted: $inverted\n  Children: $children"

abstract class PartialNode extends Node:
  indentation/string := ""

  can-be-standalone -> bool: return true

class PartialConcreteNode extends PartialNode:
  name/string

  constructor .name:

  accept visitor/Visitor -> any:
    return visitor.visit-partial-concrete this

  stringify -> string:
    return "Partial: $name\n  Indentation: '$indentation'"

class PartialDynamicNode extends PartialNode:
  partial-field/string

  constructor .partial-field:

  accept visitor/Visitor -> any:
    return visitor.visit-partial-dynamic this

  stringify -> string:
    return "PartialDynamic: $partial-field\n Indentation: '$indentation'"

class BlockNode extends Node implements ContainerNode:
  name/string
  children/List ::= []  // Will be filled by the parser.

  constructor .name:

  can-be-standalone -> bool: return true

  add-child node/Node --strict/bool:
    children.add node

  accept visitor/Visitor -> any:
    return visitor.visit-block this

  stringify -> string:
    return "BlockTag: $name"

class PartialInheritanceNode extends PartialNode implements ContainerNode:
  name/string
  overridden/Map ::= {:}  // From string to BlockNode.

  constructor .name:

  add-child node/Node --strict/bool:
    if node is BlockNode:
      block-node := node as BlockNode
      if strict and overridden.contains block-node.name:
        throw "Block tag already overridden: $block-node.name"
      overridden[block-node.name] = block-node
    else if strict:
      throw "Only block tags are allowed in partial inheritance nodes."

  children -> List:
    return overridden.values

  accept visitor/Visitor -> any:
    return visitor.visit-partial-inheritance this

  stringify -> string:
    return "PartialInheritance: $name"
