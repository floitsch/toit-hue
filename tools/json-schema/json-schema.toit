/**
An implementation of the JSON Schema Specification Draft 2022-12.
https://json-schema.org/draft/2020-12/json-schema-core#name-the-vocabulary-keyword
*/

import certificate-roots
import http
import encoding.json
import net
import uuid show Uuid
import .uri
import .json-pointer
import .regex as regex

JSON-SCHEMA-2020-12-URI ::= "https://json-schema.org/draft/2020-12/schema"
OPENAPI-3_1-URI ::= "https://spec.openapis.org/oas/3.1/dialect/base"

// Cached entries for dialects, so we don't need to download the Schema.
DIALECTS ::= {
  JSON-SCHEMA-2020-12-URI: {
    VocabularyCore.URI: true,
    VocabularyApplicator.URI: true,
    VocabularyUnevaluated.URI: true,
    VocabularyValidation.URI: true,
    VocabularyMetaData.URI: true,
    VocabularyFormatAnnotation.URI: true,
    VocabularyContent.URI: true,
  },
  OPENAPI-3_1-URI: {
    VocabularyCore.URI: true,
    VocabularyApplicator.URI: true,
    VocabularyUnevaluated.URI: true,
    VocabularyValidation.URI: true,
    VocabularyMetaData.URI: true,
    VocabularyFormatAnnotation.URI: true,
    VocabularyContent.URI: true,
    VocabularyOpenApi.URI: true,
  },
}

KNOWN-VOCABULARIES ::= {
  VocabularyCore.URI: VocabularyCore,
  VocabularyApplicator.URI: VocabularyApplicator,
  VocabularyValidation.URI: VocabularyValidation,
  VocabularyUnevaluated.URI: VocabularyUnevaluated,
  VocabularyMetaData.URI: VocabularyMetaData,
  VocabularyFormatAnnotation.URI: VocabularyFormatAnnotation,
  VocabularyContent.URI: VocabularyContent,
  VocabularyOpenApi.URI: VocabularyOpenApi,
}

interface Vocabulary:
  uri -> string
  keywords -> List
  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> bool

