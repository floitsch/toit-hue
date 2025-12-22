// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import namer
import json-pointer show JsonPointer

import .action
import .schema
import .store_

abstract class GenVisitorBase:
  visit-X-Of x-of/X-Of -> any:
    if x-of.is-disabled: return null
    if x-of.kind == X-Of.ALL-OF: return visit-AllOf x-of
    else if x-of.kind == X-Of.ANY-OF: return visit-AnyOf x-of
    else if x-of.kind == X-Of.ONE-OF: return visit-OneOf x-of
    else: unreachable

  abstract visit-AllOf x-of/X-Of -> any
  abstract visit-AnyOf x-of/X-Of -> any
  abstract visit-OneOf x-of/X-Of -> any

class ClassVisitor extends GenVisitorBase implements ActionVisitor:
  one-ofs/List := []  // Of List of schemas.
  all-ofs/List := []  // Of schemas.
  any-ofs/List := []  // Of schemas.
  dependent/List := []  // Of Map<String, Schema>.
  fields/Set := {}
  fields-required/Set := {}

  visit schema/Schema -> none:
    schema.actions.do: | action/Action |
      action.accept this

  recurse-check-no-change_ [block]:
    one-ofs-size := one-ofs.size
    all-ofs-size := all-ofs.size
    any-ofs-size := any-ofs.size
    dependent-size := dependent.size
    block.call
    if one-ofs.size != one-ofs-size or
        all-ofs.size != all-ofs-size or
        any-ofs.size != any-ofs-size or
        dependent.size != dependent-size:
      throw "UNIMPLEMENTED: conditional hierarchy structure."

  visit-Ref ref/Ref -> none:
    if ref.is-dynamic: throw "UNIMPLEMENTED"
    ref.target.actions.do: | action/Action |
      action.accept this

  visit-AllOf x-of/X-Of -> none:
    all-ofs.add-all x-of.subschemas

  visit-AnyOf x-of/X-Of -> none:
    any-ofs.add-all x-of.subschemas

  visit-OneOf x-of/X-Of -> none:
    // Note that we add the subschemas as list, and don't merge
    // all one-ofs.
    one-ofs.add x-of.subschemas

  visit-Not not_/Not -> none: return

  visit-IfThenElse if-then-else/IfThenElse -> none:
    if-then-else.condition-subschema.actions.do: | action/Action |
      action.accept this

    recurse-check-no-change_:
      if-then-else.then-subschema.actions.do: | action/Action |
        action.accept this
      if-then-else.else-subschema.actions.do: | action/Action |
        action.accept this

  visit-DependentSchemas dependent-schemas/DependentSchemas -> none:
    dependent.add dependent-schemas.subschemas

  visit-Properties properties/Properties -> none:
    recurse-check-no-change_:
      properties.properties.do: | _ schema/Schema |
        schema.actions.do: | action/Action |
          action.accept this
    fields.add-all properties.properties.keys

  visit-PropertyNames property-names/PropertyNames -> none: return

  visit-Contains contains/Contains -> none: return

  visit-Type type/Type -> none: return

  visit-Enum enum_/Enum -> none: return

  visit-Const const/Const -> none: return

  visit-NumComparison num-comparison/NumComparison -> none: return

  visit-StringLength string-length/StringLength -> none: return

  visit-ArrayLength array-length/ArrayLength -> none: return

  visit-UniqueItems unique-items/UniqueItems -> none: return

  visit-Required required/Required -> none:
    fields-required.add-all required.properties

  visit-ObjectSize object-size/ObjectSize -> none: return

  visit-Items items/Items -> none: return

  visit-Pattern pattern/Pattern -> none: return

  visit-DependentRequired dependent-required/DependentRequired -> none: return
  visit-UnevaluatedProperties unevaluated-properties/UnevaluatedProperties -> none: unreachable
  visit-UnevaluatedItems unevaluated-items/UnevaluatedItems -> none: unreachable
  visit-Annotation annotation/Annotation -> none: unreachable
  visit-Format format/Format -> none: unreachable
  visit-Discriminator discriminator/Discriminator -> none: unreachable

