import encoding.yaml
import fs
import host.file
import io
import system

import .mustache.src.mustache as mustache
import .openapi
import .openapi-gen.template-to-mustache show template-to-mustache

COMMON-ABBREVIATIONS := {
  "XML",
  "HTTP",
  "HTML",
  "JSON",
  "API",
}

class Namer:
  unique_ name/string [is-reserved]:
    if not is-reserved.call name:
      return name
    i := 1
    while is-reserved.call "$name-$i":
      i++
    return "$name-$i"

  toit-class-name_ name/string -> string:
    return to-caml-case_ (toit-identifier_ name)

  toit-member-name_ name/string -> string:
    return to-kebab-case_ (toit-identifier_ name)

  toit-local-name_ name/string -> string:
    return to-kebab-case_ (toit-identifier_ name)

  toit-identifier_ str/string -> string:
    chars := []
    str.do --runes: | rune/int |
      if 0 <= rune <= 9:
        chars.add rune
      else if 'a' <= rune <= 'z':
        chars.add rune
      else if 'A' <= rune <= 'Z':
        chars.add rune
      else if rune == '-' or rune == '_':
        chars.add rune
      else:
        chars.add rune
    // Make sure we don't have a leading or trailing '-' or two
    // consecutive '-'s.
    to := 0
    last-was-dash := true
    for i := 0; i < chars.size; i++:
      c := chars[i]
      if c == '-':
        if last-was-dash or i == chars.size - 1:
          continue // Skip this character.
        last-was-dash = true
      chars[to++] = c
    chars.resize to
    return string.from-runes chars

  to-kebab-case_ id/string -> string:
    chunks := split-into-chunks_ id
    chunks.map --in-place: | str/string |
      str.to-ascii-lower
    return chunks.join "-"

  to-caml-case_ id/string -> string:
    chunks := split-into-chunks_ id
    chunks.map --in-place: | str/string |
      lower := str.to-ascii-lower
      lower[..1].to-ascii-upper + lower[1..]
    return chunks.join ""

  split-into-chunks_ str/string -> List:
    result := []
    start := 0
    last-was-upper := false
    for i := 0; i < str.size; i++:
      c := str[i]
      if not c:
        if start == i: start++
        continue  // Unicode.
      is-upper/bool := ?
      if 'A' <= c <= 'Z':
        is-upper = true
        if not last-was-upper and i != start:
          // Caml-case cut-point.
          result.add str[start .. i]
          start = i
        else if last-was-upper and COMMON-ABBREVIATIONS.contains str[start .. i]:
          // Cut here, even though it's not finished yet.
          // This happens when we have something like 'HTTPRequest'.
          // Might need to be tweaked a bit more...
          result.add str[start .. i]
          start = i
      else if c == '_' or c == '-' or c == ' ':
        is-upper = false
        if start != i: result.add str[start .. i]
        start = i + 1
      else:
        // We treat all other characters as if they were normal
        // lower-case. Might need tuning.
        is-upper = false
      last-was-upper = is-upper
    if start != str.size: result.add str[start..]
    return result

class GlobalNamer extends Namer:
  used_/Set ::= {}
  class-namers/Map ::= {:}

  reserve name/string --make-unique/bool -> string:
    if make-unique:
      name = unique_ name: used_.contains name
    if used_.contains name:
      throw "Global name already used: $name"
    used_.add name
    return name

  reserve-class-name-for-tag-name tag-name/string -> string:
    return reserve --make-unique
        toit-class-name_ "$(tag-name)Api"

  class-namer class-name/string -> ClassNamer:
    return class-namers.get class-name --init=(: ClassNamer this)

