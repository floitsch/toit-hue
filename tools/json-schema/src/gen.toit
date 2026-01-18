// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import encoding.url as url-encoder
import toit-gen
import toit-gen.namer
import json-pointer show JsonPointer

import .action
import .json-schema
import .schema
import .store_
import .uri

class ClassManager:
  used/Set ::= {} // Of string.
  classes/Map ::= {:}  // From UriReference to toit-gen.Class.
  // TODO(florian): "any" shouldn't be a core class.
  any-class/toit-gen.Class ::= toit-gen.Class.core "any"
  list-class/toit-gen.Class ::= toit-gen.Class.core "List"
  map-class/toit-gen.Class ::= toit-gen.Class.core "Map"
  bool-class/toit-gen.Class ::= toit-gen.Class.core "bool"
  int-class/toit-gen.Class ::= toit-gen.Class.core "int"
  num-class/toit-gen.Class ::= toit-gen.Class.core "num"
  string-class/toit-gen.Class ::= toit-gen.Class.core "string"
  null-class/toit-gen.Class ::= toit-gen.Class.core "Null"

  constructor --class-seed/Map?={:}:
    if class-seed:
      class-seed.do: | url/UriReference name/string |
        class-name := namer.toit-class-name name
        use-unique_ --url=url class-name

  use-unique_ --url/UriReference name/string -> toit-gen.Class:
    attempt := name
    i := 0
    while used.contains attempt:
      attempt = "$name$(i++)"
    used.add attempt
    clazz := toit-gen.Class attempt --kind=toit-gen.Class.CLASS
    classes[url] = clazz
    return clazz

  use-class url/UriReference name/string -> toit-gen.Class:
    if classes.contains url:
      return classes[url]

    return use-unique_ --url=url name

  operator [] url/UriReference -> toit-gen.Class?:
    return classes.get url

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

/**
A visitor that assigns names to schemas.

Each schema gets a name that could be used as a Toit class name.
Many of these names won't be used, especially the names of
  schemas that represent primitive types.
*/
class NameVisitor implements ActionVisitor:
  current-class-name/string? := null
  class-manager/ClassManager

  constructor .class-manager:

  visit schema/Schema [--if-no-name] -> none:
    // Try to guess the name from the URL.
    url := schema.absolute-location
    fragment := url.fragment
        ? url-encoder.decode url.fragment
        : ""
    segments := fragment.split "/"
    name := segments.is-empty
        ? if-no-name.call
        : segments.last
    visit schema --name=name

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
    visit schema --name=name

  visit schema/Schema --name/string -> none:
    url := schema.absolute-location
    old-name := current-class-name
    current-class-name = (class-manager.use-class url name).preferred-name
    schema.actions.do: | action/Action |
      action.accept this
    current-class-name = old-name

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

  visit-StringLength _/StringLength -> none: return

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

