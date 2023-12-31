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
      action := ActionRef --target-uri=target-uri --is-dynamic=false
      context.refs.add action
      schema.add_ "\$ref" action

    json.get "\$dynamicRef" --if-present=: | ref/string |
      target-uri := resolve-ref_ ref --schema-resource=schema.schema-resource
      action := ActionRef --target-uri=target-uri --is-dynamic
      context.refs.add action
      schema.add_ "\$ref" action

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
        if keyword == "allOf": kind = ActionMulti.ALL-OF
        else if keyword == "anyOf": kind = ActionMulti.ANY-OF
        else if keyword == "oneOf": kind = ActionMulti.ONE-OF
        else: throw "unreachable"
        schema.add_ keyword (ActionMulti --kind=kind subschemas)

    json.get "not" --if-present=: | not-entry/any |
      sub-pointer := json-pointer + "not"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ not-entry --parent=schema --context=context --json-pointer=sub-pointer
      schema.add_ "not" (ActionNot subschema)

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
      schema.add_ "if" (ActionIfThenElse condition-subschema then-subschema else-subschema)

    json.get "dependentSchemas" --if-present=: | dependent-schemas/Map |
      sub-pointer := json-pointer + "dependentSchemas"
      subschemas := map-schemas_
          --object=dependent-schemas
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
      schema.add_ "dependentSchemas" (ActionDependentSchemas subschemas)

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
      schema.add_ "items" (ActionItems --prefix-items=prefix-items --items=items)

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
      schema.add_ "contains"
          ActionContains subschema --min-contains=min-contains --max-contains=max-contains

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
      action := ActionProperties
          --properties=properties
          --patterns=pattern-properties
          --additional=additional-properties
      schema.add_ "properties" action

    json.get "propertyNames" --if-present=: | property-names/any |
      sub-pointer := json-pointer + "propertyNames"
      // Building the schema will automatically add its json-pointer to the store.
      subschema := Schema.build_ property-names
          --parent=schema
          --context=context
          --json-pointer=sub-pointer
      schema.add_ "propertyNames" (ActionPropertyNames subschema)


// class VocabularyUnevaluated implements Vocabulary:
//   static URL ::= "https://json-schema.org/draft/2020-12/meta/unevaluated"
//   static KEYWORDS ::= [
//     "unevaluatedItems",
//     "unevaluatedProperties",
//   ]

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
      schema.add_ "type" (ActionType type)

    json.get "enum" --if-present=: | enum-values/any |
      schema.add_ "enum" (ActionEnum enum-values)

    json.get "const" --if-present=: | value/any |
      schema.add_ "const" (ActionConst value)

    ["multipleOf", "maximum", "exclusiveMaximum", "minimum", "exclusiveMinimum"].do: | keyword/string |
      json.get keyword --if-present=: | n/num |
        kind/int := ?
        if keyword == "multipleOf": kind = ActionNumComparison.MULTIPLE-OF
        else if keyword == "maximum": kind = ActionNumComparison.MAXIMUM
        else if keyword == "exclusiveMaximum": kind = ActionNumComparison.EXCLUSIVE-MAXIMUM
        else if keyword == "minimum": kind = ActionNumComparison.MINIMUM
        else if keyword == "exclusiveMinimum": kind = ActionNumComparison.EXCLUSIVE-MINIMUM
        else: throw "unreachable"
        schema.add_ keyword (ActionNumComparison --kind=kind n)

    json.get "required" --if-present=: | required-properties/List |
      schema.add_ "required" (ActionRequired required-properties)

    min-length := int-value_ (json.get "minLength")
    max-length := int-value_ (json.get "maxLength")
    if min-length or max-length:
      schema.add_ "stringLength" (ActionStringLength --min=min-length --max=max-length)

    min-items := int-value_ (json.get "minItems")
    max-items := int-value_ (json.get "maxItems")
    if min-items or max-items:
      schema.add_ "arrayLength" (ActionArrayLength --min=min-items --max=max-items)

    json.get "uniqueItems" --if-present=: | val/bool |
      if val: schema.add_ "uniqueItems" ActionUniqueItems

    min-properties := int-value_ (json.get "minProperties")
    max-properties := int-value_ (json.get "maxProperties")
    if min-properties or max-properties:
      schema.add_ "propertiesLength" (ActionObjectSize --min=min-properties --max=max-properties)

    json.get "pattern" --if-present=: | pattern/string |
      schema.add_ "pattern" (ActionPattern pattern)

    json.get "dependentRequired" --if-present=: | dependent-required/Map |
      schema.add_ "dependentRequired" (ActionDependentRequired dependent-required)

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