class VocabularyCore implements Vocabulary:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/core"

  static KEYWORDS ::= [
    "\$schema",
    "\$vocabulary",
    "\$id",
    "\$anchor",
    "\$dynamicAnchor",
    "\$ref",
    "\$dynamicRef",
    "\$defs",
    "\$comment",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value
    json.get "\$anchor" --if-present=: | anchor-id/string |
      normalized-fragment := UriReference.normalize-fragment anchor-id
      anchor-uri := schema.schema-resource.uri.with-fragment normalized-fragment
      context.store.add anchor-uri.to-string schema

    json.get "\$dynamicAnchor" --if-present=: | anchor-id/string |
      normalized-fragment := UriReference.normalize-fragment anchor-id
      anchor-uri := schema.schema-resource.uri.with-fragment normalized-fragment
      context.store.add --dynamic anchor-uri.to-string schema --fragment=normalized-fragment

    json.get "\$ref" --if-present=: | ref/string |
      target-uri := schema.uri-reference ref
      applicator := Ref --target-uri=target-uri --is-dynamic=false
      context.refs.add applicator
      schema.add-applicator applicator

    json.get "\$dynamicRef" --if-present=: | ref/string |
      target-uri := schema.uri-reference ref
      applicator := Ref --target-uri=target-uri --is-dynamic
      context.refs.add applicator
      schema.add-applicator applicator

    json.get "\$defs" --if-present=: | defs/Map |
      schema-defs := defs.map: | key/string value/any |
        sub-pointer := json-pointer["\$defs"][key]
        // Building the schema will automatically add its json-pointer to the store.
        Schema.parse_ value --parent=schema --context=context --json-pointer=sub-pointer

int-value_ n/num? -> int?:
  if not n: return null
  if n is int: return n as int
  if n is float: return n.to-int
  unreachable

class VocabularyApplicator implements Vocabulary:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/applicator"

  static KEYWORDS ::= [
    "allOf",
    "anyOf",
    "oneOf",
    "not",
    "if",
    "then",
    "else",
    "dependentSchemas",
    "prefixItems",
    "items",
    "contains",
    "properties",
    "patternProperties",
    "additionalProperties",
    "propertyNames",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  map-schemas_ --list/List --parent/Schema? --context/BuildContext --json-pointer/JsonPointer -> List:
    result := List list.size: | i/int |
      sub-schema-json/any := list[i]
      // Building the schema will automatically add its json-pointer to the store.
      Schema.parse_ sub-schema-json --parent=parent --context=context --json-pointer=json-pointer[i]
    return result

  map-schemas_ --object/Map --parent/Schema? --context/BuildContext --json-pointer/JsonPointer -> Map:
    return object.map: | key/string sub-schema-json/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.parse_ sub-schema-json --parent=parent --context=context --json-pointer=json-pointer[key]

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    ["allOf", "anyOf", "oneOf"].do: | keyword/string |
      json.get keyword --if-present=: | entries/List |
        subschemas := map-schemas_
            --list=entries
            --parent=schema
            --context=context
            --json-pointer=json-pointer[keyword]
        kind/int := ?
        if keyword == "allOf": kind = X-Of.ALL-OF
        else if keyword == "anyOf": kind = X-Of.ANY-OF
        else if keyword == "oneOf": kind = X-Of.ONE-OF
        else: throw "unreachable"
        schema.add-applicator (X-Of --kind=kind subschemas)

    json.get "not" --if-present=: | not-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ not-entry --parent=schema --context=context --json-pointer=json-pointer["not"]
      schema.add-applicator (Not subschema)

    condition-subschema/Schema? := json.get "if" --if-present=: | if-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.parse_ if-entry --parent=schema --context=context --json-pointer=json-pointer["if"]

    // We build the then subschema even if there is no 'if', in case
    // the subschema is referenced.
    then-subschema/Schema? := json.get "then" --if-present=: | then-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.parse_ then-entry --parent=schema --context=context --json-pointer=json-pointer["then"]

    // We build the 'else' subschema even if there is no 'if', in case
    // the subschema is referenced.
    else-subschema/Schema? := json.get "else" --if-present=: | else-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.parse_ else-entry --parent=schema --context=context --json-pointer=json-pointer["else"]

    if condition-subschema:
      schema.add-applicator (IfThenElse condition-subschema then-subschema else-subschema)

    json.get "dependentSchemas" --if-present=: | dependent-schemas/Map |
      subschemas := map-schemas_
          --object=dependent-schemas
          --parent=schema
          --context=context
          --json-pointer=json-pointer["dependentSchemas"]
      schema.add-applicator (DependentSchemas subschemas)

    prefix-items := json.get "prefixItems" --if-present=: | prefix-items/List |
      subschemas := map-schemas_
          --list=prefix-items
          --parent=schema
          --context=context
          --json-pointer=json-pointer["prefixItems"]

    items := json.get "items" --if-present=: | items/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ items
          --parent=schema
          --context=context
          --json-pointer=json-pointer["items"]

    if prefix-items or items:
      schema.add-applicator (Items --prefix-items=prefix-items --items=items)

    json.get "contains" --if-present=: | contains/any |
      supports-min-max := schema.schema-resource.vocabularies.contains VocabularyValidation.URI
      min-contains := supports-min-max ? int-value_ (json.get "minContains") : null
      max-contains := supports-min-max ? int-value_ (json.get "maxContains") : null

      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ contains
          --parent=schema
          --context=context
          --json-pointer=json-pointer["contains"]
      schema.add-applicator (Contains subschema --min-contains=min-contains --max-contains=max-contains)

    properties := json.get "properties" --if-present=: | properties/Map |
      subschemas := map-schemas_
          --object=properties
          --parent=schema
          --context=context
          --json-pointer=json-pointer["properties"]

    additional-properties := json.get "additionalProperties" --if-present=: | additional-properties/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ additional-properties
          --parent=schema
          --context=context
          --json-pointer=json-pointer["additionalProperties"]

    pattern-properties := json.get "patternProperties" --if-present=: | pattern-properties/Map |
      subschemas := map-schemas_
          --object=pattern-properties
          --parent=schema
          --context=context
          --json-pointer=json-pointer["patternProperties"]

    if properties or additional-properties or pattern-properties:
      applicator := Properties
          --properties=properties
          --patterns=pattern-properties
          --additional=additional-properties
      schema.add-applicator applicator

    json.get "propertyNames" --if-present=: | property-names/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ property-names
          --parent=schema
          --context=context
          --json-pointer=json-pointer["propertyNames"]
      schema.add-applicator (PropertyNames subschema)


class VocabularyUnevaluated implements Vocabulary:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/unevaluated"
  static KEYWORDS ::= [
    "unevaluatedItems",
    "unevaluatedProperties",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    json.get "unevaluatedItems" --if-present=: | unevaluated-items/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ unevaluated-items
          --parent=schema
          --context=context
          --json-pointer=json-pointer["unevaluatedItems"]
      schema.add-applicator (UnevaluatedItems subschema)

    json.get "unevaluatedProperties" --if-present=: | unevaluated-properties/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.parse_ unevaluated-properties
          --parent=schema
          --context=context
          --json-pointer=json-pointer["unevaluatedProperties"]
      schema.add-applicator (UnevaluatedProperties subschema)

class VocabularyValidation implements Vocabulary:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/validation"

  static KEYWORDS ::= [
    "type",
    "enum",
    "const",
    "minContains",
    "maxContains",
    "multipleOf",
    "maximum",
    "exclusiveMaximum",
    "minimum",
    "exclusiveMinimum",
    "required",
    "minLength",
    "maxLength",
    "maxItems",
    "minItems",
    "uniqueItems",
    "minProperties",
    "maxProperties",
    "pattern",
    "dependentRequired",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    json.get "type" --if-present=: | type/any |
      if type is string: type = [type]
      schema.add-assertion (Type type)

    json.get "enum" --if-present=: | enum-values/any |
      schema.add-assertion (Enum enum-values)

    json.get "const" --if-present=: | value/any |
      schema.add-assertion (Const value)

    ["multipleOf", "maximum", "exclusiveMaximum", "minimum", "exclusiveMinimum"].do: | keyword/string |
      json.get keyword --if-present=: | value |
        if value is not num:
          throw "Invalid value for '$keyword' keyword: $value"
        n := value as num
        kind/int := ?
        if keyword == "multipleOf": kind = NumComparison.MULTIPLE-OF
        else if keyword == "maximum": kind = NumComparison.MAXIMUM
        else if keyword == "exclusiveMaximum": kind = NumComparison.EXCLUSIVE-MAXIMUM
        else if keyword == "minimum": kind = NumComparison.MINIMUM
        else if keyword == "exclusiveMinimum": kind = NumComparison.EXCLUSIVE-MINIMUM
        else: throw "unreachable"
        schema.add-assertion (NumComparison --kind=kind n)

    json.get "required" --if-present=: | required-properties/List |
      schema.add-assertion (Required required-properties)

    min-length := int-value_ (json.get "minLength")
    max-length := int-value_ (json.get "maxLength")
    if min-length or max-length:
      schema.add-assertion (StringLength --min=min-length --max=max-length)

    min-items := int-value_ (json.get "minItems")
    max-items := int-value_ (json.get "maxItems")
    if min-items or max-items:
      schema.add-assertion (ArrayLength --min=min-items --max=max-items)

    json.get "uniqueItems" --if-present=: | val/bool |
      if val: schema.add-assertion UniqueItems

    min-properties := int-value_ (json.get "minProperties")
    max-properties := int-value_ (json.get "maxProperties")
    if min-properties or max-properties:
      schema.add-assertion (ObjectSize --min=min-properties --max=max-properties)

    json.get "pattern" --if-present=: | pattern/string |
      schema.add-assertion (Pattern pattern)

    json.get "dependentRequired" --if-present=: | dependent-required/Map |
      schema.add-assertion (DependentRequired dependent-required)

class VocabularyFormatAnnotation implements Vocabulary:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/format-annotation"

  static KEYWORDS ::= [
    "format",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    json.get "format" --if-present=: | format/string |
      schema.add-assertion (Format format)

abstract class VocabularyAnnotationBase implements Vocabulary:
  abstract uri -> string
  abstract keywords -> List

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    keywords.do: | keyword/string |
      // We assume that the values have the correct type.
      // The meta-schema can be used to validate the schema, so we don't need to do this
      // here.
      json.get keyword --if-present=: | value |
        schema.add-assertion (Annotation keyword value)

class VocabularyMetaData extends VocabularyAnnotationBase:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/meta-data"

  static KEYWORDS ::= [
    "title",
    "description",
    "default",
    "deprecated",
    "readOnly",
    "writeOnly",
    "examples",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

class VocabularyContent extends VocabularyAnnotationBase:
  static URI ::= "https://json-schema.org/draft/2020-12/vocab/content"

  static KEYWORDS ::= [
    "contentSchema",
    "contentMediaType",
    "contentEncoding",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

/**
Vocabulary for OpenAPI.

The OpenAPI specification is geared towards their OpenAPI specifications and
  is relatively vague on how to correctly implement the vocabulary outside
  the context of OpenAPI. Specifically, OpenAPI uses the term "parent", which
  is neither defined in the OpenAPI specification, nor the JSON Schema.
  It is also not giving any guidance on corner cases that could arrive
  when using the discriminator keyword.

The OpenAPI vocabulary is relatively invasive. It required changes to the
  following parts of this library:
- The X-Of applicator: Can now be disabled, since the discriminator "shadows"
  the functionality.
- Schemas: Due to the implicit 'all-of' targets, it's necessary to guard
  schemas that are in an 'allOf' chain so that there isn't any infinite
  recursion.
*/
class VocabularyOpenApi implements Vocabulary:
  static URI ::= "https://spec.openapis.org/oas/3.1/dialect/base"

  static KEYWORDS ::= [
    "discriminator",
    "xml",
    "externalDocs",
    "example",  // Deprecated but still supported.
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  add-actions --schema/Schema --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    // The 'discriminator' keyword is handled by the X-Of applicator.
    [ "xml", "externalDocs", "example" ].do: | keyword/string |
      json.get keyword --if-present=: | value/any |
        schema.add-assertion (Annotation keyword value)

    json.get "discriminator" --if-present=: | discriminator-json/any |
      property-name := discriminator-json.get "propertyName" --if-absent=:
        throw "Missing 'propertyName' in 'discriminator' keyword."
      mapping := discriminator-json.get "mapping"
      uri-ref-mapping/Map? := null
      if mapping:
        uri-ref-mapping = mapping.map: | _ ref/string |
          schema.uri-reference ref
      discriminator := Discriminator property-name uri-ref-mapping
      context.discriminators.add [discriminator, schema]
      schema.add-applicator discriminator

  static flatten_ schema/Schema tree/Map --seen/Set --result/List -> none:
    absolute-location := schema.absolute-location
    if seen.contains absolute-location:
      throw "Recursive all-of loop"
    seen.add absolute-location
    parents := tree.get absolute-location
    if not parents: return
    parents.do: | parent/Schema |
      flatten_ parent tree --seen=seen --result=result
      result.add parent

  /**
  Computes the all-of hierarchy.

  We consider a schema to be a "parent" of another schema, if it is the
    target of a 'ref' inside an 'allOf' keyword.

  Returns a map from schema URI to a list of schemas that have the schema
    as a parent.
  */
  static compute-all-of-hierarchy_ context/BuildContext -> Map:
    seen := {}  // Set of schema URIs that have already been seen.
    // The tree is a map from schema URI to a list of schemas.
    // Any entry in the value means that the key is the target of an 'allOf' keyword.
    // Only considers 'refs' in the all-of keywords.
    tree := {:}
    context.store.do: | uri/string schema/Schema |
      // Schemas may exist under multiple URIs in the store.
      // Make sure we look at each one only once.
      if seen.contains schema.absolute-location: continue.do
      seen.add schema.absolute-location

      schema.actions.do: | action/Action |
        if action is X-Of:
          x-of := action as X-Of
          if x-of.kind == X-Of.ALL-OF:
            x-of.subschemas.do: | subschema/Schema |
              subactions := subschema.actions
              if subschema.actions.size != 1:
                continue.do
              subaction := subactions.first
              if subaction is not Ref or (subaction as Ref).is-dynamic:
                continue.do
              ref := subaction as Ref
              target-uri := ref.target.absolute-location
              (tree.get target-uri --init=:[]).add schema

    return tree

  /**
  Resolves the discriminators.

  Builds the map from identifier to schema for the discriminators.
  All references must be resolved before calling this method.
  */
  static resolve-discriminators --context/BuildContext -> none:
    all-of-hierarchy := compute-all-of-hierarchy_ context

    all-of-hierarchy-parents := {:}
    all-of-hierarchy.do: | parent-url/UriReference children/List |
      children.do: | child/Schema |
        all-of-hierarchy-parents[child.absolute-location] = parent-url

    one-of-schemas := {:}  // From schema-uri to list of options.
    all-of-schemas := {:}  // From schema-UriReference to Discriminator.

    context.discriminators.do: | entry/List |
      discriminator/Discriminator := entry[0]
      schema/Schema := entry[1]

      discriminator.all-of-hierarchy-parents = all-of-hierarchy-parents

      // See if the schema contains an `anyOf` or `oneOf` keyword.
      x-of/X-Of? := null
      for i := 0; i < schema.actions.size; i++:
        action := schema.actions[i]
        if action is X-Of:
          potential-x-of := action as X-Of
          if potential-x-of.kind == X-Of.ANY-OF or potential-x-of.kind == X-Of.ONE-OF:
            x-of = potential-x-of
            break

      // Map from uri to schema.
      implicit-targets/List := ?
      if x-of:
        // This discriminator will do the job of the x-of.
        x-of.is-disabled = true

        implicit-targets = x-of.subschemas.map: | subschema/Schema |
          // Find the 'ref' in the subschema.
          target/Schema? := null
          actions := subschema.actions
          for i := 0; i < actions.size; i++:
            action/Action := actions[i]
            if action is Ref:
              ref := action as Ref
              if ref.is-dynamic:
                throw "Invalid discriminator schema with 'anyOf' or 'oneOf' keyword. Only non-dynamic references are allowed."
              target = ref.target
              if not target:
                throw "Unresolved target for ref that is used in discriminator."
              break
          target
      else:
        // The schema containing this discriminator doesn't have any
        // x-of keyword. This means we need to use all "parents" (having
        // this schema as `allOf`)
        // The specification isn't really clear on how to find parents. We
        // just find schemas that have the discriminator-keyword as transitive
        // 'allOf'.
        // See https://github.com/OAI/OpenAPI-Specification/issues/3591.
        implicit-targets = []
        flatten_ schema all-of-hierarchy --seen={} --result=implicit-targets
        schema.all-of-discriminator = discriminator
        implicit-targets.do: | child/Schema |
            child.all-of-discriminator = discriminator

      inverted-mapping := {:}
      if discriminator.mapping:
        discriminator.mapping.do: | key/any value/UriReference |
          inverted-mapping[value] = key

      resolved-mapping := {:}

      implicit-targets.do: | schema/Schema |
        explicit-mapping/string? := inverted-mapping.get schema.absolute-location
        if explicit-mapping:
          resolved-mapping[explicit-mapping] = schema
        else:
          // Find the implicit name of the schema.
          segments := schema.json-pointer.segments
          i := segments.size - 1
          while i > 0:
            // The OpenAPI spec isn't really clear on how to find the name, but
            // the following approach works with the examples they give.
            // In practice we probably only remove one 'allOf'.
            if segments[i] != "allOf":
              break
            i--
          resolved-mapping[segments[i]] = schema

      discriminator.kind = x-of ? x-of.kind : X-Of.ALL-OF
      discriminator.resolved-mapping = resolved-mapping

interface ResourceLoader:
  load url/string -> any

class HttpResourceLoader implements ResourceLoader:
  constructor:
    certificate-roots.install-all-trusted-roots

  load url/string -> any:
    network := net.open
    client/http.Client? := null
    try:
      client = http.Client network
      response := client.get --uri=url
      if response.status-code != 200:
        throw "HTTP error: $response.status-code $response.status-message"
      result := json.decode-stream response.body
      while response.body.read: null
      return result
    finally:
      if client: client.close
      network.close

class Result:
  /**
  When this result is converted to JSON with the structure equal to $STRUCTURE-FLAG,
    then the returned object contains a single field "valid" with the value of $is-valid.
  */
  static STRUCTURE-FLAG ::= 0
  /**
  When this result is converted to JSON with the structure equal to $STRUCTURE-BASIC,
    then the returned object contains the following fields:
  - "valid": A boolean indicating whether the validation was successful.
  - "annotations"/"errors": A list of annotations or errors, depending on $is-valid.

  See $Detail.to-json for the structure of the annotations and errors.
  */
  static STRUCTURE-BASIC ::= 1

  // The result of the root schema.
  schema-result_/SubResult

  constructor.private_ .schema-result_:

  annotations-for instance-pointer/JsonPointer -> List:
    return schema-result_.annotations.get instance-pointer --if-absent=: []

  /** Whether the validation was successful. */
  is-valid -> bool:
    return schema-result_.is-valid

  /** A list of details of type $Detail. */
  details -> List:
    if not schema-result_.is-valid:
      return schema-result_.errors.copy or []
    if not schema-result_.annotations: return []

    annotations := []
    schema-result_.annotations.do --values: | value/List |
      annotations.add-all value
    return annotations

  /**
  Returns this result as a JSON object.

  Dependening on the $structure-kind, the returned object has different fields.

  If $structure-kind is equal to $STRUCTURE-FLAG, then the returned object consists
    of a map with a single field:
  - "valid": A boolean indicating whether the validation was successful.

  If $structure-kind is equal to $STRUCTURE-BASIC, then the returned object consists
    of a map with the following fields:
  - "valid": A boolean indicating whether the validation was successful.
  - "annotations": A list of annotations. This field is only present if the validation
    was successful. See $Detail.to-json for the structure of the annotations.
  - "errors": A list of map from instance pointers to lists of errors. This field is
    only present if the validation was not successful. See $Detail.to-json for the
    structure of the errors.
  */
  to-json --structure-kind/int=STRUCTURE-BASIC -> Map:
    if structure-kind != STRUCTURE-FLAG and structure-kind != STRUCTURE-BASIC:
      throw "INVALID_ARGUMENT"

    if structure-kind == STRUCTURE-FLAG:
      return {"valid": is-valid}

    json-details := details.map: | detail/Detail |
      detail.to-json

    return {
      "valid": is-valid,
      is-valid ? "annotations" : "errors": json-details
    }

class SubResult:
  location/InstantiatedSchema?
  instance-pointer/JsonPointer
  is-valid/bool := true
  annotations/Map? := null
  errors/List? := null

  constructor .location .instance-pointer:

  /**
  Merges the $sub result into this one.
  Reuses the $sub result's fields if possible. This means that the $sub result
    can not be used after this method is called.

  If the given $sub is not valid, marks this instance as not valid.

  Only merges annotations if the $sub is valid.
  */
  merge sub/SubResult -> none:
    if not sub.is-valid:
      is-valid = false

    if sub.errors:
      assert: not sub.is-valid
      if not errors:
        errors = sub.errors
      else:
        errors.add-all sub.errors

    if sub.is-valid and sub.annotations:
      if not annotations:
        annotations = sub.annotations
      else:
        sub.annotations.do: | key/string sub-entries/List |
          this-entry := annotations.get key
          if not this-entry:
            annotations[key] = sub-entries
          else:
            this-entry.add-all sub-entries

  fail-false -> none:
    is-valid = false
    error := Detail.false-error
        --instance-pointer=instance-pointer
        --location=location
    errors = [error]

  fail -> none
      keyword/string
      value/any
      --instance-pointer=instance-pointer
  :
    is-valid = false
    if not errors:
      errors = []
    error := Detail.error
        --keyword=keyword
        --instance-pointer=instance-pointer
        --location=location
        value
    errors.add error

  annotate -> none
      keyword/string
      value/any
  :
    if not annotations:
      annotations = {:}
    annotation-key := instance-pointer.to-string
    entries := annotations.get annotation-key --init=:[]
    annotation := Detail.annotation
        --keyword=keyword
        --instance-pointer=instance-pointer
        --location=location
        value
    entries.add annotation

/**
An annotation or error.
*/
class Detail:
  is-error/bool
  keyword/string?
  instance-pointer/JsonPointer
  location/InstantiatedSchema
  value/any

  constructor.annotation --.keyword --.instance-pointer --.location .value:
    is-error = false

  constructor.error --.keyword --.instance-pointer --.location .value:
    is-error = true

  constructor.false-error --.instance-pointer --.location:
    is-error = true
    keyword = null
    value = "This instance is disallowed by a boolean 'false' schema."

  /**
  Converts this detail to JSON.

  The returned object contains the following fields:
  - `keywordLocation`: the relative location, as JSON pointer, of the keyword that
    produced the detail.
  - `absoluteKeywordLocation`: the absolute, dereferenced location of the keyword
    that produced the detail. This location is constructed using the canonical
    URL of the schema resource with a JSON pointer fragment.
  - `instanceLocation`: the location, as JSON pointer, of the JSON value within the
    instance that produced the detail.
  */
  to-json:
    result := {:}
    keyword-location := keyword ? [keyword] : []
    current/InstantiatedSchema? := location
    while current:
      keyword-location.add current.segment
      current = current.parent
    i := 0
    j := keyword-location.size - 1
    while i < j:
      t := keyword-location[i]
      keyword-location[i++] = keyword-location[j]
      keyword-location[j--] = t

    result["keywordLocation"] = keyword-location.join "/"
    absolute-location := location.schema.absolute-location.to-string
    if keyword: absolute-location += "/$keyword"
    result["absoluteKeywordLocation"] = absolute-location
    result["instanceLocation"] = instance-pointer.to-string
    json-value := value
    if json-value is Set: json-value = json-value.to-list
    if is-error:
      result["error"] = json-value
    else:
      result["annotation"] = json-value
    return result

/**
Builds the $JsonSchema for the given JSON value $o.

Conceptually this consists of:
  - Parsing the JSON value into a schema.
  - Resolving all references.

Users may want to use the $parse and $resolve methods directly, if they want to
  control the process more closely. For example, the OpenAPI specification has
  schemas intermingled with other data, in which case $parse needs to be called
  multiple times with different json-pointers.
*/
build o/any --resource-loader/ResourceLoader=HttpResourceLoader -> JsonSchema:
  context := BuildContext --resource-loader=resource-loader
  schema := parse o --resource-loader=resource-loader --context=context
  resolve --context=context
  return schema

parse o/any -> JsonSchema
    --context/BuildContext
    --resource-loader/ResourceLoader=HttpResourceLoader
    --json-pointer/JsonPointer=JsonPointer
    --base-uri/UriReference?=null
:
  root-schema := Schema.parse_ o
      --context=context
      --json-pointer=json-pointer
      --parent=null
      --base-uri=base-uri
  return JsonSchema root-schema context.store

/**
Resolves all references that were collected during the parsing of the schema.

The given $context contains the references and the store with all the schemas.
*/
resolve --context/BuildContext:
  store := context.store
  resource-loader := context.resource-loader
  // Resolve all references.
  while not context.refs.is-empty:
    pending := context.refs
    context.refs = []
    pending.do: | ref/Ref |
      target-uri := ref.target-uri
      target-uri-no-fragment := target-uri.with-fragment null
      context.resource-uri-id-mapping.get target-uri-no-fragment --if-present=: | replacement/UriReference |
        // The target URI is actually an ID that was defined in a resource.
        target-uri = replacement.with-fragment target-uri.fragment
      target := target-uri.to-string
      resolved := store.get target

      if not resolved:
        missing-resource-url := target-uri.with-fragment null
        missing-resource-url-string := missing-resource-url.to-string
        if not store.get missing-resource-url-string:
          resource-json := resource-loader.load missing-resource-url-string
          // Building the schema will automatically add its json-pointer to the store.
          schema := Schema.parse_ resource-json
              --context=context
              --json-pointer=JsonPointer
              --parent=null
              --base-uri=missing-resource-url
          // The downloaded resource might have an ID that is different than the URL.
          store.add missing-resource-url-string schema
          // Try again to find the target.
          resolved = store.get target
        if not resolved:
          throw "Could not resolve reference: $target"

      dynamic-fragment := store.get-dynamic-fragment target
      ref.set-target resolved --dynamic-fragment=dynamic-fragment

  if not context.discriminators.is-empty:
    VocabularyOpenApi.resolve-discriminators --context=context

class JsonSchema:
  schema_/Schema
  store_/Store

  constructor .schema_ .store_:

  validate o/any --collect-annotations/bool=true --collect-all-errors/bool=false -> Result:
    location := InstantiatedSchema null "" schema_
    context := ValidationContext
        --store=store_
        --needs-all-errors=collect-all-errors
        --needs-annotations=collect-annotations
    subresult := location.validate o --context=context --instance-pointer=JsonPointer
    return Result.private_ subresult

class ValidationContext:
  store/Store
  needs-annotations/bool
  needs-all-errors/bool

  constructor --.store --.needs-annotations/bool --.needs-all-errors/bool:

  with --needs-annotations/bool:
    return ValidationContext
        --store=store
        --needs-annotations=needs-annotations
        --needs-all-errors=needs-all-errors

/**
A schema resource identifies a group of schemas.

It defines which vocabulary is used.
It resets the json-pointer.
It sets the URL for all contained schemas that are relative to the resource.
*/
class SchemaResource_:
  uri/UriReference
  vocabularies/Map  // The dialect of this schema resource.
  handled-keywords/Set  // The keywords handled by the vocabularies.

  constructor o/any --parent/Schema? --base-uri/UriReference? --build-context/BuildContext:
    id/string? := o is Map ? o.get "\$id" : null

    if not id and base-uri:
      id = base-uri.to-string
    else if not id:
      id = "urn:uuid:$(Uuid.uuid5 "json-schema" "$Time.now.ns-since-epoch")"
    // Empty fragments are allowed (but not recommended).
    // Trim them.
    id = id.trim --right "#"
    new-uri := UriReference.parse id
    if not new-uri.is-absolute:
      new-uri = new-uri.resolve --base=parent.schema-resource.uri
    new-uri = new-uri.normalize
    this.uri = new-uri

    if id and base-uri and new-uri != base-uri:
      // The resource was loaded with the base-uri, but it declares a different ID.
      // Remember the mapping.
      build-context.resource-uri-id-mapping[base-uri] = new-uri

    // Unless this is a schema with a "$schema" property that overrides the
    // dialect, these are the vocabularies we want to use:
    //  Inherit from parent if there is one, otherwise use the default ones.
    specified-schema := o is Map and o.get "\$schema"
    if specified-schema or not parent:
      meta-uri := specified-schema or build-context.default-vocabulary-uri
      dialect := DIALECTS.get meta-uri
      if not dialect:
        meta-schema := build-context.resource-loader.load meta-uri
        if meta-schema is Map:
          dialect = meta-schema.get "\$vocabulary"
      vocabularies = {:}
      dialect.do: | vocabulary-uri/string required/bool |
        vocabulary := KNOWN-VOCABULARIES.get vocabulary-uri
        if not vocabulary and required:
          throw "Unknown vocabulary: $vocabulary-uri"
        if vocabulary:
          vocabularies[vocabulary-uri] = vocabulary
    else:
      vocabularies = parent.schema-resource.vocabularies

    handled-keywords = {}
    vocabularies.do: | _ vocabulary/Vocabulary |
      handled-keywords.add-all vocabulary.keywords

/**
An instantiated schema is a schema that has been resolved and has a dynamic location in the schema tree.
*/
abstract class InstantiatedSchema:
  parent/InstantiatedSchema?
  segment/string
  schema/Schema?

  constructor parent/InstantiatedSchema? segment/string schema/Schema:
    return schema.instantiate --parent=parent --segment=segment

  constructor.from-sub_ .parent .segment .schema:

  operator [] segment/string -> InstantiatedSchema:
    return InstantiatedSchemaGroup this segment

  operator [] segment/string sub-schema/Schema -> InstantiatedSchema:
    return InstantiatedSchema this segment sub-schema

  do-schema-resources --reversed [block]:
    if not reversed: throw "INVALID_ARGUMENT"
    do-schema-resources_ --reversed null block

  do-schema-resources_ --reversed last-resource [block]:
    resources := []
    current := this
    while current != null:
      if current.schema:
        current-resource := current.schema.schema-resource
        if current-resource != last-resource:
          resources.add current-resource
          last-resource = current-resource
      current = current.parent

    resources.do --reversed block

  abstract validate o/any --context/ValidationContext --instance-pointer/JsonPointer -> SubResult

class InstantiatedSchemaGroup extends InstantiatedSchema:
  constructor parent/InstantiatedSchema? segment/string:
    super.from-sub_ parent segment null

  validate o/any --context/ValidationContext --instance-pointer/JsonPointer -> SubResult:
    unreachable

class InstantiatedSchemaObject extends InstantiatedSchema:
  constructor parent/InstantiatedSchema? segment/string schema/Schema:
    super.from-sub_ parent segment schema

  schema_ -> Schema:
    return schema as Schema

  validate o/any --context/ValidationContext --instance-pointer/JsonPointer -> SubResult:
    if schema_.all-of-discriminator:
      // This is a schema that is the target of a ref in an allOf chain.
      // If we entering the chain, we have to call the discriminator.
      // Otherwise we do the normal validation.
      if segment == "\$ref" and
          parent and parent.parent and parent.parent.segment == "allOf":
        // We are already in the chain.
        // Do the normal validation (by falling through).
      else if segment == "discriminator":
        // We are beginning the chain.
        // Do the normal validation (by falling through).
      else:
        // Use the discriminator.
        return schema_.all-of-discriminator.validate o
            --context=context
            --location=this
            --instance-pointer=instance-pointer
            --required-hierarchy-schema=schema_

    if not context.needs-annotations:
      // Check if one of our actions need annotation.
      action-needs-annotations := schema_.actions.any: | action/Action |
        action is AnnotationsApplicator
      if action-needs-annotations:
        // From now on all sub schemas will collect annotations.
        // That's almost certainly too much, as most AnnotationsApplicators only
        // need annotations for the current object, but this is still short cutting
        // a lot of work.
        context = context.with --needs-annotations=true
    store := context.store
    result := SubResult this instance-pointer
    schema_.actions.do: | action/Action |
      action-result/SubResult := ?
      if action is AnnotationsApplicator:
        annotations-action := action as AnnotationsApplicator
        action-result = annotations-action.validate o
            --context=context
            --location=this
            --annotations=result.annotations
            --instance-pointer=instance-pointer
      else:
        action-result = action.validate o
            --context=context
            --location=this
            --instance-pointer=instance-pointer
      result.merge action-result
      if not context.needs-all-errors and not result.is-valid:
        return action-result

    return result

class InstantiatedSchemaBool extends InstantiatedSchema:
  constructor parent/InstantiatedSchema? segment/string schema/Schema:
    super.from-sub_ parent segment schema

  validate o/any --context/ValidationContext --instance-pointer/JsonPointer -> SubResult:
    result := SubResult this instance-pointer
    if not schema.json-value:
      result.fail-false
    return result


class Schema:
  json-pointer/JsonPointer
  json-value/any
  schema-resource/SchemaResource_? := ?
  is-resolved/bool := false
  is-sorted_/bool := false
  absolute-location/UriReference

  /**
  If this schema is in an all-of chain where the super-parent has an
    OpenAPI discriminator, then this is the discriminator of that super parent.

  */
  all-of-discriminator/Discriminator? := null

  actions/List ::= []

  add-applicator applicator/Applicator:
    actions.add applicator

  add-assertion assertion/Assertion:
    actions.add assertion

  constructor.private_ .json-pointer .json-value --.schema-resource --.absolute-location:

  static parse_ o/any -> Schema
      --parent/Schema?
      --context/BuildContext
      --json-pointer/JsonPointer
      --base-uri/UriReference? = null
  :
    schema-resource/SchemaResource_ := ?
    if not parent or (o is Map and o.get "\$id"):
      schema-resource = SchemaResource_ o --parent=parent --base-uri=base-uri --build-context=context
      if parent:
        // Reset the json-pointer, unless this is the root schema, where the pointer
        // was passed in.
        json-pointer = JsonPointer
    else:
      schema-resource = parent.schema-resource

    escaped-json-pointer := json-pointer.to-fragment-string
    escaped-json-pointer = UriReference.normalize-fragment escaped-json-pointer
    schema-json-pointer-url := schema-resource.uri.with-fragment escaped-json-pointer

    result := Schema.private_ json-pointer o
        --schema-resource=schema-resource
        --absolute-location=schema-json-pointer-url

    if o is Map:
      result.schema-resource.vocabularies.do: | _ vocabulary/Vocabulary |
        vocabulary.add-actions --schema=result --context=context --json-pointer=json-pointer

      // All keywords that are not handled by the dialect are treated like annotations.
      o.do: | key/string value/any |
        if not result.schema-resource.handled-keywords.contains key:
          result.add-assertion (Annotation key value)

    context.store.add schema-json-pointer-url.to-string result
    if json-pointer.to-fragment-string == "":
      // Also add this schema without any fragment.
      context.store.add result.schema-resource.uri.to-string result
    return result

  instantiate --parent/InstantiatedSchema? --segment/string -> InstantiatedSchema:
    if json-value is bool:
      return InstantiatedSchemaBool parent segment this
    else:
      if not is-sorted_:
        actions.sort --in-place: | a/Action b/Action | a.order.compare-to b.order
        is-sorted_ = true
      return InstantiatedSchemaObject parent segment this

  uri-reference ref/string -> UriReference:
    reference := (UriReference.parse ref).normalize
    return reference.resolve --base=schema-resource.uri

class BuildContext:
  store/Store ::= Store
  refs/List := []  // Of ActionRef.
  discriminators/List ::= []  // Of [Discriminator, Schema].
  resource-loader/ResourceLoader
  /**
  Resource-schemas can be loaded through a URL that isn't their actual ID.
  For example, this can happen when a loaded schema defines its own "$id" property.
  */
  resource-uri-id-mapping := {:}  // From UriReference to UriReference.
  default-vocabulary-uri/string

  constructor
      --.resource-loader=HttpResourceLoader
      --.default-vocabulary-uri=JSON-SCHEMA-2020-12-URI:

class Store:
  entries_/Map ::= {:}
  dynamic-entries_/Map ::= {:}

  add uri/string schema/Schema:
    entries_[uri] = schema

  add --dynamic/bool uri/string schema/Schema --fragment/string:
    entries_[uri] = schema
    dynamic-entries_[uri] = fragment

  get uri/string -> Schema?:
    return entries_.get uri

  get-dynamic-fragment uri/string -> string?:
    return dynamic-entries_.get uri

  do [block] -> none:
    entries_.do block

abstract class Action:
  static ORDER-EARLY ::= 20
  static ORDER-DEFAULT ::= 50
  static ORDER-LATE ::= 70

  /**
  The order/precedence of the action.

  An action with a lower order is executed before an action with a higher order.
  This can be used to ensure that certain actions are executed before others.

  Typically, actions that are fast to execute should be executed first, so that their failure
    short-circuits the validation.

  Applicators should never run after ORDER-LATE, as the $UnevaluatedProperties and $UnevaluatedItems applicators
    are run at that level and need to know whether subschemas have evaluated properties/items.
  */
  abstract order -> int

  abstract validate o/any --context/ValidationContext --location/InstantiatedSchema --instance-pointer/JsonPointer -> SubResult

abstract class Applicator extends Action:
  order -> int:
    return Action.ORDER-DEFAULT

abstract class AnnotationsApplicator extends Applicator:
  order -> int:
    return Action.ORDER-LATE

  abstract validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
      --annotations/Map?

abstract class Assertion extends Action:
  order -> int:
    return Action.ORDER-EARLY

abstract class SimpleAssertion extends Assertion:
  abstract validate o/any [fail] -> none

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    validate o: | keyword/string error-message/string |
      result.fail keyword error-message
    return result

abstract class SimpleStringAssertion extends Assertion:
  abstract validate str/string [fail] -> none

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not string: return result
    validate (o as string): | keyword/string error-message/string |
      result.fail keyword error-message
    return result

abstract class SimpleNumAssertion extends Assertion:
  abstract validate n/num [fail] -> none

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not num: return result
    validate (o as num): | keyword/string error-message/string |
      result.fail keyword error-message
    return result

abstract class SimpleObjectAssertion extends Assertion:
  abstract validate o/Map [fail] -> none

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not Map: return result
    validate (o as Map): | keyword/string error-message/string |
      result.fail keyword error-message
    return result

abstract class SimpleListAssertion extends Assertion:
  abstract validate o/List [fail] -> none

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not List: return result
    validate (o as List): | keyword/string error-message/string |
      result.fail keyword error-message
    return result

class Ref extends Applicator:
  target-uri/UriReference
  resolved_/Schema? := null
  is-dynamic/bool := ?
  dynamic-fragment/string? := null

  constructor --.target-uri --.is-dynamic:

  set-target schema/Schema --dynamic-fragment/string?:
    if is-dynamic and dynamic-fragment:
      this.dynamic-fragment = dynamic-fragment
    else:
      // If a dynamic reference resolves to a non-dynamic anchor, then it
      // behaves like a normal ref.
      is-dynamic = false
    resolved_ = schema

  target -> Schema?:
    return resolved_

  find-dynamic-schema_ --location/InstantiatedSchema --store/Store -> Schema:
    location.do-schema-resources --reversed: | resource/SchemaResource_ |
      dynamic-target-uri := resource.uri.with-fragment dynamic-fragment
      dynamic-target := dynamic-target-uri.to-string
      dynamic-target-schema := store.get dynamic-target
      if not dynamic-target-schema:
        continue.do-schema-resources
      if not store.get-dynamic-fragment dynamic-target:
        // Wasn't actually a dynamic target.
        continue.do-schema-resources
      return dynamic-target-schema
    // We know that there is a dynamic anchor in the same resource.
    // Otherwise we would have changed the dynamic reference to a static one.
    throw "Dynamic reference withouth a dynamic target: $target-uri"

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    resolved/Schema? := is-dynamic
        ? find-dynamic-schema_ --location=location --store=context.store
        : resolved_

    if resolved == null:
      throw "Unresolved reference: $target-uri"

    return location["\$ref", resolved].validate o --context=context --instance-pointer=instance-pointer

class X-Of extends Applicator:
  static ALL-OF ::= 0
  static ANY-OF ::= 1
  static ONE-OF ::= 2

  kind/int
  subschemas/List
  // An x-of keyword can be disabled it there is an OpenAPI discriminator. In that
  // case the discriminator does the work of the x-of keyword.
  is-disabled/bool := false

  constructor --.kind .subschemas:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if is-disabled:
      return result

    if kind == ALL-OF:
      all-of-location := location["allOf"]
      for i := 0; i < subschemas.size; i++:
        subschema := subschemas[i]
        subresult := all-of-location["$i", subschema].validate o
            --context=context
            --instance-pointer=instance-pointer
        result.merge subresult
        if not subresult.is-valid and not context.needs-all-errors:
          break
      if not result.is-valid:
        result.fail "allOf" "Expected all subschemas to match."
      return result
    else:
      success-count := 0
      keyword := kind == ANY-OF ? "anyOf" : "oneOf"
      x-of-location := location[keyword]
      for i := 0; i < subschemas.size; i++:
        subschema := subschemas[i]
        subresult := x-of-location["$i", subschema].validate o
            --context=context
            --instance-pointer=instance-pointer
        if subresult.is-valid:
          success-count++
          result.merge subresult
          if not context.needs-annotations and kind == ANY-OF:
            break
          if not context.needs-all-errors and kind == ONE-OF and success-count > 1:
            break
      if kind == ONE-OF:
        if success-count != 1:
          result.fail keyword "Expected exactly one subschema to match."
      else if kind == ANY-OF:
        if success-count == 0:
          result.fail keyword "Expected at least one subschema to match."
      else:
        unreachable
      return result

class Not extends Applicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    subresult := location["not", subschema].validate o
        --context=context
        --instance-pointer=instance-pointer
    if subresult.is-valid:
      result.fail "not" "Expected subschema to fail."
    return result

class IfThenElse extends Applicator:
  condition-subschema/Schema
  then-subschema/Schema?
  else-subschema/Schema?

  constructor .condition-subschema/Schema .then-subschema/Schema? .else-subschema/Schema?:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    condition-result := location["if", condition-subschema].validate o
        --context=context
        --instance-pointer=instance-pointer
    if condition-result.is-valid:
      result.merge condition-result
      if then-subschema:
        then-result := location["then", then-subschema].validate o
            --context=context
            --instance-pointer=instance-pointer
        if not then-result.is-valid:
          return then-result
        else:
          result.merge then-result
          return result
    else:
      if else-subschema:
        else-result := location["else", else-subschema].validate o
            --context=context
            --instance-pointer=instance-pointer
        if not else-result.is-valid:
          return else-result
        else:
          result.merge else-result
          return result
    return result

class DependentSchemas extends Applicator:
  subschemas/Map

  constructor .subschemas/Map:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not Map: return result
    map := o as Map
    dependent-location := location["dependentSchemas"]
    subschemas.do: | key/string subschema/Schema |
      map.get key --if-present=: | value/any |
        subresult := dependent-location[key, subschema].validate o
            --context=context
            --instance-pointer=instance-pointer
        result.merge subresult
        if not subresult.is-valid:
          result.fail "dependentSchemas" "Dependent schema '$key' failed."
          if not context.needs-all-errors:
            return result
    return result

class Properties extends Applicator:
  properties/Map?
  additional/Schema?
  patterns/Map?
  cached-regexs_/Map?

  constructor --.properties --.additional --.patterns:
    if patterns:
      cached := {:}
      patterns.do: | pattern/string _ |
        cached[pattern] = regex.parse pattern
      cached-regexs_ = cached
    else:
      cached-regexs_ = null


  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not Map: return result
    map := o as Map
    evaluated-properties := {}
    evaluated-matched-properties := {}
    evaluated-additional-properties := {}

    properties-location := location["properties"]
    patterns-location := location["patternProperties"]

    failed-properties := []
    failed-patterns := []
    failed-additional := []
    map.do: | key/string value/any |
      sub-pointer := instance-pointer[key]
      is-additional := true
      if properties and properties.contains key:
        evaluated-properties.add key
        is-additional = false
        subschema/Schema := properties[key]
        sub-is-valid := ?
        if subschema.json-value == false:
          sub-is-valid = false
        else:
          subresult := properties-location[key, properties[key]].validate value
              --context=context
              --instance-pointer=sub-pointer
          result.merge subresult
          sub-is-valid = subresult.is-valid
        if not sub-is-valid:
          failed-properties.add key
          if not context.needs-all-errors:
            result.fail "properties" "Property '$key' failed." --instance-pointer=sub-pointer
            return result

      if patterns:
        patterns.do: | pattern/string schema/Schema |
          regex := cached-regexs_[pattern]
          if regex.match key:
            evaluated-matched-properties.add key
            is-additional = false
            sub-is-valid := ?
            if schema.json-value == false:
              sub-is-valid = false
            else:
              subresult := patterns-location[pattern, schema].validate value
                  --context=context
                  --instance-pointer=sub-pointer
              result.merge subresult
              sub-is-valid = subresult.is-valid
            if not sub-is-valid:
              failed-patterns.add key
              if not context.needs-all-errors:
                result.fail "patternProperties"
                    "Pattern for '$key' failed."
                    --instance-pointer=sub-pointer
                return result

      if is-additional and additional:
        evaluated-additional-properties.add key
        sub-is-valid := ?
        if additional.json-value == false:
          sub-is-valid = false
        else:
          subresult := location["additionalProperties", additional].validate value
              --context=context
              --instance-pointer=sub-pointer
          result.merge subresult
          sub-is-valid = subresult.is-valid
        if not sub-is-valid:
          failed-additional.add key
          if not context.needs-all-errors:
            result.fail "additionalProperties"
                "Additional for '$key' failed."
                --instance-pointer=sub-pointer
            return result

    if context.needs-annotations:
      if not evaluated-properties.is-empty:
        result.annotate "properties" evaluated-properties
      if not evaluated-matched-properties.is-empty:
        result.annotate "patternProperties" evaluated-matched-properties
      if not evaluated-additional-properties.is-empty:
        result.annotate "additionalProperties" evaluated-additional-properties

    if not failed-properties.is-empty:
      result.fail "properties" failed-properties
    if not failed-patterns.is-empty:
      result.fail "patternProperties" failed-patterns
    if not failed-additional.is-empty:
      result.fail "additionalProperties" failed-additional
    return result

class PropertyNames extends Applicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not Map: return result
    map := o as Map
    sublocation := location["propertyNames", subschema]
    map.do: | key/string _ |
      subresult := sublocation.validate key
          --context=context
          // I don't think there is a way to point to the key of a property with a json pointer.
          --instance-pointer=instance-pointer
      if not subresult.is-valid:
        result.fail "propertyNames" "Property name '$key' failed."
        return result
      result.merge subresult
    return result

class Contains extends Applicator:
  subschema/Schema
  min-contains/int?
  max-contains/int?

  constructor .subschema/Schema --.min-contains --.max-contains:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not List: return result
    list := o as List
    success-count := 0
    contained-indexes := []
    sublocation := location["contains", subschema]
    for i := 0; i < list.size; i++:
      item := list[i]
      subresult := sublocation.validate item
          --context=context
          --instance-pointer=instance-pointer[i]
      if subresult.is-valid:
        contained-indexes.add i
        success-count++
        result.merge subresult
    if min-contains:
      if success-count < min-contains:
        result.fail "minContains" "Expected at least $min-contains items to match."
        return result
    else if success-count == 0:
      result.fail "contains" "Expected at least one item to match."
      return result
    if max-contains and success-count > max-contains:
      result.fail "maxContains" "Expected at most $max-contains items to match."
      return result
    annotation-value := contained-indexes == list.size ? true : contained-indexes
    if context.needs-annotations:
      result.annotate "contains" annotation-value
    return result

class Type extends SimpleAssertion:
  types/List

  constructor .types/List:

  validate o/any [fail] -> none:
    types.do: | type-string |
      if type-string == "null" and o == null: return
      if type-string == "boolean" and o is bool: return
      if type-string == "object" and o is Map: return
      if type-string == "array" and o is List: return
      if type-string == "number" and o is num: return
      if type-string == "string" and o is string: return
      if type-string == "integer":
        if o is int: return
        // TODO(florian): This is not correct: to-int could throw.
        if o is float and (o as float).to-int == o: return
    fail.call "type" "Value type not one of $types"

structural-equals_ a/any b/any -> bool:
  if a is num and a == b: return true
  if a is bool and a == b: return true
  if a is string and a == b: return true
  if a == null and b == null: return true

  if a is Map and b is Map:
    a-map := a as Map
    b-map := b as Map
    if a-map.size != b-map.size: return false
    a-map.do: | key/string a-value/any |
      b-value := b-map.get key
      if not structural-equals_ a-value b-value: return false
    return true

  if a is List and b is List:
    a-list := a as List
    b-list := b as List
    if a-list.size != b-list.size: return false
    for i := 0; i < a.size; i++:
      a-value := a-list[i]
      b-value := b-list[i]
      if not structural-equals_ a-value b-value: return false
    return true

  return false

class Enum extends SimpleAssertion:
  values/List

  constructor .values/List:

  validate o/any [fail] -> none:
    values.do: | value |
      if structural-equals_ o value: return
    fail.call "enum" "Value not one of $values"

class Const extends SimpleAssertion:
  value/any

  constructor .value/any:

  validate o/any [fail] -> none:
    if not structural-equals_ o value:
      fail.call "const" "Value not equal to $value"

class NumComparison extends SimpleNumAssertion:
  static MULTIPLE-OF ::= 0
  static MAXIMUM ::= 1
  static EXCLUSIVE-MAXIMUM ::= 2
  static MINIMUM ::= 3
  static EXCLUSIVE-MINIMUM ::= 4

  kind/int
  n/num

  constructor .n/num --.kind:

  validate o/num [fail] -> none:
    if kind == MULTIPLE-OF:
      if o % n != 0.0:
        fail.call "multipleOf" "Value $o not a multiple of $n"
    else if kind == MAXIMUM:
      if o > n:
        fail.call "maximum" "Value $o greater than $n"
    else if kind == EXCLUSIVE-MAXIMUM:
      if o >= n:
        fail.call "exclusiveMaximum" "Value $o greater than or equal to $n"
    else if kind == MINIMUM:
      if o < n:
        fail.call "minimum" "Value $o less than $n"
    else if kind == EXCLUSIVE-MINIMUM:
      if o <= n:
        fail.call "exclusiveMinimum" "Value $o less than or equal to $n"

class StringLength extends SimpleStringAssertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate str/string [fail] -> none:
    rune-size := str.size --runes
    if min and rune-size < min:
      fail.call "minLength" "String length $rune-size less than $min"
    if max and rune-size > max:
      fail.call "maxLength" "String length $rune-size greater than $max"

class ArrayLength extends SimpleListAssertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/List [fail] -> none:
    if min and o.size < min:
      fail.call "minItems" "Array length $o.size less than $min"
    if max and o.size > max:
      fail.call "maxItems" "Array length $o.size greater than $max"

class UniqueItems extends SimpleListAssertion:
  constructor:

  validate list/List [fail] -> none:
    // For simplicity do an O(n^2) algorithm.
    for i := 0; i < list.size; i++:
      for j := i + 1; j < list.size; j++:
        if structural-equals_ list[i] list[j]:
          fail.call "uniqueItems" "Array contains duplicate items."
          return

class Required extends SimpleObjectAssertion:
  properties/List

  constructor .properties/List:

  validate map/Map [fail] -> none:
    missing := []
    properties.do: | property |
      if not map.contains property:
        missing.add property
    if missing.size == 1:
      fail.call "required" "Required property '$missing.first' missing."
    else if missing.size > 1:
      fail.call "required" "Required properties $((missing.map: "'$it'").join ", ") missing."

class ObjectSize extends SimpleObjectAssertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate map/Map [fail] -> none:
    if min and map.size < min:
      fail.call "minProperties" "Object size $map.size less than $min"
    if max and map.size > max:
      fail.call "maxProperties" "Object size $map.size greater than $max"

class Items extends Applicator:
  prefix-items/List?
  items/Schema?

  constructor --.prefix-items --.items:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if o is not List: return result
    list := o as List
    items-location/InstantiatedSchema? := items ? location["items", items] : null
    prefix-location := location["prefixItems"]
    failed-items := []
    failed-prefix-items := []
    for i := 0; i < list.size; i++:
      sub-pointer := instance-pointer[i]
      if prefix-items and i < prefix-items.size:
        prefix-schema/Schema := prefix-items[i]
        subresult := prefix-location["$i", prefix-items[i]].validate list[i]
            --context=context
            --instance-pointer=sub-pointer
        result.merge subresult
        if not subresult.is-valid:
          failed-prefix-items.add i
          if not context.needs-all-errors:
            result.fail "prefixItems" "Prefix item $i failed." --instance-pointer=sub-pointer
            return result
      else if items:
        sub-is-valid := ?
        if items.json-value == false:
          sub-is-valid = false
        else:
          subresult := items-location["$i", items].validate list[i]
              --context=context
              --instance-pointer=sub-pointer
          result.merge subresult
          sub-is-valid = subresult.is-valid
        if not sub-is-valid:
          failed-items.add i
          if not context.needs-all-errors:
            result.fail "items" "Item $i failed." --instance-pointer=sub-pointer
            return result

    if not failed-prefix-items.is-empty:
      result.fail "prefixItems" failed-prefix-items
    if not failed-items.is-empty:
      result.fail "items" failed-items
    if context.needs-annotations:
      if prefix-items:
        annotation-value := prefix-items.size < list.size ? prefix-items.size : true
        result.annotate "prefixItems" annotation-value
      if items:
        result.annotate "items" true
    return result

class Pattern extends SimpleStringAssertion:
  pattern/string
  regex_/regex.Regex

  constructor .pattern:
    regex_ = regex.parse pattern

  validate str/string [fail] -> none:
    if not regex_.match str:
      fail.call "pattern" "String '$str' does not match pattern '$pattern'"

class DependentRequired extends SimpleObjectAssertion:
  properties/Map

  constructor .properties/Map:

  validate map/Map [fail] -> none:
    missing := []
    properties.do: | key/string required/List |
      if map.contains key:
        required.do: | property |
          if not map.contains property:
            missing.add property

    if missing.size == 1:
      fail.call "dependentRequired" "Required property '$missing.first' missing."
    else if missing.size > 1:
      fail.call "dependentRequired" "Required properties $((missing.map: "'$it'").join ", ") missing."

class UnevaluatedProperties extends AnnotationsApplicator:
  static EVALUATED-ANNOTATION-KEYS_ ::= [
    "properties",
    "patternProperties",
    "additionalProperties",
    "unevaluatedProperties",
  ]
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    unreachable

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
      --annotations/Map?
  :
    result := SubResult location instance-pointer
    if o is not Map: return result

    evaluated := {}
    if annotations:
      object-annotations := annotations.get instance-pointer.to-string
      if object-annotations:
        object-annotations.do: | annotation/Detail |
          if annotation.is-error: continue.do
          if EVALUATED-ANNOTATION-KEYS_.contains annotation.keyword:
            evaluated.add-all annotation.value

    new-evaluated := {}
    map := o as Map
    unevaluated-location := location["unevaluatedProperties", subschema]
    failed-unevaluated := []
    map.do: | key/string value/any |
      if not evaluated.contains key:
        new-evaluated.add key
        sub-pointer := instance-pointer[key]
        sub-is-valid := ?
        if subschema.json-value == false:
          sub-is-valid = false
        else:
          subresult := unevaluated-location.validate value
              --context=context
              --instance-pointer=sub-pointer
          result.merge subresult
          sub-is-valid = subresult.is-valid
        if not sub-is-valid:
          failed-unevaluated.add key
          if not context.needs-all-errors:
            result.fail "unevaluatedProperties"
                "Unevaluated property '$key' failed."
                --instance-pointer=sub-pointer
            return result
    if context.needs-annotations:
      result.annotate "unevaluatedProperties" new-evaluated
    if not failed-unevaluated.is-empty:
      result.fail "unevaluatedProperties" failed-unevaluated
    return result

class UnevaluatedItems extends AnnotationsApplicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    unreachable

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
      --annotations/Map?
  :
    result := SubResult location instance-pointer
    if o is not List: return result
    list := o as List
    first-unevaluated := 0
    evaluated-with-contains := {}
    if annotations:
      list-annotations/List? := annotations.get instance-pointer.to-string
      if list-annotations:
        list-annotations.do: | annotation/Detail |
          if annotation.is-error: continue.do
          if annotation.keyword == "items" or annotation.keyword == "unevaluatedItems":
            // Means that all items have been evaluated.
            return result
          if annotation.keyword == "contains":
            value := annotation.value
            if value == true:
              // Was applied to all items.
              return result
            assert: value is List
            evaluated-with-contains.add-all (value as List)
          if annotation.keyword == "prefixItems":
            value := annotation.value
            if value == true:
              // Was applied to all items.
              return result
            assert: value is int
            prefix-count := value as int
            if prefix-count >= list.size:
              // Was applied to all items.
              return result
            first-unevaluated = prefix-count
          else if annotation.keyword == "contains":

    sublocation := location["unevaluatedItems", subschema]
    needs-annotation := false
    failed-unevaluated := []
    for i := first-unevaluated; i < list.size; i++:
      if evaluated-with-contains.contains i:
        continue
      needs-annotation = true
      item := list[i]
      sub-pointer := instance-pointer[i]
      sub-is-valid := ?
      if subschema.json-value == false:
        sub-is-valid = false
      else:
        subresult := sublocation.validate item
            --context=context
            --instance-pointer=sub-pointer
        result.merge subresult
        sub-is-valid = subresult.is-valid
      if not sub-is-valid:
        failed-unevaluated.add i
        if not context.needs-all-errors:
          result.fail "unevaluatedItems"
              "Unevaluated item at position '$i' failed."
              --instance-pointer=sub-pointer
          return result
    if not failed-unevaluated.is-empty:
      result.fail "unevaluatedItems" failed-unevaluated
    if needs-annotation:
      result.annotate "unevaluatedItems" true
    return result

class Annotation extends Assertion:
  keyword/string
  value/any

  constructor .keyword .value:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result_ := SubResult location instance-pointer
    if context.needs-annotations:
      result_.annotate keyword value
    return result_

class Format extends Assertion:
  format/string

  constructor .format/string:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
  :
    result := SubResult location instance-pointer
    if context.needs-annotations:
      result.annotate "format" format
    // TODO(florian): Implement validation and give a way for users to add their own formats.
    return result

class Discriminator extends Applicator:
  property/string
  mapping/Map?  // From string to UriReference.
  resolved-mapping/Map? := null  // From string to Schema.
  kind/int := -1  // An X-Of kind.
  all-of-hierarchy-parents/Map? := null

  constructor .property .mapping:

  validate o/any -> SubResult
      --context/ValidationContext
      --location/InstantiatedSchema
      --instance-pointer/JsonPointer
      --required-hierarchy-schema/Schema? = null
  :
    result := SubResult location instance-pointer
    if o is not Map: return result

    if kind == X-Of.ALL-OF and not required-hierarchy-schema:
      // All-of discriminators are called as part of the validate in
      // Schemas, where the schema is set.
      // Otherwise, we skip them.
      return result

    map := o as Map
    discriminator-value := map.get property
    if discriminator-value is not string:
      result.fail "discriminator" "Discriminator property '$property' not a string."
      return result

    target-schema/Schema? := resolved-mapping.get discriminator-value
    if not target-schema:
      result.fail "discriminator" "Discriminator value '$discriminator-value' not in mapping."
      return result

    subresult := location["discriminator", target-schema].validate o
        --context=context
        --instance-pointer=instance-pointer
    result.merge subresult

    if required-hierarchy-schema:
      required-url := required-hierarchy-schema.absolute-location
      // Check that the required-hierarchy-schema is a parent of the target-schema.
      current/UriReference? := target-schema.absolute-location
      while current != required-url:
        current = (all-of-hierarchy-parents.get current)
        if not current:
          result.fail "discriminator" "Discriminator value '$discriminator-value' not expected class"
          return result

    if kind == X-Of.ONE-OF and not subresult.is-valid:
      result.fail "discrimator" "Discriminator with 'oneOf' kind failed."
      return result
    return result
