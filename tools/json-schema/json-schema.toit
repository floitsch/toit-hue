/**
An implementation of the JSON Schema Specification Draft 2022-12.
https://json-schema.org/draft/2020-12/json-schema-core#name-the-vocabulary-keyword
*/

import certificate-roots
import http
import encoding.json
import net
import uuid
import .uri
import .json-pointer
import .regex as regex

class Dialect:
  vocabularies_/Map

  constructor --vocabularies/Map:
    vocabularies_ = vocabularies

interface Vocabulary:
  uri -> string
  keywords -> List
  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> bool

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

  static resolve-ref_ ref/string --schema-resource/SchemaResource_ -> UriReference:
    reference := (UriReference.parse ref).normalize
    return reference.resolve --base=schema-resource.uri

  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> none:
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
      target-uri := resolve-ref_ ref --schema-resource=schema.schema-resource
      applicator := Ref --target-uri=target-uri --is-dynamic=false
      context.refs.add applicator
      schema.add-applicator applicator

    json.get "\$dynamicRef" --if-present=: | ref/string |
      target-uri := resolve-ref_ ref --schema-resource=schema.schema-resource
      applicator := Ref --target-uri=target-uri --is-dynamic
      context.refs.add applicator
      schema.add-applicator applicator

    json.get "\$defs" --if-present=: | defs/Map |
      schema-defs := defs.map: | key/string value/any |
        sub-pointer := json-pointer["\$defs"][key]
        // Building the schema will automatically add its json-pointer to the store.
        Schema.build_ value --parent=schema --context=context --json-pointer=sub-pointer

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

  map-schemas_ --list/List --parent/SchemaObject_? --context/BuildContext --json-pointer/JsonPointer -> List:
    result := List list.size: | i/int |
      sub-schema-json/any := list[i]
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ sub-schema-json --parent=parent --context=context --json-pointer=json-pointer[i]
    return result

  map-schemas_ --object/Map --parent/SchemaObject_? --context/BuildContext --json-pointer/JsonPointer -> Map:
    return object.map: | key/string sub-schema-json/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ sub-schema-json --parent=parent --context=context --json-pointer=json-pointer[key]

  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> none:
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
      subschema := Schema.build_ not-entry --parent=schema --context=context --json-pointer=json-pointer["not"]
      schema.add-applicator (Not subschema)

    condition-subschema/Schema? := json.get "if" --if-present=: | if-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ if-entry --parent=schema --context=context --json-pointer=json-pointer["if"]

    // We build the then subschema even if there is no 'if', in case
    // the subschema is referenced.
    then-subschema/Schema? := json.get "then" --if-present=: | then-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ then-entry --parent=schema --context=context --json-pointer=json-pointer["then"]

    // We build the 'else' subschema even if there is no 'if', in case
    // the subschema is referenced.
    else-subschema/Schema? := json.get "else" --if-present=: | else-entry/any |
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ else-entry --parent=schema --context=context --json-pointer=json-pointer["else"]

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
      subschema := Schema.build_ items
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
      subschema := Schema.build_ contains
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
      subschema := Schema.build_ additional-properties
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
      subschema := Schema.build_ property-names
          --parent=schema
          --context=context
          --json-pointer=json-pointer["propertyNames"]
      schema.add-applicator (PropertyNames subschema)


class VocabularyUnevaluated implements Vocabulary:
  static URI ::= "https://json-schema.org/draft/2020-12/meta/unevaluated"

  static KEYWORDS ::= [
    "unevaluatedItems",
    "unevaluatedProperties",
  ]

  uri -> string:
    return URI

  keywords -> List:
    return KEYWORDS

  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    json.get "unevaluatedItems" --if-present=: | unevaluated-items/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ unevaluated-items
          --parent=schema
          --context=context
          --json-pointer=json-pointer["unevaluatedItems"]
      schema.add-applicator (UnevaluatedItems subschema)

    json.get "unevaluatedProperties" --if-present=: | unevaluated-properties/any |
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ unevaluated-properties
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

  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    json.get "type" --if-present=: | type/any |
      if type is string: type = [type]
      schema.add-assertion (Type type)

    json.get "enum" --if-present=: | enum-values/any |
      schema.add-assertion (Enum enum-values)

    json.get "const" --if-present=: | value/any |
      schema.add-assertion (Const value)

    ["multipleOf", "maximum", "exclusiveMaximum", "minimum", "exclusiveMinimum"].do: | keyword/string |
      json.get keyword --if-present=: | n/num |
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

