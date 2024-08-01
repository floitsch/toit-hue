import encoding.yaml
import host.file
import io
import .openapi

interface Fs:
  create-file path/string -> io.CloseableWriter

class FsDisk implements Fs:
  create-file path/string -> io.CloseableWriter:
    stream := file.Stream.for-write path
    return stream.out


class GlobalNamer:
  used-globals_/Set ::= {}
  globals_/IdentityMap ::= IdentityMap

  reserve name/string -> none:
    if used-globals_.contains name:
      throw "Global name already used: $name"
    used-globals_.add name

  klass -> ClassNamer:
    return ClassNamer this

class ClassNamer:
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
    name = name.replace --all "/" "-"
    name = name.replace --all " " "-"
    return name

  method->MethodNamer:
    return MethodNamer this

class MethodNamer:
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
  fs/Fs
  base-dir/string

  constructor .fs --.base-dir:

  gen openapi/OpenApi:
    namer := GlobalNamer
    namer.reserve "Client"

    client-namer := namer.klass
    client-namer.reserve-static "URL"

    writer := fs.create-file "$base-dir/client.toit"
    url := openapi.url
    writer.write """
      // import openapi

      class Client:
        static URL ::= $(url ? "\"$url\"" : "null")
      """
    openapi.paths.paths.do: | path/string path-item/PathItem |
      // We are ignoring the description and summary of the path-item.
      // From what I can see most specs don't have one, and it seems to be ignored by
      // other generators as well.
      gen-operation path "get" path-item.get writer client-namer

    writer.close

  gen-operation path/string method/string op/Operation? writer/io.Writer namer/ClassNamer:
    if not op: return
    name := namer.for-operation path method op
    method-namer := namer.method
    parameters := (op.parameters or []).map: | param/Parameter |
      method-namer.for-parameter param

    writer.write """
        $name $(parameters.join " "):
          // TODO(florian): implement
          throw "Not implemented"
      """

main args/List:
  if args.size != 2:
    print "Usage: openapi-to-toit <openapi.json> <output-dir>"
    return
  openapi := build (yaml.decode (file.read-content args[0]))
  fs := FsDisk
  (OpenApiGenerator fs --base-dir=args[1]).gen openapi
