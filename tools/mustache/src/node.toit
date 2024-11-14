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

/**
A node with children.
*/
interface ContainerNode:
  name -> string
  add-child node/Node --strict/bool -> none
  children -> List

/**
A node that only contains text that should be rendered.

All text that isn't part of a tag is represented by a TextNode.
*/
class TextNode extends Node:
  text/string := ?

  constructor .text:

  can-be-standalone -> bool: return false

  accept visitor/Visitor -> any:
    return visitor.visit-text this

  stringify -> string:
    return "Text: '$text'"

/**
A node that represents a variable.

Example:
```
data:
  { name: 'world' }
template:
  "Hello, {{name}}!"
output:
  "Hello, world!"
```
*/
class VariableNode extends Node:
  name/string
  escape/bool

  constructor .name --.escape/bool=true:

  can-be-standalone -> bool: return false

  accept visitor/Visitor -> any:
    return visitor.visit-variable this

  stringify -> string:
    return "Variable: $name"

/**
A node that represents a section.

Example:
```
data:
  { boolean: true }
template:
  "{{#boolean}}This should be rendered.{{/boolean}}"
output:
  "This should be rendered."
```

A SectionNode has a name and a list of children that should be rendered
  if the value of the name is not falsey.

If the section's value is a list, then the children are rendered for each
  item in the list.

```
data:
  { list: [ { item: 1 }, { item: 2 }, { item: 3 } ] }
template:
  "{{#list}}{{item}}{{/list}}"
output:
  "123"
```
*/
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

/**
A node that represents a partial.

Partials are used to expand an external template into the current template.
The origin of the partial is determined by the implementation. Frequently,
  the partial comes from a file.

If a partial is standalone, then any preceding whitespace is used as indentation.

See $PartialConcreteNode and $PartialDynamicNode for concrete implementations.
*/
abstract class PartialNode extends Node:
  indentation/string := ""

  can-be-standalone -> bool: return true

/**
A $PartialNode where the name of the partial is known at compile time.

Example:
```
template:
  {{>text}}
partials:
  text: "Hello, world!"
output:
  "Hello, world!"
```
*/
class PartialConcreteNode extends PartialNode:
  name/string

  constructor .name:

  accept visitor/Visitor -> any:
    return visitor.visit-partial-concrete this

  stringify -> string:
    return "Partial: $name\n  Indentation: '$indentation'"

/**
A $PartialNode where the name of the partial is determined at runtime.

Example:
```
data:
  { dynamic: 'content' }
template:
  "{{>*dynamic}}"
partials:
  { content: 'Hello, world!' }
output:
  "Hello, world!"
```

This node is part of the dynamic-names extension.
*/
class PartialDynamicNode extends PartialNode:
  partial-field/string

  constructor .partial-field:

  accept visitor/Visitor -> any:
    return visitor.visit-partial-dynamic this

  stringify -> string:
    return "PartialDynamic: $partial-field\n Indentation: '$indentation'"

/**
A node that represents a block tag.

Block tags are used to define a block of content that can be overridden
  by a partial inheritance node.

Example:
```
{{$name}}...{{/name}}
```

Block tags are part of the inheritance extension.
See $PartialInheritanceNode.
*/
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

/**
A node that represents a partial inheritance.

Partial inheritance is an extension to the mustache syntax that allows
  a template to inherit from another template.

Example:
```
template:
  {{<super}}{{$title}}sub template title{{/title}}{{/super}}
partials:
  super: "...{{$title}}Default title{{/title}}..."
output:
  "...sub template title..."
```

Also see $BlockNode.
This node is part of the inheritance extension.
*/
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