DEFAULT-VOCABULARIES ::= {
  VocabularyCore.URI: VocabularyCore,
  VocabularyApplicator.URI: VocabularyApplicator,
  VocabularyValidation.URI: VocabularyValidation,
  VocabularyUnevaluated.URI: VocabularyUnevaluated,
}

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

class Result_:
  is-valid/bool := true
  annotations/Map? := null

  /**
  Merges the $other result into this one.
  Reuses the $other result's fields if possible. This means that the $other result
    can not be used after this method is called.
  */
  merge other/Result_ -> none:
    assert: is-valid and other.is-valid
    result := Result_
    if not other.annotations:
      return
    if not annotations:
      annotations = other.annotations
      return
    other.annotations.do: | key/string other-entries/List |
      this-entry := annotations.get key
      if not this-entry:
        annotations[key] = other-entries
      else:
        this-entry.add-all other-entries

  fail message/string:
    annotations = null
    is-valid = false

  annotate json-pointer/JsonPointer key/string value/any:
    if not annotations:
      annotations = {:}
    annotation-key := json-pointer.to-string
    entries := annotations.get annotation-key --init=:[]
    entries.add (Annotation key value)

class Annotation:
  key/string
  value/any

  constructor .key .value:

build o/any --resource-loader/ResourceLoader=HttpResourceLoader -> JsonSchema:
  store := Store
  context := BuildContext --store=store
  root-schema := Schema.build_ o --context=context --json-pointer=JsonPointer --parent=null

  // Resolve all references.
  while not context.refs.is-empty:
    pending := context.refs
    context.refs = []
    pending.do: | ref/Ref |
      target-uri := ref.target-uri
      target := target-uri.to-string
      resolved := store.get target

      if not resolved:
        missing-resource-url := target-uri.with-fragment null
        missing-resource-url-string := missing-resource-url.to-string
        if not store.get missing-resource-url-string:
          resource-json := resource-loader.load missing-resource-url-string
          // Building the schema will automatically add its json-pointer to the store.
          schema := Schema.build_ resource-json
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

  return JsonSchema root-schema store

class JsonSchema:
  schema_/Schema
  store_/Store

  constructor .schema_ .store_:

  validate o/any -> bool:
    result := schema_.validate_ o --store=store_ --dynamic-scope=[] --json-pointer=JsonPointer
    return result.is-valid

/**
A schema resource identifies a group of schemas.

It defines which vocabulary is used.
It resets the json-pointer.
It sets the URL for all contained schemas that are relative to the resource.
*/
class SchemaResource_:
  uri/UriReference
  vocabularies/Map

  constructor id/string? --parent/SchemaObject_? --base-uri/UriReference?:
    // This is a resource schema.
    // TODO(florian): get the "$schema".
    if not id and base-uri:
      id = base-uri.to-string
    else if not id:
      id = "urn:uuid:$(uuid.uuid5 "json-schema" "$Time.now.ns-since-epoch")"
    // Empty fragments are allowed (but not recommended).
    // Trim them.
    id = id.trim --right "#"
    new-uri := UriReference.parse id
    if not new-uri.is-absolute:
      new-uri = new-uri.resolve --base=parent.schema-resource.uri
    new-uri = new-uri.normalize
    this.uri = new-uri
    // Instantiate the schema object with a resource set to null and then update it to itself.
    vocabularies = DEFAULT-VOCABULARIES

abstract class Schema:
  json-value/any
  schema-resource/SchemaResource_? := ?

  constructor.from-sub_ .json-value --.schema-resource:

  static build_ o/any -> Schema
      --parent/SchemaObject_?
      --context/BuildContext
      --json-pointer/JsonPointer
      --base-uri/UriReference? = null
  :
    schema-resource/SchemaResource_ := ?
    id := o is Map ? o.get "\$id" : null
    if id or not parent:
      schema-resource = SchemaResource_ id --parent=parent --base-uri=base-uri
      // Reset the json-pointer.
      json-pointer = JsonPointer
    else:
      schema-resource = parent.schema-resource

    result/Schema := ?
    if o is bool:
      result = SchemaBool_ o --schema-resource=schema-resource
    else:
      schema-object := SchemaObject_ o --schema-resource=schema-resource
      schema-object.schema-resource.vocabularies.do: | _ vocabulary/Vocabulary |
        vocabulary.add-actions --schema=schema-object --context=context --json-pointer=json-pointer

      result = schema-object

    escaped-json-pointer := json-pointer.to-fragment-string
    escaped-json-pointer = UriReference.normalize-fragment escaped-json-pointer
    schema-json-pointer-url := result.schema-resource.uri.with-fragment escaped-json-pointer
    context.store.add schema-json-pointer-url.to-string result
    if json-pointer.to-fragment-string == "":
      // Also add this schema without any fragment.
      context.store.add result.schema-resource.uri.to-string result
    return result

  abstract validate_ o/any --store/Store --dynamic-scope/List --json-pointer/JsonPointer -> Result_

