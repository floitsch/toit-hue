/**
An implementation of the JSON Schema Specification Draft 2022-12.
https://json-schema.org/draft/2020-12/json-schema-core#name-the-vocabulary-keyword
*/

import uuid
import .uri
import .json-pointer

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

  add-actions --schema/SchemaObject_ --context/BuildContext --json-pointer/JsonPointer -> none:
    json := schema.json-value
    json.get "\$anchor" --if-present=: | anchor-id/string |
      anchor-uri := context.uri.with-fragment (UriReference.normalize-fragment anchor-id)
      context.store.add anchor-uri.to-string schema

    json.get "\$dynamicAnchor" --if-present=: | anchor-id/string |
      throw "unimplemented"

    json.get "\$ref" --if-present=: | ref/string |
      reference := UriReference.parse ref
      reference = reference.normalize
      target-uri := reference.resolve --base=context.uri
      target := target-uri.to-string
      schema.add_ "\$ref" (ActionRef target)

    json.get "\$dynamicRef" --if-present=: | ref-id/string |
      throw "unimplemented"

    json.get "\$defs" --if-present=: | defs/Map |
      schema-defs := defs.map: | key/string value/any |
        sub-pointer := json-pointer + "\$defs" + key
        // Building the schema will automatically add its json-pointer to the build context.
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
      sub-schema-json := list[i]
      sub-pointer := json-pointer + "$i"
      // Building the schema will automatically add its json-pointer to the build context.
      Schema.build_ sub-schema-json --parent=parent --context=context --json-pointer=sub-pointer
    return result

  map-schemas_ --object/Map --parent/SchemaObject_? --context/BuildContext --json-pointer/JsonPointer -> Map:
    return object.map: | key/string sub-schema-json/Map |
      sub-pointer := json-pointer + key
      // Building the schema will automatically add its json-pointer to the build context.
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
      // Building the schema will automatically add its json-pointer to the build context.
      subschema := Schema.build_ not-entry --parent=schema --context=context --json-pointer=sub-pointer
      schema.add_ "not" (ActionNot subschema)

    condition-subschema/Schema? := json.get "if" --if-present=: | if-entry/any |
      condition-sub-pointer := json-pointer + "if"
      // Building the schema will automatically add its json-pointer to the build context.
      Schema.build_ if-entry --parent=schema --context=context --json-pointer=condition-sub-pointer

    // We build the then subschema even if there is no 'if', in case
    // the subschema is referenced.
    then-subschema/Schema? := json.get "then" --if-present=: | then-entry/any |
      then-sub-pointer := json-pointer + "then"
      // Building the schema will automatically add its json-pointer to the build context.
      Schema.build_ then-entry --parent=schema --context=context --json-pointer=then-sub-pointer

    // We build the 'else' subschema even if there is no 'if', in case
    // the subschema is referenced.
    else-subschema/Schema? := json.get "else" --if-present=: | else-entry/any |
      else-sub-pointer := json-pointer + "else"
      // Building the schema will automatically add its json-pointer to the build context.
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
      // Building the schema will automatically add its json-pointer to the build context.
      subschema := Schema.build_ items
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    if prefix-items or items:
      schema.add_ "items" (ActionItems --prefix-items=prefix-items --items=items)

    json.get "contains" --if-present=: | contains/any |
      sub-pointer := json-pointer + "contains"
      supports-min-max := context.vocabularies.contains VocabularyValidation.URI
      min-contains := supports-min-max ? int-value_ (json.get "minContains") : null
      max-contains := supports-min-max ? int-value_ (json.get "maxContains") : null

      // Building the schema will automatically add its json-pointer to the build context.
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
      // Building the schema will automatically add its json-pointer to the build context.
      subschema := Schema.build_ additional-properties
          --parent=schema
          --context=context
          --json-pointer=sub-pointer

    if properties or additional-properties:
      action := ActionProperties
          --properties=properties
          --additional=additional-properties
      schema.add_ "properties" action

    json.get "patternProperties" --if-present=: | pattern-properties/Map |
      throw "Unimplemented"

    json.get "propertyNames" --if-present=: | property-names/any |
      sub-pointer := json-pointer + "propertyNames"
      // Building the schema will automatically add its json-pointer to the build context.
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

