import encoding.yaml
import fs
import host.file
import host.directory
import io
import json-schema
import json-schema.schema as json-schema
import json-schema.action as schema-action
import mustache
import namer
import system

import .openapi

class Namer:
  unique_ name/string [block] -> string:
    return namer.unique name --is-reserved=block

  toit-local-name_ name/string -> string:
    return namer.toit-local-name name

  toit-class-name_ name/string -> string:
    return namer.toit-class-name name

  to-kebab-case_ name/string -> string:
    return namer.to-kebab-case name

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
      return reserve_ (to-kebab-case_ op-id)
    return reserve_ "$path-$method"

  /**
  Reserves a field-name for the given $tag-name.
  */
  reserve-field-name-for-tag-name tag-name/string -> string:
    return reserve_ (to-kebab-case_ tag-name)

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

class JsonSchemaGenerator:
  namer/Namer := Namer
  referenced-schemas/Map ::= {:}

  use open-api-schema/Schema? --hint/string -> string:
    if not open-api-schema: return "any"
    json-schema := open-api-schema.schema.schema

    if referenced-schemas.contains json-schema:
      return referenced-schemas[json-schema]

    simple-type := simple-type-of json-schema
    if simple-type: return simple-type

    name := hint
    if json-schema.is-reference-only:
      target-uri := json-schema.reference-target-uri
      // TODO(florian): avoid name clashes.
      print target-uri.fragment
      json-schema-name := (target-uri.fragment.split "%2F").last
      name = namer.toit-class-name_ json-schema-name
      print "ref-only: $name"

    referenced-schemas[json-schema] = name
    return name

  simple-type-of schema/json-schema.Schema -> string?:
    // TODO(florian): handle enum.
    schema.actions.do: | action/schema-action.Action |
      if action is schema-action.Type:
        type-action := action as schema-action.Type
        accepted-types := type-action.types
        if accepted-types.size != 1: return null
        type := accepted-types.first
        if type == "integer": return "int"
        if type == "number": return "num"
        if type == "string": return "string"
        if type == "boolean": return "bool"
        if type == "null": return "none"
        if type == "array": return "List"
        if type == "object": return "Map"
        return null
    return null

class OpenApiGenerator:
  base-dir/string
  json-schema-gen/JsonSchemaGenerator

  current-path/string? := null
  current-method/string? := null

  constructor --.base-dir --.json-schema-gen:

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
      current-path = path
      // We are ignoring the description and summary of the path-item.
      // From what I can see most specs don't have one, and it seems to be ignored by
      // other generators as well.
      PathItem.OPERATION-KINDS.do: | method/string |
        operation := path-item.operation method
        if not operation: continue.do
        current-method = method
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

  gen-operation path/string method/string op/Operation namer/ClassNamer -> Map:
    name := namer.reserve-operation path method op
    method-namer := namer.fresh-method-namer
    // For each operation we have a '--raw' version.
    method-namer.reserve_ "raw"
    has-cookie-params/bool := false
    parameters := (op.parameters or []).map: | param/Parameter |
      if param.in == Parameter.COOKIE: has-cookie-params = true
      type-hint := "$current-path-$current-method-$param.name"
      result := {
        "name": method-namer.reserve-parameter param,
        "description": param.description,
        "required": param.required,
        "original-name": param.name,
        "in-path": param.in == Parameter.PATH,
        "in-query": param.in == Parameter.QUERY,
        "in-header": param.in == Parameter.HEADER,
        "in-cookie": param.in == Parameter.COOKIE,
        "style": param.style,
        "explode": param.explode,
        "type": json-schema-gen.use param.schema --hint=type-hint,
      }
    request-body/Map? := null
    if op.request-body:
      resolved := op.request-body.resolved-request-body
      content := resolved.content
      type := ?
      if content.contains "application/json":
        type = json-schema-gen.use content["application/json"].schema
          --hint="$current-path-$(current-method)-request-body"
      else:
        type = "ByteArray"
      request-body = {
        "description": resolved.description,
        "name": method-namer.reserve_ "body",
        "type": type,
      }

    return {
      "method": "\$http.$(method.to-ascii-upper)",
      "path": path,
      "description": op.description,
      "deprecated": op.deprecated,
      "name": name,
      "parameters": parameters,
      "request-body": request-body,
      "tags": op.tags,
      "has-cookie-params": has-cookie-params,
    }

main args/List:
  if args.size != 2:
    print "Usage: openapi-to-toit <openapi.yaml> <output-dir>"
    return
  openapi := build (yaml.decode (file.read-content args[0]))
  json-schema-gen := JsonSchemaGenerator
  open-api-gen := OpenApiGenerator --base-dir=args[1] --json-schema-gen=json-schema-gen
  context := open-api-gen.gen openapi
  dir := fs.dirname system.program-path
  toit-template := (file.read-content "$dir/openapi-template/api.toit").to-string
  mustache-template := mustache.comment-template-to-mustache toit-template
  parsed := mustache.parse mustache-template
  rendered := mustache.render parsed --input=context
  directory.mkdir --recursive (fs.join args[1] "src")
  file.write-content --path=(fs.join args[1] "src" "api.toit") rendered