class CollectRefTargetsVisitor implements ActionVisitor:
  ref-targets/Set ::= {}  // of Schema.

  visit schema/Schema -> none:
    schema.actions.do: | action/Action |
      action.accept this

  visit-Ref ref/Ref -> none:
    if ref.is-dynamic: throw "UNIMPLEMENTED"
    ref-targets.add ref.target
    ref.target.actions.do: | action/Action |
      action.accept this

  visit-X-Of x-of/X-Of -> none:
    x-of.subschemas.do: | schema/Schema |
      visit schema

  visit-Not not_/Not -> none: return

  visit-IfThenElse if-then-else/IfThenElse -> none:
    visit if-then-else.condition-subschema
    visit if-then-else.then-subschema
    visit if-then-else.else-subschema

  visit-DependentSchemas dependent-schemas/DependentSchemas -> none:
    dependent-schemas.subschemas.do: | schema/Schema |
      visit schema

  visit-Properties properties/Properties -> none:
    if properties.properties:
      properties.properties.do: | _ schema/Schema |
        visit schema
    // TODO(florian): handle "additional".

  visit-PropertyNames property-names/PropertyNames -> none: return

  visit-Contains contains/Contains -> none: return

  visit-Type type/Type -> none: return

  visit-Enum enum_/Enum -> none: return

  visit-Const const/Const -> none: return

  visit-NumComparison num-comparison/NumComparison -> none: return

  visit-StringLength string-length/StringLength -> none: return

  visit-ArrayLength array-length/ArrayLength -> none: return

  visit-UniqueItems unique-items/UniqueItems -> none: return

  visit-Required required/Required -> none: return

  visit-ObjectSize object-size/ObjectSize -> none: return

  visit-Items items/Items -> none:
    if items.prefix-items and not items.prefix-items.is-empty:
      items.prefix-items.do: | schema/Schema |
        visit schema
    visit items.items

  visit-Pattern pattern/Pattern -> none: return

  visit-DependentRequired dependent-required/DependentRequired -> none: return

  visit-UnevaluatedProperties unevaluated-properties/UnevaluatedProperties -> none:
    visit unevaluated-properties.subschema

  visit-UnevaluatedItems unevaluated-items/UnevaluatedItems -> none:
    visit unevaluated-items.subschema

  visit-Annotation annotation/Annotation -> none: return

  visit-Format format/Format -> none: return

  visit-Discriminator discriminator/Discriminator -> none:
    discriminator.mapping.do --values: | schema/Schema |
      visit schema

class Type_:
  schema/Schema
  path/JsonPointer
  one-ofs/List := []  // Of List of schemas.
  all-ofs/List := []  // Of schemas.
  any-ofs/List := []  // Of schemas.
  dependent/List := []  // Of Map<String, Schema>.
  fields/Set := {}
  fields-required/Set := {}
  reffed/Schema? := null
  types/List? := null

  constructor .schema .path:

