/**
An implementation of the JSON Schema Specification Draft 2022-12.
https://json-schema.org/draft/2020-12/json-schema-core#name-the-vocabulary-keyword
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