class SchemaObject_ extends Schema:
  is-resolved/bool := false
  is-sorted_/bool := false

  constructor o/Map --schema-resource/SchemaResource_?:
    super.from-sub_ o --schema-resource=schema-resource

  actions/List ::= []

  add-applicator applicator/Applicator:
    actions.add applicator

  add-assertion assertion/Assertion:
    actions.add assertion

  validate_ o/any --store/Store --dynamic-scope/List --json-pointer/JsonPointer -> Result_:
    if not is-sorted_:
      actions.sort --in-place: | a/Action b/Action | a.order.compare-to b.order
      is-sorted_ = true

    result := Result_
    with-updated-dynamic-scope_ dynamic-scope: | updated-scope/List |
      actions.do: | action/Action |
        action-result/Result_ := ?
        if action is AnnotationsApplicator:
          annotations-action := action as AnnotationsApplicator
          action-result = annotations-action.validate o
              --store=store
              --dynamic-scope=updated-scope
              --annotations=result.annotations
              --json-pointer=json-pointer
        else:
          action-result = action.validate o
              --store=store
              --dynamic-scope=updated-scope
              --json-pointer=json-pointer
        if not action-result.is-valid:
          return action-result
        result.merge action-result

    return result

  with-updated-dynamic-scope_ dynamic-scope/List [block] -> none:
    if dynamic-scope.is-empty or dynamic-scope.last != schema-resource:
      try:
        dynamic-scope.add schema-resource
        block.call dynamic-scope
      finally:
        dynamic-scope.remove-last
    else:
      block.call dynamic-scope

class SchemaBool_ extends Schema:
  constructor value/bool --schema-resource/SchemaResource_:
    super.from-sub_ value --schema-resource=schema-resource

  validate_ o/any --store/Store --dynamic-scope/List --json-pointer/JsonPointer -> Result_:
    result := Result_
    if not json-value:
      result.fail "Value is false."
    return result

class BuildContext:
  store/Store
  refs/List := []  // Of ActionRef.

  constructor --.store:

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

  abstract validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_

abstract class Applicator extends Action:
  order -> int:
    return Action.ORDER-DEFAULT

abstract class AnnotationsApplicator extends Applicator:
  order -> int:
    return Action.ORDER-LATE

  abstract validate o/any -> Result_
      --dynamic-scope/List
      --store/Store
      --json-pointer/JsonPointer
      --annotations/Map?

abstract class Assertion extends Action:
  order -> int:
    return Action.ORDER-EARLY

abstract class SimpleAssertion extends Assertion:
  abstract validate o/any -> Result_

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    return validate o

abstract class SimpleStringAssertion extends Assertion:
  abstract validate str/string -> Result_

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    if o is not string:
      return Result_
    return validate o as string

abstract class SimpleNumAssertion extends Assertion:
  abstract validate n/num -> Result_

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    if o is not num:
      return Result_
    return validate o as num

abstract class SimpleObjectAssertion extends Assertion:
  abstract validate o/Map -> Result_

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    if o is not Map:
      return Result_
    return validate o as Map

abstract class SimpleListAssertion extends Assertion:
  abstract validate o/List -> Result_

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    if o is not List:
      return Result_
    return validate o as List

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

  find-dynamic-schema_ --dynamic-scope/List --store/Store -> Schema:
    dynamic-scope.do: | resource/SchemaResource_ |
      dynamic-target-uri := resource.uri.with-fragment dynamic-fragment
      dynamic-target := dynamic-target-uri.to-string
      dynamic-target-schema := store.get dynamic-target
      if not dynamic-target-schema:
        continue.do
      if not store.get-dynamic-fragment dynamic-target:
        // Wasn't actually a dynamic target.
        continue.do
      return dynamic-target-schema
    // We know that there is a dynamic anchor in the same resource.
    // Otherwise we would have changed the dynamic reference to a static one.
    throw "Dynamic reference withouth a dynamic target: $target-uri"

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    resolved/Schema? := is-dynamic
        ? find-dynamic-schema_ --dynamic-scope=dynamic-scope --store=store
        : resolved_

    result := Result_
    if resolved == null:
      throw "Unresolved reference: $target-uri"

    return resolved.validate_ o --dynamic-scope=dynamic-scope --store=store --json-pointer=json-pointer