class TypeVisitor extends GenVisitorBase implements ActionVisitor:
  current-path/JsonPointer := JsonPointer
  current-type/Type_? := null
  schemas-to-types/Map ::= {:}

  visit schema/Schema --new-type/bool=false -> none:
    old-type := current-type
    if new-type:
      current-type = Type_ schema current-path
      schemas-to-types[schema] = current-type
    schema.actions.do: | action/Action |
      action.accept this
    current-type = old-type

  visit segment schema/Schema --new-type/bool=false -> none:
    old := current-path
    current-path = current-path[segment]
    visit schema --new-type=new-type
    current-path = old

  recurse-check-no-change_ [block]:
    one-ofs-size := current-type.one-ofs.size
    all-ofs-size := current-type.all-ofs.size
    any-ofs-size := current-type.any-ofs.size
    dependent-size := current-type.dependent.size
    block.call
    if current-type.one-ofs.size != one-ofs-size or
        current-type.all-ofs.size != all-ofs-size or
        current-type.any-ofs.size != any-ofs-size or
        current-type.dependent.size != dependent-size:
      throw "UNIMPLEMENTED: conditional hierarchy structure."

  accept_ index o/Action -> none:
    old := current-path
    current-path = current-path[index]
    o.accept this
    current-path = old

  visit-Ref ref/Ref -> none:
    if ref.is-dynamic: throw "UNIMPLEMENTED"
    if ref.target:
      current-type.reffed = ref.target

  visit-AllOf x-of/X-Of -> none:
    current-type.all-ofs.add-all x-of.subschemas
    x-of.subschemas.do: | schema/Schema |
      visit "all-of" schema

  visit-AnyOf x-of/X-Of -> none:
    current-type.any-ofs.add-all x-of.subschemas
    x-of.subschemas.do: | schema/Schema |
      visit "any-of" schema

  visit-OneOf x-of/X-Of -> none:
    // Note that we add the subschemas as list, and don't merge
    // all one-ofs.
    current-type.one-ofs.add x-of.subschemas
    x-of.subschemas.do: | schema/Schema |
      visit "one-of" schema

  visit-Not not_/Not -> none:
    // TODO(florian): do we need to go through not children?
    return

  visit-IfThenElse if-then-else/IfThenElse -> none:
    visit "condition" if-then-else.condition-subschema
    recurse-check-no-change_:
      visit "then" if-then-else.then-subschema
      visit "else" if-then-else.else-subschema

  visit-DependentSchemas dependent-schemas/DependentSchemas -> none:
    current-type.dependent.add dependent-schemas.subschemas
    dependent-schemas.subschemas.do: | schema/Schema |
      visit "dependent-schemas" schema

  visit-Properties properties/Properties -> none:
    if properties.properties:
      properties.properties.do: | prop-name/string schema/Schema |
        visit prop-name schema --new-type
      current-type.fields.add-all properties.properties.keys

  visit-PropertyNames property-names/PropertyNames -> none: return

  visit-Contains contains/Contains -> none: return

  visit-Type type/Type -> none:
    // TODO(florian): we should use this to type fields.
    current-type.types = type.types
    return

  visit-Enum enum_/Enum -> none:
    // TODO(florian): we should use this to type fields.
    return

  visit-Const const/Const -> none: return

  visit-NumComparison num-comparison/NumComparison -> none: return

  visit-StringLength string-length/StringLength -> none: return

  visit-ArrayLength array-length/ArrayLength -> none: return

  visit-UniqueItems unique-items/UniqueItems -> none: return

  visit-Required required/Required -> none:
    current-type.fields-required.add-all required.properties

  visit-ObjectSize object-size/ObjectSize -> none: return

  visit-Items items/Items -> none:
    if items.prefix-items and not items.prefix-items.is-empty:
      print "Unhandled prefix-items"
    if items.items:
      visit "items" items.items --new-type

  visit-Pattern pattern/Pattern -> none: return

  visit-DependentRequired dependent-required/DependentRequired -> none: return

  visit-UnevaluatedProperties unevaluated-properties/UnevaluatedProperties -> none:
    visit "unevaluated-properties" unevaluated-properties.subschema --new-type

  visit-UnevaluatedItems unevaluated-items/UnevaluatedItems -> none:
    visit "unevaluated-items" unevaluated-items.subschema --new-type

  visit-Annotation annotation/Annotation -> none: return
  visit-Format format/Format -> none: unreachable
  visit-Discriminator discriminator/Discriminator -> none: unreachable

class Namer:
  used/Set ::= {} // of strings.
  fragment-to-name ::= {:}  // From fragment to name.

  use --fragment/string -> string:
    return fragment-to-name.get fragment --init=:
      parts := fragment.split "%2F"
      attempt := parts.last
      if attempt == "": attempt = "unknown"
      attempt = namer.toit-class-name attempt
      i := 0
      orig := attempt
      while true:
        if not used.contains attempt:
          used.add attempt
          continue.get attempt
        attempt = "$orig$(i++)"

class Gen:
  dir/string
  used-files/Set ::= {}
  url-to-file/Map ::= {:}  // From URL to file path.

  constructor .dir:

  gen schema/Schema --path/string:
    url := schema.absolute-location
    assert: not url-to-file.contains url
    last-segment := (url.path.split "/").last
    file-path := "$dir/$(last-segment).toit"
    i := 0
    while true:
      if not used-files.contains file-path:
        used-files.add file-path
        break
      file-path = "$dir/$(last-segment)-$(i++).toit"
    url-to-file[url] = file-path

    ref-visitor := CollectRefTargetsVisitor
    ref-visitor.visit schema
    reffed-schemas := ref-visitor.ref-targets.to-list

    type-visitor := TypeVisitor
    type-visitor.visit --new-type schema
    reffed-schemas.do: | reffed/Schema |
      if reffed == schema: continue.do
      type-visitor.visit reffed --new-type

    type-visitor.schemas-to-types.do: | schema/Schema type/Type_ |
      print "Schema: $schema.absolute-location"
      print "Type path: $type.path"
      print "Fields: $type.fields"
      print "Required fields: $type.fields-required"
      print "OneOfs: $type.one-ofs"
      print "AllOfs: $type.all-ofs"
      print "AnyOfs: $type.any-ofs"
      print "Dependent schemas: $type.dependent"
      print "Reffed: $(type.reffed and type.reffed.absolute-location)"
      print "Types: $type.types"
      print