class QualifiedType_:
  uri/UriReference?  // The JSON-Schema URL of the type, or null if Core.
  clazz/toit-gen.Class

  constructor .clazz --.uri=null:

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

  single-type -> string?:
    if ref: return (SchemaType ref.target).single-type
    if not type: return null
    accepted-types := type.types
    if accepted-types.size != 1: return null
    return accepted-types.first

  is-map -> bool:
    if ref: return (SchemaType ref.target).is-map
    if not type: return false
    if not properties: return false
    if properties.properties: return false
    return true

  is-typed-map -> bool:
    return is-map and properties.additional != null

  type class-manager/ClassManager -> QualifiedType_:
    if ref:
      on-stack := {}
      current-type := this
      on-stack.add current-type.url
      while current-type.ref:
        current-ref := current-type.ref
        current-type = SchemaType current-ref.target
        if on-stack.contains current-type.url:
          // Circular reference.
          return QualifiedType_ class-manager.any-class
        on-stack.add current-type.url
      return current-type.type class-manager
    type-string := single-type
    if type-string:
      if type-string == "null":
        return QualifiedType_ class-manager.null-class
      if type-string == "boolean":
        return QualifiedType_ class-manager.bool-class
      if type-string == "object":
        if is-map: return QualifiedType_ class-manager.map-class
        return QualifiedType_ class-manager[url] --uri=url
      if type-string == "array":
        return QualifiedType_ class-manager.list-class
      if type-string == "number":
        return QualifiedType_ class-manager.num-class
      if type-string == "string":
        return QualifiedType_ class-manager.string-class
      if type-string == "integer":
        return QualifiedType_ class-manager.int-class
    if one-of or all-of or any-of or properties:
      return QualifiedType_ class-manager[url] --uri=url
    return QualifiedType_ class-manager.any-class

  is-primitive -> bool:
    type-string := single-type
    if not type-string: return false
    return type-string == "null" or
        type-string == "boolean" or
        type-string == "number" or
        type-string == "string" or
        type-string == "integer"

  is-object -> bool:
    type-string := single-type
    if not type-string: return false
    return type-string == "object"

  convert-from-json expr/toit-gen.Expression -> toit-gen.Expression
      --class-manager/ClassManager
      [--gen-ref]
      :
    if not is-object: return expr
    if is-typed-map:
      value-type := SchemaType properties.additional
      value-def := toit-gen.VarDefinition.parameter "v"
      value-ref := toit-gen.Ref value-def
      element-conversion := value-type.convert-from-json value-ref
          --class-manager=class-manager
          --gen-ref=gen-ref
      block := toit-gen.Block --parameters=[toit-gen.VarDefinition.ignored, value-def]
          toit-gen.Statement element-conversion
      map-call := toit-gen.Call expr "map" --arguments=[block]
      return map-call
    if is-map:
      return toit-gen.As expr class-manager.map-class
    self-ref/toit-gen.Ref := gen-ref.call this
    return toit-gen.Call self-ref "from-json"
        --arguments=[expr]

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
  done/Set ::= {}
  schema-to-clazz/Map ::= {:}
  class-manager/ClassManager ::= ClassManager
  // TODO(florian): make this a map from uri to library when we
  // support multiple libraries.
  out-gen/LibraryGen? := null

  constructor .out-path:

  gen-type type/SchemaType -> QualifiedType_:
    result := type.type class-manager

    if done.contains type.url:
      return result
    done.add type.url

    if type.ref:
      gen-type (SchemaType type.ref.target)
      return result

    if type.type and type.type.types != ["object"]:
      return result

    if type.is-map:
      return result

    library-gen := library-gen-for-url_ type.url
    library-gen.gen-class type
    return result

  gen schemas/List -> none:
    if schemas.is-empty:
      throw "UNIMPLEMENTED"

    // TODO(florian): handle dynamic refs.
    // We need to collect all dynamic refs, and all the resource-uris.
    // Then extract the possible target schemas from the store.
    store := (schemas.first as JsonSchema).store_

    ref-visitor := CollectRefTargetsVisitor
    schemas.do: | schema/JsonSchema |
      // Not really a target, but this way we have all
      // transitive schemas we need.
      ref-visitor.ref-targets.add schema.schema
      ref-visitor.visit schema.schema

    reffed := ref-visitor.ref-targets.to-list
    reffed.sort: | a/Schema b/Schema |
      a.absolute-location.to-string.compare-to b.absolute-location.to-string

    name-visitor := NameVisitor class-manager
    reffed.do: | schema/Schema |
      name-visitor.visit schema --if-no-name=: "Root"

    // At this point the namer has assigned names to all schemas.
    // The 'type-names' map represents the actual type name we use for
    // each schema. Differences arise when a schema has a '$ref', or
    // if a schema represents a primitive type.

    program := toit-gen.Program

    // TODO(florian): split into multiple libraries.
    library := toit-gen.Library out-path
    program.libraries.add library
    out-gen = LibraryGen library --program-gen=this

    reffed.do: | schema/Schema |
      type := SchemaType schema
      gen-type type

    file-map := program.gen --in-memory
    file-map.do: | path/string code/string |
      print "path: $path"
      print code
      print "=============================="
      print

  library-gen-for-url_ uri/UriReference -> LibraryGen:
    // For now, all generated classes go into the same library.
    return out-gen

class LibraryGen:
  library/toit-gen.Library
  program-gen/Gen
  core-import/toit-gen.Import

  constructor .library --.program-gen/Gen:
    core-import = toit-gen.Import ["core"]
    library.imports.add core-import

  class-manager -> ClassManager:
    return program-gen.class-manager

  gen-class type/SchemaType -> none:
    qualified-clazz := type.type class-manager
    clazz := qualified-clazz.clazz
    map-class := toit-gen.Class.core "Map"
    data-arg := toit-gen.VarDefinition.parameter "data"
        --type=toit-gen.ImportedRef core-import class-manager.map-class
    constructor-body := toit-gen.Sequence
    if type.properties and type.properties.properties:
      type.properties.properties.do: | prop-name/string schema/Schema |
        prop-type := SchemaType schema
        field-qualified-type := program-gen.gen-type prop-type
        field-type-import := gen-import_ field-qualified-type
        field-type-ref/toit-gen.Ref := ?
        if field-type-import:
          field-type-ref = toit-gen.ImportedRef field-type-import field-qualified-type.clazz
        else:
          field-type-ref = toit-gen.Ref field-qualified-type.clazz

        is-required := false
        if type.required:
          is-required = type.required.properties.contains prop-name
        initial := is-required
            ? toit-gen.LateInitialized
            : toit-gen.Literal null
        field := toit-gen.VarDefinition.field prop-name
            --type=field-type-ref
            --is-nullable=not is-required
            --initial=initial
            --is-final=false
        clazz.fields.add field
        index := toit-gen.Index (toit-gen.Ref data-arg) (toit-gen.Literal prop-name)
        converted := prop-type.convert-from-json index
            --class-manager=class-manager
            --gen-ref=: | type/SchemaType |
              qualified := program-gen.gen-type type
              imp := gen-import_ qualified
              if imp:
                toit-gen.ImportedRef imp clazz
              else:
                toit-gen.Ref clazz
        constructor-body.assign field converted
    constr := toit-gen.Function.constr --parameters=[data-arg] constructor-body
    clazz.members.add constr
    library.classes.add clazz

  gen-import_ qualified/QualifiedType_ -> toit-gen.Import?:
    uri := qualified.uri
    if not uri: core-import
    // For now, all generated classes go into the same library.
    return null