DEFAULT-VOCABULARIES ::= {
  VocabularyCore.URI: VocabularyCore,
  VocabularyApplicator.URI: VocabularyApplicator,
  VocabularyValidation.URI: VocabularyValidation,
}

build o/any -> Schema:
  store := Store
  context := BuildContext
      --vocabularies=DEFAULT-VOCABULARIES
      --store=store
      --uri=null
  result := Schema.build_ o --context=context --json-pointer=JsonPointer --parent=null
  store.do: | _ schema/Schema |
    schema.resolve_ --store=context.store
  return result

abstract class Schema:
  json-value/any
  parent/SchemaObject_?

  constructor.from-sub_ .json-value --.parent:

  static build_ o/any --parent/SchemaObject_? --context/BuildContext --json-pointer/JsonPointer -> Schema:
    result/Schema := ?
    if o == true:
      result = SchemaTrue_ --parent=parent
    else if o == false:
      result = SchemaFalse_ --parent=parent
    else:
      schema-object := SchemaObject_ o --parent=parent
      new-id := o.get "\$id"
      if new-id or parent == null:
        // This is a resource schema.
        // TODO(florian): get the "$schema".
        if not new-id:
          new-id = "urn:uuid:$(uuid.uuid5 "json-schema" "$Time.now.ns-since-epoch")"
        // Empty fragments are allowed (but not recommended).
        // Trim them.
        new-id = new-id.trim --right "#"
        new-uri := UriReference.parse new-id
        if not new-uri.is-absolute:
          new-uri = new-uri.resolve --base=context.uri
        new-uri = new-uri.normalize
        context = context.with --uri=new-uri
        // Also add the schema without the '#' fragment.
        context.store.add new-uri.to-string schema-object
        // Reset the json-pointer.
        json-pointer = JsonPointer

      result = schema-object
      context.vocabularies.do: | _ vocabulary/Vocabulary |
        vocabulary.add-actions --schema=schema-object --context=context --json-pointer=json-pointer
    escaped-json-pointer := json-pointer.to-fragment-string
    escaped-json-pointer = UriReference.normalize-fragment escaped-json-pointer
    schema-json-pointer-url := context.uri.with-fragment escaped-json-pointer
    context.store.add schema-json-pointer-url.to-string result
    return result

  abstract resolve_ --store/Store -> none
  abstract validate o/any -> bool

class SchemaObject_ extends Schema:
  is-resolved/bool := false

  constructor o/Map --parent/SchemaObject_?:
    super.from-sub_ o --parent=parent

  actions/Map ::= {:}

  add_ keyword/string action/Action:
    actions[keyword] = action

  resolve_ --store/Store -> none:
    if is-resolved: return
    is-resolved = true
    actions.do: | keyword/string action/Action |
      if action is ResolveableAction:
        (action as ResolveableAction).resolve_ --store=store

  validate o/any -> bool:
    actions.do: | keyword/string action/Action |
      if not action.validate o: return false
    return true

class SchemaTrue_ extends Schema:
  constructor --parent/SchemaObject_?:
    super.from-sub_ true --parent=parent

  validate o/any -> bool:
    return true

  resolve_ --store/Store -> none:
    return

class SchemaFalse_ extends Schema:
  constructor --parent/SchemaObject_?:
    super.from-sub_ false --parent=parent

  validate o/any -> bool:
    return false

  resolve_ --store/Store -> none:
    return


class BuildContext:
  vocabularies/Map
  store/Store
  uri/UriReference?

  constructor --.vocabularies --.store --.uri:

  with --uri/UriReference -> BuildContext:
    return BuildContext --vocabularies=vocabularies --store=store --uri=uri

class Store:
  entries_/Map ::= {:}

  add id/string schema/Schema:
    entries_[id] = schema

  get id/string -> Schema?:
    return entries_.get id

  do [block] -> none:
    entries_.do block

