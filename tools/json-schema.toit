/**
An implementation of the JSON Schema Specification Draft 2020-12.
https://tools.ietf.org/html/draft-bhutton-json-schema-00
*/

class Schema:
  static TRUE-SCHEMA ::= Schema.from-json {:}
  static FALSE-SCHEMA ::= Schema.from-json {:}

  /**
  The canonical URI of this schema.
  */
  id/string?

  /**
  The anchor of this schema.

  The anchor is a string that identifies a location within a resource.
  An anchor makes it possible to reference a schema in a way that is
    not tied to any particular structural location.

  Anchors must start with a letter (A-Za-z) or underscore (_), and
    may be followed by any number of letters, digits (0-9), hyphens (-),
    underscores, and periods (.).
  */
  anchor/string?

  /**
  A dynamic anchor.

  A dynamic anchor is a dynamic extension point for dynamic references.
  Dynamic anchors are a low-level feature, and $(anchor)s should
    typically be used instead.
  */
  dynamic-anchor/string?

  /**
  The schema dialect.
  Must be a URI.
  Must only be present on the root schema.

  Used as a JSON Schema dialect identifier, and as the identifier of
    a resource which is itself a JSON Schema, which describes the set
    of valid schemas written for this particular dialect.

  If this URI identifies a retrievable resource, that resource should
    be of media type "application/schema+json".
  */
  schema/string?

  /**
  The vocabularies available for use in schemas described by this
    meta schema.
  Must only be present on the root schema.

  Also used to indicate whether each vocabulary is required or
    optional, in the sense that an implementation must understand
    the required vocabularies in order to successfully process the
    scheam. Together, this information forms a dialect. Any
    vocabulary that is understood by the implementation must be
    processed in a manner consistent with the semantic definitions
    contained within the vocubulary.

  The keys of the map must be URIs (containing a scheme) and this
    URI must be normalized.

  The values of the map must be booleans. If the value is true,
    then implementations that do not recognize the vocabulary
    must refuse to process any schemas that declare this
    meta-schema. If the value is false, then implementations
    should proceed with processing.
  The value has no impact if the implementation understands the
    vocabulary.
  */
  vocabulary/Map?

  /**
  A reference to a statically identified schema.
  */
  ref/string?

  /**
  A reference to a schema that is identified dynamically.

  The full resolution of the reference is deferred until runtime, at
    which point it is resolved each time it is encountered while
    evaluating an instance.

  See $dynamic-anchor.
  */
  dynamic-ref/string?

  /**
  A map of re-usable JSON Schemas.
  */
  defs/Map?

  /**
  Comments.
  */
  comments/string?

  constructor.from-json o/any:
    if o == true: return Schema.TRUE-SCHEMA
    if o == false: return Schema.FALSE-SCHEMA
    return Schema.object o

  constructor.object o/Map:
    id = o.get "\$id"
    anchor = o.get "\$anchor"
    dynamic-anchor = o.get "\$dynamicAnchor"
    schema = o.get "\$schema"
    vocabulary = o.get "\$vocabulary"
    ref = o.get "\$ref"
    dynamic-ref = o.get "\$dynamicRef"
    defs = o.get "\$defs" --if-present=: | value/Map |
      value.map: | _ schema | Schema.from-json schema
    comments = o.get "\$comments"

  to-json -> any:
    if this == Schema.TRUE-SCHEMA: return true
    if this == Schema.FALSE-SCHEMA: return false
    result := {:}
    if id: result["\$id"] = id
    if anchor: result["\$anchor"] = anchor
    if dynamic-anchor: result["\$dynamicAnchor"] = dynamic-anchor
    if schema: result["\$schema"] = schema
    if vocabulary: result["\$vocabulary"] = vocabulary
    if ref: result["\$ref"] = ref
    if dynamic-ref: result["\$dynamicRef"] = dynamic-ref
    if defs: result["\$defs"] = defs.map: | _ schema | schema.to-json
    if comments: result["\$comments"] = comments
    return result