build o/any --resource-loader/ResourceLoader=HttpResourceLoader -> JsonSchema:
  store := Store
  context := BuildContext --store=store
  root-schema := Schema.build_ o --context=context --json-pointer=JsonPointer --parent=null

  // Resolve all references.
  while not context.refs.is-empty:
    pending := context.refs
    context.refs = []
    pending.do: | ref/ActionRef |
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


  // while store.has-missing-resources:
  //   store.do-missing-resources: | url/string |
  //     resource-json := resource-loader.load url
  //     store.add-downloaded-url url
  //     // Building the schema will automatically add its json-pointer to the store.
  //     schema := Schema.build_ resource-json --context=context --json-pointer=JsonPointer --parent=null
  //     // The ID of the schema could be different than the URL.
  //     store.add url schema

  // store.do: | _ schema/Schema |
  //   schema.resolve_ --store=store
  return JsonSchema root-schema store

class JsonSchema:
  schema_/Schema
  store_/Store

  constructor .schema_ .store_:

  validate o/any -> bool:
    return schema_.validate_ o --store=store_ --dynamic-scope=[]

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

  abstract validate_ o/any --store/Store --dynamic-scope/List -> bool


class SchemaObject_ extends Schema:
  is-resolved/bool := false

  constructor o/Map --schema-resource/SchemaResource_?:
    super.from-sub_ o --schema-resource=schema-resource

  actions/Map ::= {:}

  add_ keyword/string action/Action:
    actions[keyword] = action

  validate_ o/any --store/Store --dynamic-scope/List -> bool:
    with-updated-dynamic-scope_ dynamic-scope: | updated-scope/List |
      actions.do: | keyword/string action/Action |
        if not action.validate o --store=store --dynamic-scope=updated-scope: return false
    return true

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

  validate_ o/any --store/Store --dynamic-scope/List -> bool:
    return json-value

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

interface Action:
  validate o/any --dynamic-scope/List --store/Store -> bool

class ActionRef implements Action:
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

  validate o/any --dynamic-scope/List --store/Store -> bool:
    resolved/Schema? := is-dynamic
        ? find-dynamic-schema_ --dynamic-scope=dynamic-scope --store=store
        : resolved_

    if resolved == null:
      // TODO(florian): what should this do?
      return false
    return resolved.validate_ o --dynamic-scope=dynamic-scope --store=store

class ActionMulti implements Action:
  static ALL-OF ::= 0
  static ANY-OF ::= 1
  static ONE-OF ::= 2

  kind/int
  subschemas/List

  constructor --.kind .subschemas:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if kind == ALL-OF:
      return subschemas.every: | subschema/Schema |
        subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
    else if kind == ANY-OF:
      return subschemas.any: | subschema/Schema |
        subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
    else if kind == ONE-OF:
      success-count := 0
      subschemas.do: | subschema/Schema |
        if subschema.validate_ o --dynamic-scope=dynamic-scope --store=store:
          success-count++
      return success-count == 1
    else:
      throw "unreachable"

class ActionNot implements Action:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    return not subschema.validate_ o --dynamic-scope=dynamic-scope --store=store

class ActionIfThenElse implements Action:
  condition-subschema/Schema
  then-subschema/Schema?
  else-subschema/Schema?

  constructor .condition-subschema/Schema .then-subschema/Schema? .else-subschema/Schema?:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if condition-subschema.validate_ o --dynamic-scope=dynamic-scope --store=store:
      if not then-subschema: return true
      return then-subschema.validate_ o --dynamic-scope=dynamic-scope --store=store
    else:
      if not else-subschema: return true
      return else-subschema.validate_ o --dynamic-scope=dynamic-scope --store=store

class ActionDependentSchemas implements Action:
  subschemas/Map

  constructor .subschemas/Map:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not Map: return true
    map := o as Map
    subschemas.do: | key/string subschema/Schema |
      map.get key --if-present=: | value/any |
        if not subschema.validate_ o --dynamic-scope=dynamic-scope --store=store:
          return false
    return true

