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
        sub-pointer := json-pointer + "\$defs" + key
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
      sub-pointer := json-pointer + "$i"
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ sub-schema-json --parent=parent --context=context --json-pointer=sub-pointer
    return result

  map-schemas_ --object/Map --parent/SchemaObject_? --context/BuildContext --json-pointer/JsonPointer -> Map:
    return object.map: | key/string sub-schema-json/any |
      sub-pointer := json-pointer + key
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ sub-schema-json --parent=parent --context=context --json-pointer=sub-pointer

  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value

    ["allOf", "anyOf", "oneOf"].do: | keyword/string |
      json.get keyword --if-present=: | entries/List |
        subschemas := map-schemas_
            --list=entries
            --parent=schema
            --context=context
            --json-pointer=json-pointer + keyword
        kind/int := ?
        if keyword == "allOf": kind = X-Of.ALL-OF
        else if keyword == "anyOf": kind = X-Of.ANY-OF
        else if keyword == "oneOf": kind = X-Of.ONE-OF
        else: throw "unreachable"
        schema.add-applicator (X-Of --kind=kind subschemas)

    json.get "not" --if-present=: | not-entry/any |
      sub-pointer := json-pointer + "not"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ not-entry --parent=schema --context=context --json-pointer=sub-pointer
      schema.add-applicator (Not subschema)

    condition-subschema/Schema? := json.get "if" --if-present=: | if-entry/any |
      condition-sub-pointer := json-pointer + "if"
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ if-entry --parent=schema --context=context --json-pointer=condition-sub-pointer

    // We build the then subschema even if there is no 'if', in case
    // the subschema is referenced.
    then-subschema/Schema? := json.get "then" --if-present=: | then-entry/any |
      then-sub-pointer := json-pointer + "then"
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ then-entry --parent=schema --context=context --json-pointer=then-sub-pointer

    // We build the 'else' subschema even if there is no 'if', in case
    // the subschema is referenced.
    else-subschema/Schema? := json.get "else" --if-present=: | else-entry/any |
      else-sub-pointer := json-pointer + "else"
      // Building the schema will automatically add its json-pointer to the store.
      Schema.build_ else-entry --parent=schema --context=context --json-pointer=else-sub-pointer

    if condition-subschema:
      schema.add-applicator (IfThenElse condition-subschema then-subschema else-subschema)

    json.get "dependentSchemas" --if-present=: | dependent-schemas/Map |
      sub-pointer := json-pointer + "dependentSchemas"
      subschemas := map-schemas_
          --object=dependent-schemas
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
      schema.add-applicator (DependentSchemas subschemas)

    prefix-items := json.get "prefixItems" --if-present=: | prefix-items/List |
      sub-pointer := json-pointer + "prefixItems"
      subschemas := map-schemas_
          --list=prefix-items
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    items := json.get "items" --if-present=: | items/any |
      sub-pointer := json-pointer + "items"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ items
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    if prefix-items or items:
      schema.add-applicator (Items --prefix-items=prefix-items --items=items)

    json.get "contains" --if-present=: | contains/any |
      sub-pointer := json-pointer + "contains"
      supports-min-max := schema.schema-resource.vocabularies.contains VocabularyValidation.URI
      min-contains := supports-min-max ? int-value_ (json.get "minContains") : null
      max-contains := supports-min-max ? int-value_ (json.get "maxContains") : null

      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ contains
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
      schema.add-applicator (Contains subschema --min-contains=min-contains --max-contains=max-contains)

    properties := json.get "properties" --if-present=: | properties/Map |
      sub-pointer := json-pointer + "properties"
      subschemas := map-schemas_
          --object=properties
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    additional-properties := json.get "additionalProperties" --if-present=: | additional-properties/any |
      sub-pointer := json-pointer + "additionalProperties"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ additional-properties
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    pattern-properties := json.get "patternProperties" --if-present=: | pattern-properties/Map |
      sub-pointer := json-pointer + "patternProperties"
      subschemas := map-schemas_
          --object=pattern-properties
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    if properties or additional-properties or pattern-properties:
      applicator := Properties
          --properties=properties
          --patterns=pattern-properties
          --additional=additional-properties
      schema.add-applicator applicator

    json.get "propertyNames" --if-present=: | property-names/any |
      sub-pointer := json-pointer + "propertyNames"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ property-names
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
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
      sub-pointer := json-pointer + "unevaluatedItems"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ unevaluated-items
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
      schema.add-applicator (UnevaluatedItems subschema)

    json.get "unevaluatedProperties" --if-present=: | unevaluated-properties/any |
      sub-pointer := json-pointer + "unevaluatedProperties"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ unevaluated-properties
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
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

  evaluated-properties/Set? := null
  evaluated-items/Set? := null
  all-items-evaluated/bool := false

  mark-evaluated-property key/string:
    if not evaluated-properties: evaluated-properties = Set
    evaluated-properties.add key

  mark-evaluated-item index/int:
    if all-items-evaluated: return
    if not evaluated-items: evaluated-items = Set
    evaluated-items.add index

  mark-all-items-evaluated:
    all-items-evaluated = true
    evaluated-items = null

  merge other/Result_ -> Result_:
    TODO(florian): this doesn't work: we can't just merge stuff all over the place. When we
    enter/leave an object/array we must not propagate more.
    For example { "o": { "b": 4}} should not have "b" as evaluated property of the outer map.
    assert: is-valid and other.is-valid
    result := Result_
    if evaluated-properties or other.evaluated-properties:
      result.evaluated-properties = Set
      result.evaluated-properties.add-all evaluated-properties
      result.evaluated-properties.add-all other.evaluated-properties
    if all-items-evaluated or other.all-items-evaluated:
      result.all-items-evaluated = true
      result.evaluated-items = null
    else if evaluated-items or other.evaluated-items:
      result.evaluated-items = Set
      result.evaluated-items.add-all evaluated-items
      result.evaluated-items.add-all other.evaluated-items
    return result

  fail message/string:
    evaluated-properties = null
    evaluated-items = null
    all-items-evaluated = false
    is-valid = false

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
          schema := Schema.build_ resource-json --context=context --json-pointer=JsonPointer --parent=null
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
    result := schema_.validate_ o --store=store_ --dynamic-scope=[]
    return result.is-valid

