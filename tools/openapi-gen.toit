import encoding.yaml
import fs
import host.file
import io
import system

import .mustache.src.mustache as mustache
import .openapi
import .openapi-gen.template-to-mustache show template-to-mustache

class Namer:
  unique_ name/string [is-reserved]:
    if not is-reserved.call name:
      return name
    i := 1
    while is-reserved.call "$name-$i":
      i++
    return "$name-$i"

  toit-class-name_ name/string -> string:
    first := name[0]
    if 'a' <= first <= 'z':
      name = name[..1].to-ascii-upper + name[1..]
    return name

  toit-identifier_ str/string -> string:
    // TODO(florian): make this more robust.
    str = str.replace --all "/" " "
    str = str.trim
    str = str.replace --all " " "-"
    return str


class GlobalNamer extends Namer:
  used-globals_/Set ::= {}
  globals_/IdentityMap ::= IdentityMap

  reserve name/string -> none:
    if used-globals_.contains name:
      throw "Global name already used: $name"
    used-globals_.add name

  /** Tags are mapped to class-names of the form 'TagApi'. */
  for-tag tag/Tag -> string:
    return for-tag-name tag.name

  for-default-tag -> string:
    return for-tag-name "Default"

  for-tag-name tag-name/string -> string:
    class-name-candidate := toit-class-name_ "$(tag-name)Api"
    result := unique_ class-name-candidate: used-globals_.contains it
    reserve result
    return result

  class-namer -> ClassNamer:
    return ClassNamer this

class ClassNamer extends Namer:
  used-methods_/Set ::= {}
  methods_/IdentityMap ::= IdentityMap
  global/GlobalNamer

  constructor .global:

  reserve-static name/string -> none:
    // Statics are in the same namespace as methods.
    if used-methods_.contains name:
      throw "Static/ name already used: $name"
    used-methods_.add name

  for-operation path/string method/string op/Operation -> string:
    return methods_.get op --init=:
      op-id := op.operation-id
      name := ?
      if op-id:
        name = to-method-name_ op-id
      else:
        name = to-method-name_ "$path-$method"
      if used-methods_.contains name:
        i := 1
        while used-methods_.contains "$name-$i":
          i++
        name = "$name-$i"
      used-methods_.add name
      name

  to-method-name_ name/string -> string:
    // TODO(florian): make this more robust and complete.
    name = name.replace --all "/" " "
    name = name.trim
    name = name.replace --all " " "-"
    return name

  /** A namer for a method of the class. */
  method-namer -> MethodNamer:
    return MethodNamer this

class MethodNamer extends Namer:
  used-locals_/Set ::= {}
  locals_/IdentityMap ::= IdentityMap
  klass/ClassNamer

  constructor .klass:

  for-parameter param/Parameter -> string:
    return locals_.get param --init=:
      name := param.name
      if used-locals_.contains name:
        i := 1
        while used-locals_.contains "$name-$i":
          i++
        name = "$name-$i"
      used-locals_.add name
      name

class OpenApiGenerator:
  base-dir/string

  constructor --.base-dir:

  gen openapi/OpenApi -> Map:
    namer := GlobalNamer
    namer.reserve "Client"

    client-namer := namer.class-namer
    client-namer.reserve-static "URL"

    tag-contexts := {:}
    tag-contexts[""] = {
      "class-name": namer.for-default-tag,
      "description": "Operations without a tag",
      "operations": [],
    }
    (openapi.tags or []).do: | tag/Tag |
      tag-contexts[tag.name] = {
        "class-name": namer.for-tag tag,
        "description": tag.description,
        "operations": [],
      }

    openapi.paths.paths.do: | path/string path-item/PathItem |
      // We are ignoring the description and summary of the path-item.
      // From what I can see most specs don't have one, and it seems to be ignored by
      // other generators as well.
      PathItem.OPERATION-KINDS.do: | method/string |
        operation := path-item.operation method
        if not operation: continue.do
        op-context := gen-operation path method operation client-namer
        // TODO(florian): what if an operation has multiple tags?
        tag := operation.tags.first or ""
        tag-context := tag-contexts.get tag --init=: {
          "class-name": namer.for-tag-name tag,
          "operations": [],
        }
        tag-context["operations"].add op-context

    tag-contexts.filter --in-place: | _ context/Map |
      not context["operations"].is-empty
    return {
      "apis": tag-contexts.values
    }

  // TODO(florian):
  // -
  gen-operation path/string method/string op/Operation namer/ClassNamer -> Map:
    name := namer.for-operation path method op
    method-namer := namer.method-namer
    parameters := (op.parameters or []).map: | param/Parameter |
      method-namer.for-parameter param

    return {
      "name": name,
      "parameters": parameters,
      "tags": op.tags,
    }

main args/List:
  if args.size != 2:
    print "Usage: openapi-to-toit <openapi.yaml> <output-dir>"
    return
  openapi := build (yaml.decode (file.read-content args[0]))
  context := (OpenApiGenerator --base-dir=args[1]).gen openapi
  dir := fs.dirname system.program-path
  toit-template := (file.read-content "$dir/openapi-template/api.toit").to-string
  mustache-template := template-to-mustache toit-template
  parsed := mustache.parse mustache-template
  rendered := mustache.render parsed --input=context
  file.write-content --path=(fs.join args[1] "api.toit") rendered
