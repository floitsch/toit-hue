// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import encoding.url as url-encoder
import namer
import json-pointer show JsonPointer

import .action
import .schema
import .store_
import .uri

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
  description/string? := null

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

  visit-Annotation annotation/Annotation -> none:
    if annotation.keyword == "description" and
        annotation.value is string:
      current-type.description = annotation.value

  visit-Format format/Format -> none: unreachable
  visit-Discriminator discriminator/Discriminator -> none: unreachable

class Namer:
  used/Map ::= {:} // From URL (without fragment) to a Set of strings.

  use-class url/UriReference [--if-unknown] -> string:
    url-str := url.to-string
    sharp-index := url-str.index-of "#"
    base-url := sharp-index != -1 ? url-str[0..sharp-index] : url-str
    fragment := sharp-index != -1 ? url_str[sharp-index + 1..] : ""
    namer-set/Set ::= used.get base-url --init=: Set

    fragment = url-encoder.decode fragment
    parts := fragment.split "/"
    // Some heuristics to get nice names. This should probably get
    // patches over time.
    suggestion := ""
    // Run through the fragments.
    for i := 0; i < parts.size; i++:
      part/string := parts[i]
      if part == "\$defs" or part == "definitions" or
          part == "properties" or part == "items":
        continue
      if suggestion == "":
        suggestion = part
        continue
      suggestion = "$suggestion-$part"
    if suggestion == "":
      suggestion = if-unknown.call

    suggestion = namer.toit-class-name suggestion
    attempt := suggestion
    i := 0
    while namer-set.contains attempt:
      attempt = "$suggestion$(i++)"
    namer-set.add attempt
    return attempt

class Gen:
  dir/string
  used-files_/Set ::= {}
  url-to-file_/Map ::= {:}  // From URL to file path.
  url-to-namers_/Map ::= {:}

  constructor .dir:

  gen schema/Schema --path/string:
    url := schema.absolute-location
    assert: not url-to-file_.contains url
    last-segment := (url.path.split "/").last
    file-path := "$dir/$(last-segment).toit"
    i := 0
    while true:
      if not used-files_.contains file-path:
        used-files_.add file-path
        break
      file-path = "$dir/$(last-segment)-$(i++).toit"
    url-to-file_[url] = file-path

    type-visitor := TypeVisitor
    type-visitor.visit --new-type schema
    reffed-schemas.do: | reffed/Schema |
      if reffed == schema: continue.do
      type-visitor.visit reffed --new-type

    names := compute-class-names_ (reffed-schemas + [schema])
    print names

    type-visitor.schemas-to-types.do: | schema/Schema type/Type_ |
      print "Schema: $schema.absolute-location"
      print "Name: $(names.get schema.absolute-location)"
      print "Type path: $type.path"
      print "Fields: $type.fields"
      print "Required fields: $type.fields-required"
      print "OneOfs: $(type.one-ofs.map: it.map: it.absolute-location)"
      print "AllOfs: $(type.all-ofs.map: it.absolute-location)"
      print "AnyOfs: $(type.any-ofs.map: it.absolute-location)"
      print "Dependent schemas: $type.dependent"
      print "Reffed: $(type.reffed and type.reffed.absolute-location)"
      print "Types: $type.types"
      print


  compute-class-names_ reffed/List -> Map:
    urls := reffed.map: | schema/Schema |
      schema.absolute-location
    // We really only need prefixes to appear earlier.
    urls.sort: | a/UriReference b/UriReference | a.compare-to b

    url-to-name := {:}
    urls.do: | url-ref/UriReference |
      url := url-ref.to-string
      sharp-index := url.index-of "#"
      base-url := sharp-index != -1 ? url[0..sharp-index] : url
      namer/Namer := url-to-namers_.get url --init=(: Namer)
      fragment := sharp-index != -1 ? url[sharp-index + 1..] : ""
      url-to-name[url-ref] = namer.use-class
          --fragment=fragment
          --if-unknown=: "Root"

    return url-to-name