interface Action:
  validate o/any -> bool

interface ResolveableAction extends Action:
  resolve_ --store/Store -> none

class ActionRef implements ResolveableAction:
  target/string
  resolved_/Schema? := null

  constructor .target:

  resolve_ --store/Store -> none:
    resolved_ = store.get target

  validate o/any -> bool:
    if resolved_ == null:
      throw "unimplemented: $target"
    return resolved_.validate o

class ActionMulti implements Action:
  static ALL-OF ::= 0
  static ANY-OF ::= 1
  static ONE-OF ::= 2

  kind/int
  subschemas/List

  constructor --.kind .subschemas:

  validate o/any -> bool:
    if kind == ALL-OF:
      return subschemas.every: | subschema/Schema |
        subschema.validate o
    else if kind == ANY-OF:
      return subschemas.any: | subschema/Schema |
        subschema.validate o
    else if kind == ONE-OF:
      success-count := 0
      subschemas.do: | subschema/Schema |
        if subschema.validate o:
          success-count++
      return success-count == 1
    else:
      throw "unreachable"

class ActionNot implements Action:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any -> bool:
    return not subschema.validate o

class ActionIfThenElse implements Action:
  condition-subschema/Schema
  then-subschema/Schema?
  else-subschema/Schema?

  constructor .condition-subschema/Schema .then-subschema/Schema? .else-subschema/Schema?:

  validate o/any -> bool:
    if condition-subschema.validate o:
      return then-subschema ? then-subschema.validate o : true
    else:
      return else-subschema ? else-subschema.validate o : true

class ActionDependentSchemas implements Action:
  subschemas/Map

  constructor .subschemas/Map:

  validate o/any -> bool:
    if o is not Map: return true
    map := o as Map
    subschemas.do: | key/string subschema/Schema |
      map.get key --if-present=: | value/any |
        if not subschema.validate o: return false
    return true

class ActionProperties implements Action:
  properties/Map?
  additional/Schema?

  constructor --.properties --.additional:

  validate o/any -> bool:
    if o is not Map: return true
    map := o as Map
    map.do: | key/string value/any |
      if properties and properties.contains key:
        if not properties[key].validate value: return false
      else if additional:
        if not additional.validate value: return false
    return true

class ActionPropertyNames implements Action:
  subschema/Schema

  constructor .subschema/Schema:

  validate o/any -> bool:
    if o is not Map: return true
    map := o as Map
    map.do: | key/string _ |
      if not subschema.validate key: return false
    return true

class ActionContains implements Action:
  subschema/Schema
  min-contains/int?
  max-contains/int?

  constructor .subschema/Schema --.min-contains --.max-contains:

  validate o/any -> bool:
    if o is not List: return true
    list := o as List
    success-count := 0
    list.do: | item/any |
      if subschema.validate item: success-count++
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

  validate o/any -> bool:
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

  validate o/any -> bool:
    values.do: | value |
      if structural-equals_ o value: return true
    return false

class ActionConst implements Action:
  value/any

  constructor .value/any:

  validate o/any -> bool:
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

  validate o/any -> bool:
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

  validate o/any -> bool:
    if o is not string: return true
    if min and o.size < min: return false
    if max and o.size > max: return false
    return true

class ActionArrayLength implements Action:
  min/int?
  max/int?

  constructor --.min --.max:

  validate o/any -> bool:
    if o is not List: return true
    if min and o.size < min: return false
    if max and o.size > max: return false
    return true

class ActionUniqueItems implements Action:
  constructor:

  validate o/any -> bool:
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

  validate o/any -> bool:
    if o is not Map: return true
    map := o as Map
    properties.do: | property |
      if not map.contains property: return false
    return true

class ActionItems implements Action:
  prefix-items/List?
  items/Schema?

  constructor --.prefix-items --.items:

  validate o/any -> bool:
    if o is not List: return true
    list := o as List
    for i := 0; i < list.size; i++:
      if prefix-items and i < prefix-items.size:
        if not prefix-items[i].validate list[i]: return false
      else if items:
        if not items.validate list[i]: return false
    return true