abstract class Schema:
  json-value/any
  schema-resource/SchemaResource_? := ?

  constructor.from-sub_ .json-value --.schema-resource:

  static build_ o/any --parent/SchemaObject_? --context/BuildContext --json-pointer/JsonPointer -> Schema:
    result/Schema := ?
    if o is bool:
      result = SchemaBool_ o --schema-resource=parent.schema-resource
    else:
      schema-object/SchemaObject_ := ?
      new-id := o.get "\$id"
      if not new-id and parent:
        schema-object = SchemaObject_ o --schema-resource=parent.schema-resource
      else:
        schema-resource := SchemaResource_ o --parent=parent
        // Also add the schema without the '#' fragment.
        context.store.add schema-resource.uri.to-string schema-resource
        // Reset the json-pointer.
        json-pointer = JsonPointer
        schema-object = schema-resource

      schema-object.schema-resource.vocabularies.do: | _ vocabulary/Vocabulary |
        vocabulary.add-actions --schema=schema-object --context=context --json-pointer=json-pointer

      result = schema-object

    escaped-json-pointer := json-pointer.to-fragment-string
    escaped-json-pointer = UriReference.normalize-fragment escaped-json-pointer
    schema-json-pointer-url := result.schema-resource.uri.with-fragment escaped-json-pointer
    context.store.add schema-json-pointer-url.to-string result
    return result

  abstract validate_ o/any --store/Store --dynamic-scope/List -> Result_


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

  validate_ o/any --store/Store --dynamic-scope/List -> Result_:
    if not is-sorted_:
      actions.sort --in-place: | a/Action b/Action | a.order.compare-to b.order
      is-sorted_ = true

    result := Result_
    with-updated-dynamic-scope_ dynamic-scope: | updated-scope/List |
      actions.do: | action/Action |
        action-result/Result_ := ?
        if action is UnevaluatedApplicator:
          unevaluated-action := action as UnevaluatedApplicator
          action-result = unevaluated-action.validate o
              --store=store
              --dynamic-scope=updated-scope
              --unevaluated-properties=result.evaluated-properties
              --unevaluated-items=result.evaluated-items
              --all-items-evaluated=result.all-items-evaluated
        else:
          action-result = action.validate o --store=store --dynamic-scope=updated-scope
        if not action-result.is-valid:
          return action-result
        result = result.merge action-result

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

