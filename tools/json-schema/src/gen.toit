// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

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

  recurse-check-no-change_ [block]:
    one-ofs-size := one-ofs.size
    all-ofs-size := all-ofs.size
    any-ofs-size := any-ofs.size
    dependent-size := dependent.size
    block.call
    if one-ofs.size != one-ofs-size or
       all-ofs.size != all-ofs-size or
       any-ofs.size != any-ofs-size or
       dependent.size != dependent-size
    :
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