class ActionProperties implements Action:
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


  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not Map: return true
    map := o as Map
    map.do: | key/string value/any |
      is-additional := true
      if properties and properties.contains key:
        is-additional = false
        if not properties[key].validate_ value --dynamic-scope=dynamic-scope --store=store:
          return false
      if patterns:
        patterns.do: | pattern/string schema/Schema |
          regex := cached-regexs_[pattern]
          if regex.match key:
            is-additional = false
            if not schema.validate_ value --dynamic-scope=dynamic-scope --store=store:
              return false

      if is-additional and additional:
        if not additional.validate_ value --dynamic-scope=dynamic-scope --store=store:
          return false
    return true

class ActionPropertyNames implements Action:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not Map: return true
    map := o as Map
    map.do: | key/string _ |
      if not subschema.validate_ key --dynamic-scope=dynamic-scope --store=store:
        return false
    return true

class ActionContains implements Action:
  subschema/Schema
  min-contains/int?
  max-contains/int?

  constructor .subschema/Schema --.min-contains --.max-contains:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not List: return true
    list := o as List
    success-count := 0
    list.do: | item/any |
      if subschema.validate_ item --dynamic-scope=dynamic-scope --store=store:
        success-count++
    if min-contains:
      if success-count < min-contains:
        return false
    else if success-count == 0:
      return false

    if max-contains and success-count > max-contains:
      return false

    return true

class ActionType implements Action:
  types/List

  constructor .types/List:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    types.do: | type-string |
      if type-string == "null" and o == null: return true
      if type-string == "boolean" and o is bool: return true
      if type-string == "object" and o is Map: return true
      if type-string == "array" and o is List: return true
      if type-string == "number" and o is num: return true
      if type-string == "string" and o is string: return true
      if type-string == "integer":
        if o is int: return true
        // TODO(florian): This is not correct: to-int could throw.
        if o is float and (o as float).to-int == o: return true
    return false

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

class ActionEnum implements Action:
  values/List

  constructor .values/List:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    values.do: | value |
      if structural-equals_ o value: return true
    return false

class ActionConst implements Action:
  value/any

  constructor .value/any:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    return structural-equals_ o value

class ActionNumComparison implements Action:
  static MULTIPLE-OF ::= 0
  static MAXIMUM ::= 1
  static EXCLUSIVE-MAXIMUM ::= 2
  static MINIMUM ::= 3
  static EXCLUSIVE-MINIMUM ::= 4

  kind/int
  n/num

  constructor .n/num --.kind:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not num: return true
    if kind == MULTIPLE-OF:
      return o % n == 0.0
    else if kind == MAXIMUM:
      return o <= n
    else if kind == EXCLUSIVE-MAXIMUM:
      return o < n
    else if kind == MINIMUM:
      return o >= n
    else if kind == EXCLUSIVE-MINIMUM:
      return o > n
    else:
      throw "unreachable"

class ActionStringLength implements Action:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not string: return true
    str := o as string
    rune-size := str.size --runes
    if min and rune-size < min: return false
    if max and rune-size > max: return false
    return true

class ActionArrayLength implements Action:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not List: return true
    if min and o.size < min: return false
    if max and o.size > max: return false
    return true

class ActionUniqueItems implements Action:
  constructor:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not List: return true
    list := o as List
    // For simplicity do an O(n^2) algorithm.
    for i := 0; i < list.size; i++:
      for j := i + 1; j < list.size; j++:
        if structural-equals_ list[i] list[j]: return false
    return true

class ActionRequired implements Action:
  properties/List

  constructor .properties/List:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not Map: return true
    map := o as Map
    properties.do: | property |
      if not map.contains property: return false
    return true

class ActionObjectSize implements Action:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not Map: return true
    map := o as Map
    if min and map.size < min: return false
    if max and map.size > max: return false
    return true

class ActionItems implements Action:
  prefix-items/List?
  items/Schema?

  constructor --.prefix-items --.items:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not List: return true
    list := o as List
    for i := 0; i < list.size; i++:
      if prefix-items and i < prefix-items.size:
        if not prefix-items[i].validate_ list[i] --dynamic-scope=dynamic-scope --store=store:
          return false
      else if items:
        if not items.validate_ --dynamic-scope=dynamic-scope --store=store list[i]:
          return false
    return true

class ActionPattern implements Action:
  pattern/string
  regex_/regex.Regex

  constructor .pattern:
    regex_ = regex.parse pattern

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not string: return true
    return regex_.match o

class ActionDependentRequired implements Action:
  properties/Map

  constructor .properties/Map:

  validate o/any --dynamic-scope/List --store/Store -> bool:
    if o is not Map: return true
    map := o as Map
    properties.do: | key/string required/List |
      if map.contains key:
        required.do: | property |
          if not map.contains property: return false
    return true