/**
A schema resource is a schema with an "$id" property.

It defines which vocabulary is used.
It resets the json-pointer.
It sets the URL for all contained schemas that are relative to the resource.
*/
class SchemaResource_ extends SchemaObject_:
  uri/UriReference
  vocabularies/Map

  constructor o/Map --parent/SchemaObject_?:
    new-id := o.get "\$id"
    // This is a resource schema.
    // TODO(florian): get the "$schema".
    if not new-id:
      new-id = "urn:uuid:$(uuid.uuid5 "json-schema" "$Time.now.ns-since-epoch")"
    // Empty fragments are allowed (but not recommended).
    // Trim them.
    new-id = new-id.trim --right "#"
    new-uri := UriReference.parse new-id
    if not new-uri.is-absolute:
      new-uri = new-uri.resolve --base=parent.schema-resource.uri
    new-uri = new-uri.normalize
    this.uri = new-uri
    // Instantiate the schema object with a resource set to null and then update it to itself.
    vocabularies = DEFAULT-VOCABULARIES
    super o --schema-resource=null
    this.schema-resource = this

class SchemaBool_ extends Schema:
  constructor value/bool --schema-resource/SchemaResource_:
    super.from-sub_ value --schema-resource=schema-resource

  validate_ o/any --store/Store --dynamic-scope/List -> Result_:
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

  abstract validate o/any --dynamic-scope/List --store/Store -> Result_

abstract class Applicator extends Action:
  order -> int:
    return Action.ORDER-DEFAULT

abstract class UnevaluatedApplicator extends Applicator:
  order -> int:
    return Action.ORDER-LATE

  abstract validate o/any -> Result_
      --dynamic-scope/List
      --store/Store
      --unevaluated-properties/Set?
      --unevaluated-items/Set?
      --all-items-evaluated/bool?

abstract class Assertion extends Action:
  order -> int:
    return Action.ORDER-EARLY

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

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    resolved/Schema? := is-dynamic
        ? find-dynamic-schema_ --dynamic-scope=dynamic-scope --store=store
        : resolved_

    result := Result_
    if resolved == null:
      throw "Unresolved reference: $target-uri"

    return resolved.validate_ o --dynamic-scope=dynamic-scope --store=store

class X-Of extends Applicator:
  static ALL-OF ::= 0
  static ANY-OF ::= 1
  static ONE-OF ::= 2

  kind/int
  subschemas/List

  constructor --.kind .subschemas:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    if kind == ALL-OF:
      result := Result_
      subschemas.do: | subschema/Schema |
        sub-result := subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if not sub-result.is-valid:
          return sub-result
        result = result.merge sub-result
      return result
    else:
      success-count := 0
      result := Result_
      subschemas.do: | subschema/Schema |
        subresult := subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if subresult.is-valid:
          success-count++
          result = result.merge subresult
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

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    subresult := subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
    if subresult.is-valid:
      result.fail "Expected subschema to fail."
    return result

class IfThenElse extends Applicator:
  condition-subschema/Schema
  then-subschema/Schema?
  else-subschema/Schema?

  constructor .condition-subschema/Schema .then-subschema/Schema? .else-subschema/Schema?:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    condition-result := condition-subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
    if condition-result.is-valid:
      result = result.merge condition-result
      if then-subschema:
        then-result := then-subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if not then-result.is-valid:
          return then-result
        else:
          return result.merge then-result
    else:
      if else-subschema:
        else-result := else-subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if not else-result.is-valid:
          return else-result
        else:
          return result.merge else-result
    return result

class DependentSchemas extends Applicator:
  subschemas/Map

  constructor .subschemas/Map:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    subschemas.do: | key/string subschema/Schema |
      map.get key --if-present=: | value/any |
        subresult := subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Dependent schema '$key' failed."
          return result
        result = result.merge subresult
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


  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    map.do: | key/string value/any |
      is-additional := true
      if properties and properties.contains key:
        is-additional = false
        subresult := properties[key].validate_ value --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Property '$key' failed."
          return result
        result = result.merge subresult
      if patterns:
        patterns.do: | pattern/string schema/Schema |
          regex := cached-regexs_[pattern]
          if regex.match key:
            is-additional = false
            subresult := schema.validate_ value --dynamic-scope=dynamic-scope --store=store
            if not subresult.is-valid:
              result.fail "Pattern for '$key' failed."
              return result
            result = result.merge subresult

      if is-additional and additional:
        subresult := additional.validate_ value --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Additional for '$key' failed."
          return result
        result = result.merge subresult
    return result