class ClassNamer extends Namer:
  used_/Set ::= {}
  global/GlobalNamer

  constructor .global:

  /** Reservers the given $name, but makes sure it's unique. */
  reserve_ name/string -> string:
    name = unique_ name: used_.contains it
    used_.add name
    return name

  /**
  Reserves the given $name.
  This is for function that exist in the template, and thus
    doesn't make the identifier unique.
  */
  reserve name/string -> string:
    if used_.contains name:
      throw "Name already used: $name"
    used_.add name
    return name

  /**
  Creates a name for the given operation.

  Prefers to use the $Operation.operation-id. If none exists,
    uses a name constructed out of the $path and $method instead.
  */
  reserve-operation path/string method/string op/Operation -> string:
    op-id := op.operation-id
    name := ?
    if op-id:
      return reserve_ op-id
    return reserve_ "$path-$method"

  /**
  Reserves a field-name for the given $tag-name.
  */
  reserve-field-name-for-tag-name tag-name/string -> string:
    return reserve_ tag-name

  /** A namer for a method of the class. */
  fresh-method-namer -> MethodNamer:
    return MethodNamer this

class MethodNamer extends Namer:
  used_/Set ::= {}
  klass/ClassNamer

  constructor .klass:

  reserve_ name/string -> string:
    id := toit-local-name_ name
    unique := unique_ id:
      used_.contains id or
        klass.used_.contains id or
        klass.global.used_.contains id
    used_.add unique
    return unique

  reserve-parameter param/Parameter -> string:
    return reserve_ param.name

class OpenApiGenerator:
  base-dir/string

  constructor --.base-dir:

  gen openapi/OpenApi -> Map:
    namer := GlobalNamer
    // Reserve the import names.
    ["http", "net", "openapi", "core"].do:
      namer.reserve it --no-make-unique
    // Reserve the ApiClient which is always there.
    namer.reserve "ApiClient" --no-make-unique

    api-name := namer.reserve "Api" --no-make-unique

    api-namer := namer.class-namer api-name
    api-namer.reserve "close"

    tag-contexts := {:}
    tag-contexts[""] = {
      "field-name": api-namer.reserve-field-name-for-tag-name "default",
      "class-name": namer.reserve-class-name-for-tag-name "Default",
      "description": "Operations without a tag",
      "operations": [],
    }
    get-tag-context := : | tag-name/string tag/Tag? |
      tag-contexts.get tag-name --init=:
        tag-result := {
          "field-name": api-namer.reserve-field-name-for-tag-name tag-name,
          "class-name": namer.reserve-class-name-for-tag-name tag-name,
          "operations": [],
        }
        if tag:
          tag-result["description"] = tag.description
        tag-result

    (openapi.tags or []).do: | tag/Tag |
      get-tag-context.call tag.name tag

    openapi.paths.paths.do: | path/string path-item/PathItem |
      // We are ignoring the description and summary of the path-item.
      // From what I can see most specs don't have one, and it seems to be ignored by
      // other generators as well.
      PathItem.OPERATION-KINDS.do: | method/string |
        operation := path-item.operation method
        if not operation: continue.do
        // TODO(florian): what if an operation has multiple tags?
        tag := operation.tags.first or ""
        tag-context := get-tag-context.call tag null
        tag-namer := namer.class-namer tag-context["class-name"]
        op-context := gen-operation path method operation tag-namer
        tag-context["operations"].add op-context

    tag-contexts.filter --in-place: | _ context/Map |
      not context["operations"].is-empty
    return {
      "api-name": api-name,
      "apis": tag-contexts.values
    }

  // TODO(florian):
  // -
  gen-operation path/string method/string op/Operation namer/ClassNamer -> Map:
    name := namer.reserve-operation path method op
    method-namer := namer.fresh-method-namer
    parameters := (op.parameters or []).map: | param/Parameter |
      {
        "name": method-namer.reserve-parameter param,
        "description": param.description,
        "required": param.required,
      }


    return {
      "description": op.description,
      "deprecated": op.deprecated,
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
  print context
  dir := fs.dirname system.program-path
  toit-template := (file.read-content "$dir/openapi-template/api.toit").to-string
  mustache-template := template-to-mustache toit-template
  parsed := mustache.parse mustache-template
  rendered := mustache.render parsed --input=context
  file.write-content --path=(fs.join args[1] "api.toit") rendered
