// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import encoding.url as url-encoder
import namer
import json-pointer show JsonPointer

import .action
import .json-schema
import .schema
import .store_
import .uri

class Namer:
  used/Set ::= {} // Of string.
  mapped-names/Map ::= {:} // From UriReference to name.

  constructor --class-seed/Map?={:}:
    if class-seed:
      class-seed.do: | url/UriReference name/string |
        class-name := namer.toit-class-name name
        use-unique_ --url=url class-name

  use-unique_ --url/UriReference name/string -> string:
    attempt := name
    i := 0
    while used.contains attempt:
      attempt = "$name$(i++)"
    used.add attempt
    mapped-names[url] = attempt
    return attempt

  use-class url/UriReference name/string -> string:
    if mapped-names.contains url:
      return mapped-names[url]

    return use-unique_ --url=url name

  operator [] url/UriReference -> string?:
    return mapped-names.get url

/** A namer for members (everything inside a class). */
class MemberNamer:
  used/Set ::= {} // Of string.

  constructor:

  reserve name/string -> none:
    assert: not used.contains name
    used.add name

  use-member name/string -> string:
    attempt := name
    i := 0
    while used.contains attempt:
      attempt = "$name$(i++)"
    used.add attempt
    return attempt

/**
A visitor that assigns names to schemas.

Each schema gets a name that could be used as a Toit class name.
Many of these names won't be used, especially the names of
  schemas that represent primitive types.
*/
class NameVisitor implements ActionVisitor:
  current-class-name/string? := null
  namer/Namer

  constructor .namer:

  visit schema/Schema --nested-name/string -> none:
    url := schema.absolute-location
    name/string := ?
    if nested-name == "":
      if not current-class-name: throw "Unable to name schema at $url"
      name = current-class-name
    else:
      name = current-class-name
          ? "$current-class-name-$nested-name"
          : nested-name
    current-class-name = namer.use-class url name
    schema.actions.do: | action/Action |
      action.accept this

  visit-Ref ref/Ref -> none:
    // Do nothing.

  visit-X-Of x-of/X-Of -> none:
    x-of.subschemas.do: | schema/Schema |
      visit schema --nested-name=""

  visit-Not not_/Not -> none:
    // Do nothing.

  visit-IfThenElse if-then-else/IfThenElse -> none:
    visit if-then-else.condition-subschema --nested-name=""
    visit if-then-else.then-subschema --nested-name=""
    visit if-then-else.else-subschema --nested-name=""

  visit-DependentSchemas dependent-schemas/DependentSchemas -> none:
    dependent-schemas.subschemas.do: | schema/Schema |
      visit schema --nested-name=""

  visit-Properties properties/Properties -> none:
    if properties.properties:
      properties.properties.do: | prop-name/string schema/Schema |
        visit schema --nested-name=prop-name

  visit-PropertyNames _/PropertyNames -> none: return

  visit-Contains _/Contains -> none: return

  visit-Type _/Type -> none: return

  visit-Enum _/Enum -> none: return

  visit-Const _/Const -> none: return

  visit-NumComparison _/NumComparison -> none: return

  visit-StringLength _StringLength -> none: return

  visit-ArrayLength _/ArrayLength -> none: return

  visit-UniqueItems _/UniqueItems -> none: return

  visit-Required _/Required -> none: return

  visit-ObjectSize _/ObjectSize -> none: return

  visit-Items items/Items -> none:
    if items.items:
      visit items.items --nested-name="Element"

  visit-Pattern _/Pattern -> none: return

  visit-DependentRequired _/DependentRequired -> none: return

  visit-UnevaluatedProperties _/UnevaluatedProperties -> none: return

  visit-UnevaluatedItems _/UnevaluatedItems -> none: return

  visit-Annotation _/Annotation -> none: return

  visit-Format _/Format -> none: return

  visit-Discriminator _/Discriminator -> none: return

