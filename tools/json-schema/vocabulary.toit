/**
An implementation of the JSON Schema Specification Draft 2020-12.
https://tools.ietf.org/html/draft-bhutton-json-schema-00
*/

class Vocabulary:

class MetaCore:
  static KEYS ::= [
    "\$id",
    "\$schema",
    "\$anchor",
    "\$ref",
    "\$dynamicRef",
    "\$dynamicAnchor",
    "\$vocabulary",
    "\$comment",
    "\$defs",
  ]

interface MetaCoreVisitor:
  visit-id id/string
  visit-schema schema/string
  visit-anchor anchor/string
  visit-ref ref/string
  visit-dynamic-ref dynamic-ref/string
  visit-dynamic-anchor dynamic-anchor/string
  visit-vocabulary vocabulary/Map required/bool
  visit-comment comment/string
  visit-defs defs/Map