class PropertyNames extends Applicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    map.do: | key/string _ |
      subresult := subschema.validate_ key --dynamic-scope=dynamic-scope --store=store
      if not subresult.is-valid:
        result.fail "Property name '$key' failed."
        return result
      result = result.merge subresult
    return result

class Contains extends Applicator:
  subschema/Schema
  min-contains/int?
  max-contains/int?

  constructor .subschema/Schema --.min-contains --.max-contains:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not List: return result
    list := o as List
    success-count := 0
    list.do: | item/any |
      subresult := subschema.validate_ item --dynamic-scope=dynamic-scope --store=store
      if subresult.is-valid:
        success-count++
        result = result.merge subresult
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
    return result

class Type extends Assertion:
  types/List

  constructor .types/List:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
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

class Enum extends Assertion:
  values/List

  constructor .values/List:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    values.do: | value |
      if structural-equals_ o value: return result
    result.fail "Value not one of $values"
    return result

class Const extends Assertion:
  value/any

  constructor .value/any:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if not structural-equals_ o value:
      result.fail "Value not equal to $value"
    return result

class NumComparison extends Assertion:
  static MULTIPLE-OF ::= 0
  static MAXIMUM ::= 1
  static EXCLUSIVE-MAXIMUM ::= 2
  static MINIMUM ::= 3
  static EXCLUSIVE-MINIMUM ::= 4

  kind/int
  n/num

  constructor .n/num --.kind:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not num: return result
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

class StringLength extends Assertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not string: return result
    str := o as string
    rune-size := str.size --runes
    if min and rune-size < min:
      result.fail "String length $rune-size less than $min"
      return result
    if max and rune-size > max:
      result.fail "String length $rune-size greater than $max"
      return result
    return result

class ArrayLength extends Assertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not List: return result
    if min and o.size < min:
      result.fail "Array length $o.size less than $min"
      return result
    if max and o.size > max:
      result.fail "Array length $o.size greater than $max"
      return result
    return result

class UniqueItems extends Assertion:
  constructor:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not List: return result
    list := o as List
    // For simplicity do an O(n^2) algorithm.
    for i := 0; i < list.size; i++:
      for j := i + 1; j < list.size; j++:
        if structural-equals_ list[i] list[j]:
          result.fail "Array contains duplicate items."
          return result
    return result

class Required extends Assertion:
  properties/List

  constructor .properties/List:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    properties.do: | property |
      if not map.contains property:
        result.fail "Required property '$property' missing."
        return result
    return result

class ObjectSize extends Assertion:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
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

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not List: return result
    list := o as List
    for i := 0; i < list.size; i++:
      if prefix-items and i < prefix-items.size:
        subresult := prefix-items[i].validate_ list[i] --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Prefix item $i failed."
          return result
        result = result.merge subresult
      else if items:
        subresult := items.validate_ list[i] --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Item $i failed."
          return result
        result = result.merge subresult
    return result

class Pattern extends Assertion:
  pattern/string
  regex_/regex.Regex

  constructor .pattern:
    regex_ = regex.parse pattern

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not string: return result
    str := o as string
    if not regex_.match str:
      result.fail "String '$str' does not match pattern '$pattern'"
    return result

class DependentRequired extends Assertion:
  properties/Map

  constructor .properties/Map:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    properties.do: | key/string required/List |
      if map.contains key:
        required.do: | property |
          if not map.contains property:
            result.fail "Depending required property '$property' missing."
            return result
    return result

class UnevaluatedProperties extends UnevaluatedApplicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    unreachable

  validate o/any --dynamic-scope/List --store/Store --unevaluated-properties/List? --unevaluated-items/List? --all-items-evaluated/bool? -> Result_:
    result := Result_
    if o is not Map: return result
    map := o as Map
    map.do: | key/string _ |
      if not unevaluated-properties or not unevaluated-properties.contains key:
        subresult := subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Unevaluated property '$key' failed."
          return result
        result = result.merge subresult
    return result

class UnevaluatedItems extends UnevaluatedApplicator:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store -> Result_:
    unreachable

  validate o/any --dynamic-scope/List --store/Store --unevaluated-properties/List? --unevaluated-items/List? --all-items-evaluated/bool? -> Result_:
    result := Result_
    if o is not List: return result
    if all-items-evaluated: return result
    list := o as List
    list.do: | item/any |
      if not unevaluated-items or not unevaluated-items.contains item:
        subresult := subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
        if not subresult.is-valid:
          result.fail "Unevaluated item '$item' failed."
          return result
        result = result.merge subresult
    return result