class SchemaType implements ActionVisitor:
  schema/Schema
  one-of/X-Of? := null
  all-of/X-Of? := null
  any-of/X-Of? := null
  properties/Properties? := null
  required/Required? := null
  items/Items? := null
  ref/Ref? := null
  type/Type? := null
  description-annotation/Annotation? := null
  discriminator/Discriminator? := null

  constructor .schema:
    schema.actions.do: | action/Action |
      action.accept this

  url -> UriReference:
    return schema.absolute-location

  type-name namer/Namer -> string:
    if ref:
      on-stack := {}
      current-type := this
      on-stack.add current-type.url
      while current-type.ref:
        current-ref := current-type.ref
        current-type = SchemaType current-ref.target
        if on-stack.contains current-type.url:
          // Circular reference.
          return "any"
        on-stack.add current-type.url
      return current-type.type-name namer
    if type:
      accepted-types := type.types
      if accepted-types.size == 1:
        type-string := accepted-types.first
        if type-string == "null": return "Null"
        if type-string == "boolean": return "bool"
        if type-string == "object":
          print url
          return namer[url]
        if type-string == "array": return "List"
        if type-string == "number": return "num"
        if type-string == "string": return "string"
        if type-string == "integer": return "int"
    return "any"

  visit-Ref action/Ref -> none:
    ref = action

  visit-X-Of x-of/X-Of -> none:
    if x-of.kind == X-Of.ALL-OF: all-of = x-of
    else if x-of.kind == X-Of.ANY-OF: any-of = x-of
    else if x-of.kind == X-Of.ONE-OF: one-of = x-of
    else: unreachable

  visit-AllOf action/X-Of -> none:
    all-of = action

  visit-AnyOf action/X-Of -> none:
    any-of = action

  visit-OneOf action/X-Of -> none:
    one-of = action

  visit-Not _/Not -> none: return
  visit-IfThenElse _/IfThenElse -> none: return
  visit-DependentSchemas _/DependentSchemas -> none: return

  visit-Properties action/Properties -> none:
    properties = action

  visit-PropertyNames _/PropertyNames -> none: return
  visit-Contains _/Contains -> none: return

  visit-Type action/Type -> none:
    type = action

  visit-Enum _/Enum -> none: return
  visit-Const _/Const -> none: return
  visit-NumComparison _/NumComparison -> none: return
  visit-StringLength _/StringLength -> none: return
  visit-ArrayLength _/ArrayLength -> none: return
  visit-UniqueItems _/UniqueItems -> none: return

  visit-Required action/Required -> none:
    required = action

  visit-ObjectSize _/ObjectSize -> none: return

  visit-Items action/Items -> none:
    items = action

  visit-Pattern _/Pattern -> none: return
  visit-DependentRequired _/DependentRequired -> none: return
  visit-UnevaluatedProperties _/UnevaluatedProperties -> none: return
  visit-UnevaluatedItems _/UnevaluatedItems -> none: return
  visit-Annotation action/Annotation -> none:
    if action.keyword == "description" and
        action.value is string:
      description-annotation = action

  visit-Format _/Format -> none: return
  visit-Discriminator _/Discriminator -> none: return

class Gen:
  out-path/string
  namer/Namer ::= Namer
  done/Set ::= {}
  generated/List ::= [] // Of string.

  constructor .out-path:

  suggest-class-name uri/UriReference name/string -> none:
    namer.use-class uri name

  gen schema/JsonSchema --name/string?=null -> none:
    schema.store_
    name-visitor := NameVisitor namer
    name-visitor.visit --nested-name=(name or "Root") schema.schema
    print namer.mapped-names

    // At this point the namer has assigned names to all schemas.
    // The 'type-names' map represents the actual type name we use for
    // each schema. Differences arise when a schema has a '$ref', or
    // if a schema represents a primitive type.

    type := SchemaType schema
    gen-type type

    print (generated.join "\n")

  gen-type type/SchemaType -> none:
    if done.contains type.url:
      return
    done.add type.url

    /*
      schema/Schema
  one-of/X-Of? := null
  all-of/X-Of? := null
  any-of/X-Of? := null
  properties/Properties? := null
  required/Required? := null
  items/Items? := null
  ref/Ref? := null
  type/Type? := null
  description-annotation/Annotation? := null
  discriminator/Discriminator? := null
*/

    if type.ref:
      gen-type (SchemaType type.ref.target)
      return

    if not type.type or type.type.types != ["object"]:
      return

    url := type.url

    member-namer := MemberNamer
    member-namer.reserve "from-json"
    member-namer.reserve "to-json"
    member-namer.reserve "core"
    // TODO(florian): this should come from the namer package.
    KEYWORDS ::= ["return", "class",]
    KEYWORDS.do: member-namer.reserve it
    class-name := type.type-name namer
    fields-code := ""
    if type.properties:
      type.properties.properties.do: | prop-name/string schema/Schema |
        prop-type := SchemaType schema
        gen-type prop-type
        field-type-name := prop-type.type-name namer
        is-required := false
        if type.required:
          is-required = type.required.properties.contains prop-name
        initial-value := "?"
        if not is-required:
          field-type-name = "$field-type-name?"
          initial-value = "null"
        field-name := member-namer.use-member prop-name
        fields-code += "  $field-name/$field-type-name = $initial-value\n"

    code := """
      class $class-name:
        $fields-code
        constructor.from-json data/Map:
      """
    generated.add code