class X-Of extends Applicator:
  static ALL-OF ::= 0
  static ANY-OF ::= 1
  static ONE-OF ::= 2

  kind/int
  subschemas/List

  constructor --.kind .subschemas:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    if kind == ALL-OF:
      result := Result_
      subschemas.do: | subschema/Schema |
        sub-result := subschema.validate_ o
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer
        if not sub-result.is-valid:
          return sub-result
        result.merge sub-result
      return result
    else:
      success-count := 0
      result := Result_
      subschemas.do: | subschema/Schema |
        subresult := subschema.validate_ o
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer
        if subresult.is-valid:
          success-count++
          result.merge subresult
      if kind == ONE-OF:
        if success-count != 1:
          result.fail "Expected exactly one subschema to match."
      else if kind == ANY-OF:
        if success-count == 0:
          result.fail "Expected at least one subschema to match."
      else:
        unreachable
      return result

class Not extends Applicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    subresult := subschema.validate_ o
        --dynamic-scope=dynamic-scope
        --store=store
        --json-pointer=json-pointer
    if subresult.is-valid:
      result.fail "Expected subschema to fail."
    return result

class IfThenElse extends Applicator:
  condition-subschema/Schema
  then-subschema/Schema?
  else-subschema/Schema?

  constructor .condition-subschema/Schema .then-subschema/Schema? .else-subschema/Schema?:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    condition-result := condition-subschema.validate_ o
        --dynamic-scope=dynamic-scope
        --store=store
        --json-pointer=json-pointer
    if condition-result.is-valid:
      result.merge condition-result
      if then-subschema:
        then-result := then-subschema.validate_ o
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer
        if not then-result.is-valid:
          return then-result
        else:
          result.merge then-result
          return result
    else:
      if else-subschema:
        else-result := else-subschema.validate_ o
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer
        if not else-result.is-valid:
          return else-result
        else:
          result.merge else-result
          return result
    return result

class DependentSchemas extends Applicator:
  subschemas/Map

  constructor .subschemas/Map:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    subschemas.do: | key/string subschema/Schema |
      map.get key --if-present=: | value/any |
        subresult := subschema.validate_ o
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer
        if not subresult.is-valid:
          result.fail "Dependent schema '$key' failed."
          return result
        result.merge subresult
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


  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    evaluated-properties := {}
    evaluated-matched-properties := {}
    evaluated-additional-properties := {}

    map.do: | key/string value/any |
      is-additional := true
      if properties and properties.contains key:
        evaluated-properties.add key
        is-additional = false
        key-pointer := json-pointer[key]
        subresult := properties[key].validate_ value
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=key-pointer
        if not subresult.is-valid:
          result.fail "Property '$key' failed."
          return result
        result.merge subresult

      if patterns:
        patterns.do: | pattern/string schema/Schema |
          regex := cached-regexs_[pattern]
          if regex.match key:
            evaluated-matched-properties.add key
            is-additional = false
            subresult := schema.validate_ value
                --dynamic-scope=dynamic-scope
                --store=store
                --json-pointer=json-pointer[key]
            if not subresult.is-valid:
              result.fail "Pattern for '$key' failed."
              return result
            result.merge subresult

      if is-additional and additional:
        evaluated-additional-properties.add key
        subresult := additional.validate_ value
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer[key]
        if not subresult.is-valid:
          result.fail "Additional for '$key' failed."
          return result
        result.merge subresult

    if not evaluated-properties.is-empty:
      result.annotate json-pointer "properties" evaluated-properties
    if not evaluated-matched-properties.is-empty:
      result.annotate json-pointer "patternProperties" evaluated-matched-properties
    if not evaluated-additional-properties.is-empty:
      result.annotate json-pointer "additionalProperties" evaluated-additional-properties
    return result

class PropertyNames extends Applicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    map.do: | key/string _ |
      subresult := subschema.validate_ key
          --dynamic-scope=dynamic-scope
          --store=store
          // I don't think there is a way to point to the key of a property with a json pointer.
          --json-pointer=json-pointer
      if not subresult.is-valid:
        result.fail "Property name '$key' failed."
        return result
      result.merge subresult
    return result

