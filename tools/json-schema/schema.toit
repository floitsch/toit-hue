/**
The JSON Schema Core Vocabulary.

The core vocabulary defines the keywords that provide the base of the JSON Schema specification. Every meta-schema must include the core vocabulary.
*/

class Object:


class Schema:
  meta-schema/string
  vocabularies/Map?
  id/string?

  constructor --.meta-schema --.vocabularies --.id:

class Parser:
  check-valid-uri str/string -> none:
    // TODO(florian): check that the string is a valid URI.
    return

  parse-schema o/Map -> string:
    schema-entry := o.get "\$schema"
    if not schema-entry:
      throw "Missing \$schema property"
    if schema-entry is not string:
      throw "\$schema must be a string"
    if schema-entry != "https://json-schema.org/draft/2020-12/schema":
      throw "Unsupported \$schema: $schema-entry"
    return schema-entry

  /**
  Parses the '\$vocabulary' entry.

  Vocabularies are maps from URIs to booleans. The boolean indicates whether
    understanding/supporting the vocabulary is necessary or not.

  If a vocabulary is not understood but required, then the processing of the
    schema must fail.
  If a vocabulary is not understood but not required, then unknown properties
    should be treated as annotations.

  Vocabularies are only allowed at the root of the schema.

  Vocabularies must be ignored for documents that are not being processed
    as meta schemas.
  */
  parse-vocabularies o/Map -> Map?:
    vocabulary-entry := o.get "\$vocabulary"
    if not vocabulary-entry:
      return null
    if vocabulary-entry is not Map:
      throw "\$vocabulary must be a map"
    vocabulary := vocabulary-entry as Map
    vocabulary.do: | key value |
      check-valid-uri key
      if value is not bool:
        throw "\$vocabulary values must be booleans"
    return vocabulary-entry

  parse-id o/Map -> string?:
    id := o.get "\$id"
    if id: check-valid-uri id
    return id

  parse-ref o/Map -> string?:
    ref := o.get "\$ref"
    if ref: check-valid-uri ref
    return ref

  parse-dynamic-ref o/Map -> string?:
    dynamic-ref := o.get "\$dynamicRef"
    if dynamic-ref: check-valid-uri dynamic-ref
    return dynamic-ref

  parse-anchor o/Map -> string?:
    anchor := o.get "\$anchor"
    if anchor: check-valid-uri anchor
    return anchor

  parse-dynamic-anchor o/Map -> string?:
    dynamic-anchor := o.get "\$dynamicAnchor"
    if dynamic-anchor: check-valid-uri dynamic-anchor
    return dynamic-anchor

  parse o:
    if o is not Map:
      throw "The root must be a map"
    // The meta schema.
    schema := parse-schema o
    vocabularies := parse-vocabularies o
    id := parse-id o
    ref := parse-ref o
    dynamic-ref := parse-dynamic-ref o
    anchor := parse-anchor o
    dynamic-anchor := parse-dynamic-anchor o