class Contains extends Applicator:
  subschema/Schema
  min-contains/int?
  max-contains/int?

  constructor .subschema/Schema --.min-contains --.max-contains:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    if o is not List: return result
    list := o as List
    success-count := 0
    contained-indexes := []
    for i := 0; i < list.size; i++:
      item := list[i]
      subresult := subschema.validate_ item
          --dynamic-scope=dynamic-scope
          --store=store
          --json-pointer=json-pointer[i]
      if subresult.is-valid:
        contained-indexes.add i
        success-count++
        result.merge subresult
    if min-contains:
      if success-count < min-contains:
        result.fail "Expected at least $min-contains items to match."
        return result
    else if success-count == 0:
      result.fail "Expected at least one item to match."
      return result
    if max-contains and success-count > max-contains:
      result.fail "Expected at most $max-contains items to match."
      return result
    annotation-value := contained-indexes == list.size ? true : contained-indexes
    result.annotate json-pointer "contains" annotation-value
    return result

class Type extends SimpleAssertion:
  types/List

  constructor .types/List:

  validate o/any -> Result_:
    result := Result_
    types.do: | type-string |
      if type-string == "null" and o == null: return result
      if type-string == "boolean" and o is bool: return result
      if type-string == "object" and o is Map: return result
      if type-string == "array" and o is List: return result
      if type-string == "number" and o is num: return result
      if type-string == "string" and o is string: return result
      if type-string == "integer":
        if o is int: return result
        // TODO(florian): This is not correct: to-int could throw.
        if o is float and (o as float).to-int == o: return result
    result.fail "Value type not one of $types"
    return result

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

  validate o/any -> Result_:
    result := Result_
    values.do: | value |
      if structural-equals_ o value: return result
    result.fail "Value not one of $values"
    return result

class Const extends SimpleAssertion:
  value/any

  constructor .value/any:

  validate o/any -> Result_:
    result := Result_
    if not structural-equals_ o value:
      result.fail "Value not equal to $value"
    return result

class NumComparison extends SimpleNumAssertion:
  static MULTIPLE-OF ::= 0
  static MAXIMUM ::= 1
  static EXCLUSIVE-MAXIMUM ::= 2
  static MINIMUM ::= 3
  static EXCLUSIVE-MINIMUM ::= 4

  kind/int
  n/num

  constructor .n/num --.kind:

  validate o/num -> Result_:
    result := Result_
    if kind == MULTIPLE-OF:
      if o % n != 0.0:
        result.fail "Value $o not a multiple of $n"
      return result
    if kind == MAXIMUM:
      if o > n:
        result.fail "Value $o greater than $n"
      return result
    if kind == EXCLUSIVE-MAXIMUM:
      if o >= n:
        result.fail "Value $o greater than or equal to $n"
      return result
    if kind == MINIMUM:
      if o < n:
        result.fail "Value $o less than $n"
      return result
    if kind == EXCLUSIVE-MINIMUM:
      if o <= n:
        result.fail "Value $o less than or equal to $n"
      return result
    throw "unreachable"

class StringLength extends SimpleStringAssertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate str/string -> Result_:
    result := Result_
    rune-size := str.size --runes
    if min and rune-size < min:
      result.fail "String length $rune-size less than $min"
      return result
    if max and rune-size > max:
      result.fail "String length $rune-size greater than $max"
      return result
    return result

class ArrayLength extends SimpleListAssertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/List -> Result_:
    result := Result_
    if min and o.size < min:
      result.fail "Array length $o.size less than $min"
      return result
    if max and o.size > max:
      result.fail "Array length $o.size greater than $max"
      return result
    return result

class UniqueItems extends SimpleListAssertion:
  constructor:

  validate list/List -> Result_:
    result := Result_
    // For simplicity do an O(n^2) algorithm.
    for i := 0; i < list.size; i++:
      for j := i + 1; j < list.size; j++:
        if structural-equals_ list[i] list[j]:
          result.fail "Array contains duplicate items."
          return result
    return result

class Required extends SimpleObjectAssertion:
  properties/List

  constructor .properties/List:

  validate map/Map -> Result_:
    result := Result_
    properties.do: | property |
      if not map.contains property:
        result.fail "Required property '$property' missing."
        return result
    return result

class ObjectSize extends SimpleObjectAssertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate map/Map -> Result_:
    result := Result_
    if min and map.size < min:
      result.fail "Object size $map.size less than $min"
      return result
    if max and map.size > max:
      result.fail "Object size $map.size greater than $max"
      return result
    return result

class Items extends Applicator:
  prefix-items/List?
  items/Schema?

  constructor --.prefix-items --.items:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    result := Result_
    if o is not List: return result
    list := o as List
    for i := 0; i < list.size; i++:
      if prefix-items and i < prefix-items.size:
        prefix-schema/Schema := prefix-items[i]
        subresult := prefix-schema.validate_ list[i]
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer[i]
        if not subresult.is-valid:
          result.fail "Prefix item $i failed."
          return result
        result.merge subresult
      else if items:
        subresult := items.validate_ list[i]
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer[i]
        if not subresult.is-valid:
          result.fail "Item $i failed."
          return result
        result.merge subresult
    if prefix-items:
      annotation-value := prefix-items.size < list.size ? prefix-items.size : true
      result.annotate json-pointer "prefixItems" annotation-value
    if items:
      result.annotate json-pointer "items" true
    return result

class Pattern extends SimpleStringAssertion:
  pattern/string
  regex_/regex.Regex

  constructor .pattern:
    regex_ = regex.parse pattern

  validate str/string -> Result_:
    result := Result_
    if not regex_.match str:
      result.fail "String '$str' does not match pattern '$pattern'"
    return result

class DependentRequired extends SimpleObjectAssertion:
  properties/Map

  constructor .properties/Map:

  validate map/Map -> Result_:
    result := Result_
    properties.do: | key/string required/List |
      if map.contains key:
        required.do: | property |
          if not map.contains property:
            result.fail "Depending required property '$property' missing."
            return result
    return result

class UnevaluatedProperties extends AnnotationsApplicator:
  static EVALUATED-ANNOTATION-KEYS_ ::= [
    "properties",
    "patternProperties",
    "additionalProperties",
    "unevaluatedProperties",
  ]
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    unreachable

  validate o/any -> Result_
      --dynamic-scope/List
      --store/Store
      --json-pointer/JsonPointer
      --annotations/Map?
  :
    result := Result_
    if o is not Map: return result

    evaluated := {}
    if annotations:
      object-annotations := annotations.get json-pointer.to-string
      if object-annotations:
        object-annotations.do: | annotation/Annotation |
          if EVALUATED-ANNOTATION-KEYS_.contains annotation.key:
            evaluated.add-all annotation.value

    new-evaluated := {}
    map := o as Map
    map.do: | key/string value/any |
      if not evaluated.contains key:
        new-evaluated.add key
        subresult := subschema.validate_ value
            --dynamic-scope=dynamic-scope
            --store=store
            --json-pointer=json-pointer[key]
        if not subresult.is-valid:
          result.fail "Unevaluated property '$key' failed."
          return result
        result.merge subresult
    result.annotate json-pointer "unevaluatedProperties" new-evaluated
    return result

class UnevaluatedItems extends AnnotationsApplicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store --json-pointer/JsonPointer -> Result_:
    unreachable

  validate o/any -> Result_
      --dynamic-scope/List
      --store/Store
      --annotations/Map?
      --json-pointer/JsonPointer
  :
    result := Result_
    if o is not List: return result
    list := o as List
    first-unevaluated := 0
    evaluated-with-contains := {}
    if annotations:
      list-annotations/List? := annotations.get json-pointer.to-string
      if list-annotations:
        list-annotations.do: | annotation/Annotation |
          if annotation.key == "items" or annotation.key == "unevaluatedItems":
            // Means that all items have been evaluated.
            return result
          if annotation.key == "contains":
            value := annotation.value
            if value == true:
              // Was applied to all items.
              return result
            assert: value is List
            evaluated-with-contains.add-all (value as List)
          if annotation.key == "prefixItems":
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
          else if annotation.key == "contains":

    needs-annotation := false
    for i := first-unevaluated; i < list.size; i++:
      if evaluated-with-contains.contains i:
        continue
      needs-annotation = true
      item := list[i]
      subresult := subschema.validate_ item
          --dynamic-scope=dynamic-scope
          --store=store
          --json-pointer=json-pointer[i]
      if not subresult.is-valid:
        result.fail "Unevaluated item at position '$i' failed."
        return result
      result.merge subresult
    if needs-annotation:
      result.annotate json-pointer "unevaluatedItems" true
    return result
