// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Library to create Toit code.
*/

import fs
import io
import host.directory
import host.file

import .namer show GlobalNamer MemberNamer LocalNamer Namer

class WriteContext_:
  indent-level/int := 0
  writer/io.Writer
  is-new-line_/bool := true

  constructor .writer:

  indent-string -> string:
    return "  " * indent-level

  indent -> none:
    indent-level += 1

  dedent -> none:
    indent-level -= 1
    if indent-level < 0:
      throw "INVALID_STATE"

  write str/string -> none:
    if is-new-line_ and str != "":
      writer.write indent-string
      is-new-line_ = false
    writer.write str

  write-line line/string="" -> none:
    write line
    writer.write "\n"
    is-new-line_ = true

interface NodeVisitor:
  visit-Program node/Program -> any
  visit-Library node/Library -> any

  visit-Import node/Import -> any
  visit-Export node/Export -> any

  visit-Class node/Class -> any
  visit-Function node/Function -> any
  visit-Operator node/Function -> any

  visit-VarDefinition node/VarDefinition -> any

  // Statements.
  visit-Sequence node/Sequence -> any
  visit-If node/If -> any
  visit-Return node/Return -> any
  visit-ExpressionStatement node/ExpressionStatement -> any
  visit-LocalDefinition node/LocalDefinition -> any

  // Expressions.
  visit-Call node/Call -> any
  visit-Index node/Index -> any
  visit-Assign node/Assign -> any
  visit-Block node/Block -> any
  visit-Lambda node/Lambda -> any
  visit-Literal node/Literal -> any
  visit-LateInitialized node/LateInitialized -> any
  visit-Ref node/Ref -> any
  visit-ImportedRef node/ImportedRef -> any
  visit-As node/As -> any
  visit-Is node/Is -> any
  visit-Binary node/Binary -> any
  visit-Named node/Named -> any

class TraversingVisitor implements NodeVisitor:
  visit-Program node/Program -> any:
    node.libraries.do: it.accept this
    return null

  visit-Library node/Library -> any:
    node.imports.do: it.accept this
    node.exports.do: it.accept this
    node.classes.do: it.accept this
    node.globals.do: it.accept this
    node.functions.do: it.accept this
    return null

  visit-Import node/Import -> any:
    return null

  visit-Export node/Export -> any:
    node.exports.do: it.accept this
    return null

  visit-Class node/Class -> any:
    node.static-fields.do: it.accept this
    node.static-functions.do: it.accept this
    node.fields.do: it.accept this
    node.members.do: it.accept this
    return null

  visit-Function node/Function -> any:
    node.parameters.do: it.accept this
    if node.return-type: node.return-type.accept this
    if node.body: node.body.accept this
    return null

  visit-Operator node/Function -> any:
    return visit-Function node

  visit-VarDefinition node/VarDefinition -> any:
    if node.initial: node.initial.accept this
    return null

  // Statements.
  visit-Sequence node/Sequence -> any:
    node.statements.do: it.accept this
    return null

  visit-If node/If -> any:
    node.condition.accept this
    node.then-branch.accept this
    if node.else-branch: node.else-branch.accept this
    return null

  visit-Return node/Return -> any:
    if node.value: node.value.accept this
    return null

  visit-ExpressionStatement node/ExpressionStatement -> any:
    node.expression.accept this
    return null

  visit-LocalDefinition node/LocalDefinition -> any:
    node.definition.accept this
    return null

  // Expressions.
  visit-Call node/Call -> any:
    node.target.accept this
    node.arguments.do: it.accept this
    return null

  visit-Index node/Index -> any:
    node.target.accept this
    node.index.accept this
    return null

  visit-Assign node/Assign -> any:
    node.value.accept this
    return null

  visit-Block node/Block -> any:
    node.parameters.do: it.accept this
    node.body.accept this
    return null

  visit-Lambda node/Lambda -> any:
    node.parameters.do: it.accept this
    node.body.accept this
    return null

  visit-Literal node/Literal -> any:
    return null

  visit-LateInitialized node/LateInitialized -> any:
    return null

  visit-Ref node/Ref -> any:
    return null

  visit-ImportedRef node/ImportedRef -> any:
    return null

  visit-As node/As -> any:
    node.expression.accept this
    return null

  visit-Is node/Is -> any:
    node.expression.accept this
    return null

  visit-Binary node/Binary -> any:
    node.left.accept this
    node.right.accept this
    return null

  visit-Named node/Named -> any:
    node.value.accept this
    return null

class FixedNamingVisitor extends TraversingVisitor:
  namers/Map
  current-namer/Namer? := null

  constructor .namers:

  visit-Program node/Program -> any:
    node.libraries.do: | library/Library |
      global-namer := namers.get library --init=: GlobalNamer
      current-namer = global-namer
      library.accept this
      current-namer = null
    return null

  visit-Class node/Class -> any:
    old := current-namer
    if node.name: (old as GlobalNamer).reserve node.name
    member-namer := namers.get node --init=: (old as GlobalNamer).new-member-namer
    current-namer = member-namer
    super node
    current-namer = old
    return null

  visit-Function node/Function -> any:
    old := current-namer
    if node.name:
      if old is MemberNamer: (old as MemberNamer).reserve node.name --check=false --deep=true
      else if old is GlobalNamer: (old as GlobalNamer).reserve node.name --check=false
    local-namer := namers.get node --init=:
      old is MemberNamer ? (old as MemberNamer).new-local-namer : (old as GlobalNamer).new-local-namer
    current-namer = local-namer
    super node
    current-namer = old
    return null

  visit-VarDefinition node/VarDefinition -> any:
    if node.name:
      if current-namer is LocalNamer:
        (current-namer as LocalNamer).reserve node.name --deep=true
      else if current-namer is MemberNamer:
        (current-namer as MemberNamer).reserve node.name --check=false --deep=true
      else if current-namer is GlobalNamer:
        (current-namer as GlobalNamer).reserve node.name
    super node
    return null

class LocalNamingVisitor extends TraversingVisitor:
  namers/Map
  current-namer/Namer? := null

  constructor .namers:

  visit-Program node/Program -> any:
    node.libraries.do: | library/Library |
      current-namer = namers[library]
      library.accept this
      current-namer = null
    return null

  visit-Class node/Class -> any:
    old := current-namer
    current-namer = namers[node]
    super node
    current-namer = old
    return null

  visit-Function node/Function -> any:
    old := current-namer
    current-namer = namers[node]
    super node
    current-namer = old
    return null

  visit-VarDefinition node/VarDefinition -> any:
    if not node.name and current-namer is LocalNamer:
      node.name = (current-namer as LocalNamer).use-local node.preferred-name
    super node
    return null

class UnnamedParamNamingVisitor extends TraversingVisitor:
  namers/Map
  current-namer/Namer? := null

  constructor .namers:

  visit-Program node/Program -> any:
    node.libraries.do: | library/Library |
      current-namer = namers[library]
      library.accept this
      current-namer = null
    return null

  visit-Class node/Class -> any:
    old := current-namer
    current-namer = namers[node]
    super node
    current-namer = old
    return null

  visit-Function node/Function -> any:
    old := current-namer
    current-namer = namers[node]
    super node
    current-namer = old
    return null

  visit-VarDefinition node/VarDefinition -> any:
    if not node.name and current-namer is LocalNamer and not node.is-block and not node.initial and not node.is-named:
      outer := (current-namer as LocalNamer).outer-namer
      if outer is MemberNamer:
        node.name = (outer as MemberNamer).use-member node.preferred-name
      else if outer is GlobalNamer:
        node.name = (outer as GlobalNamer).use-global node.preferred-name
    super node
    return null


class GeneratingVisitor implements NodeVisitor:
  context/WriteContext_
  omit-trailing-newline_/bool := false

  constructor .context:

  needs-parens_ node/Expression -> bool:
    if node is Call:
      c := node as Call
      if not c.arguments.is-empty: return true
      if c.target is Ref:
        target-def := (c.target as Ref).target
        if target-def is Class: return true
        if target-def is Function and (target-def as Function).is-constructor: return true
      return false
    if node is Binary: return true
    if node is As: return true
    if node is Is: return true
    return false

  expr_ node/Expression -> none:
    node.accept this

  visit-Program node/Program -> any:
    unreachable

  visit-Operator node/Function -> any:
    return visit-Function node

  visit-Library node/Library -> any:
    node.imports.do: | imp | if not imp.refs.is-empty: imp.accept this
    if not node.imports.is-empty: context.write-line ""
    node.exports.do: | exp | exp.accept this
    if not node.exports.is-empty: context.write-line ""
    node.globals.do: | glob | glob.accept this
    node.classes.do: | cls | cls.accept this
    node.functions.do: | fun | fun.accept this
    return null

  visit-Import node/Import -> any:
    line := "import "
    if node.is-relative: line += "."
    line += node.segments.join "."
    if node.prefix:
      line += " as $(node.prefix)"

    if node.show-all:
      line += " show *"
    else if not node.refs.is-empty:
      line += " show "
      ref-names := node.refs.map: | ref/ImportedRef | ref.target.name
      line += ref-names.join " "
    context.write-line line
    return null

  visit-Export node/Export -> any:
    line := "export "
    ref-names := node.exports.map: | ref/Ref | ref.target.name
    line += ref-names.join " "
    context.write-line line
    return null

  visit-Class node/Class -> any:
    line := ""
    if node.is-abstract: line += "abstract "
    if node.kind == Class.INTERFACE: line += "interface"
    else if node.kind == Class.MIXIN: line += "mixin"
    else: line += "class"
    line += " $node.name"
    if node.super-class:
      line += " extends $(node.super-class.target.name)"
    line += ":"
    context.write-line line
    context.indent

    node.fields.do: | field/VarDefinition |
      context.write field.name
      if field.type:
        context.write "/$(field.type.target.name)"
        if field.initial:
          if field.is-final: context.write " ::= "
          else: context.write " := "
          expr_ field.initial
        else:
          if not field.is-final: context.write " := ?"
      else:
        if field.initial:
          if field.is-final: context.write " ::= "
          else: context.write " := "
          expr_ field.initial
        else:
          if not field.is-final: context.write " := ?"
          else: context.write " ::= ?"
      context.write-line ""

    node.members.do: | member/Function |
      if member.name == "constructor": context.write-line ""
      member.accept this

    context.dedent
    context.write-line ""
    return null

  visit-Function node/Function -> any:
    line := "$node.name"
    node.parameters.do: | param/VarDefinition |
      param-str := param.name
      if param.is-named: param-str = "--$param-str"
      line += " $param-str"

    if node.name != "constructor":
      if node.return-type:
        line += " -> $(node.return-type.target.name)"

    line += ":"

    context.write-line line
    if node.body:
      context.indent
      node.body.accept this
      context.dedent
    context.write-line ""
    return null

  visit-VarDefinition node/VarDefinition -> any:
    return null

  visit-Sequence node/Sequence -> any:
    old-omit := omit-trailing-newline_
    for i := 0; i < node.statements.size; i++:
      omit-trailing-newline_ = old-omit and i == node.statements.size - 1
      node.statements[i].accept this
    omit-trailing-newline_ = old-omit
    return null

  visit-If node/If -> any:
    context.write "if "
    // We use `write-arg_` to get parenthesis around the condition if it
    // isn't simple. This is over-conservative but handles the case where
    // the condition is a call with a block argument.
    write-arg_ node.condition
    context.write-line ":"
    context.indent
    node.then-branch.accept this
    context.dedent
    if node.else-branch:
      context.write-line "else:"
      context.indent
      node.else-branch.accept this
      context.dedent
    return null

  visit-Return node/Return -> any:
    if node.value:
      context.write "return "
      expr_ node.value
    else:
      context.write "return"
    if not omit-trailing-newline_ and not context.is-new-line_: context.write-line ""
    return null

  visit-ExpressionStatement node/ExpressionStatement -> any:
    expr_ node.expression
    if not omit-trailing-newline_ and not context.is-new-line_: context.write-line ""
    return null

  visit-LocalDefinition node/LocalDefinition -> any:
    def := node.definition
    context.write "$def.name := "
    expr_ def.initial
    if not omit-trailing-newline_ and not context.is-new-line_: context.write-line ""
    return null

  visit-Call node/Call -> any:
    target-parens := needs-parens_ node.target
    if node.method-name and (node.target is Call and not (node.target as Call).method-name and (node.target as Call).arguments.is-empty):
      target-parens = true

    if target-parens: context.write "("
    expr_ node.target
    if target-parens: context.write ")"
    if node.method-name: context.write ".$(node.method-name)"

    if node.arguments.is-empty: return null

    blocks := []
    normal-args := []
    node.arguments.do: | arg |
      if arg is Block: blocks.add arg
      else if arg is Named and (arg as Named).value is Block: blocks.add arg
      else: normal-args.add arg

    multi-block := blocks.size > 1
    if not normal-args.is-empty:
      if multi-block:
        // In multi-block mode, put all args on continuation lines.
        normal-args.do: | arg |
          context.write "\n$(context.indent-string)    "
          write-arg_ arg
      else:
        has-named := normal-args.any: it is Named
        if normal-args.size > 2 and has-named:
          context.write " "
          write-arg_ normal-args[0]
          for i := 1; i < normal-args.size; i++:
            context.write "\n$(context.indent-string)    "
            write-arg_ normal-args[i]
        else:
          normal-args.do: | arg |
            context.write " "
            write-arg_ arg

    for i := 0; i < blocks.size; i++:
      blk := blocks[i]
      if multi-block:
        // Each block on its own line, indented by 4 from the call.
        context.write "\n$(context.indent-string)    "
      if blk is Named:
        n-blk := blk as Named
        if multi-block or i > 0:
          context.write "--$(n-blk.parameter.name)="
        else:
          context.write " --$(n-blk.parameter.name)="
        blk = n-blk.value

      b := blk as Block
      context.write ":"
      if not b.parameters.is-empty:
        p-names := b.parameters.map: it.name
        context.write " | $(p-names.join " ") |"

      if multi-block:
        // Body at +4 from block header. Always omit trailing newline
        // to prevent blank lines between blocks.
        context.indent-level += 2
        stream-block-body_ b.body true
        context.indent-level -= 2
      else:
        is-last := i == blocks.size - 1
        stream-block-body_ b.body is-last

    return null

  visit-Index node/Index -> any:
    if needs-parens_ node.target: context.write "("
    expr_ node.target
    if needs-parens_ node.target: context.write ")"
    context.write "["
    expr_ node.index
    context.write "]"
    return null

  visit-Assign node/Assign -> any:
    context.write "$node.target.name = "
    expr_ node.value
    return null

  visit-Block node/Block -> any:
    unreachable

  visit-Lambda node/Lambda -> any:
    context.write "::"
    if not node.parameters.is-empty:
      p-names := node.parameters.map: it.name
      context.write " | $(p-names.join " ") |"

    stream-block-body_ node.body true
    return null

  visit-Literal node/Literal -> any:
    v := node.value
    if v is string: context.write "\"$v\""
    else if v is int or v is float or v is bool: context.write "$v"
    else if v == null: context.write "null"
    else if v is List and v.is-empty: context.write "[]"
    else if v is Map and v.is-empty: context.write "{:}"
    else: unreachable
    return null

  visit-LateInitialized node/LateInitialized -> any:
    context.write "?"
    return null

  visit-Ref node/Ref -> any:
    context.write node.target.name
    return null

  visit-ImportedRef node/ImportedRef -> any:
    if node.imp.prefix: context.write "$node.imp.prefix.$node.target.name"
    else: context.write node.target.name
    return null

  visit-As node/As -> any:
    if needs-parens_ node.expression: context.write "("
    expr_ node.expression
    if needs-parens_ node.expression: context.write ")"
    context.write " as $node.type.name"
    return null

  visit-Is node/Is -> any:
    if needs-parens_ node.expression: context.write "("
    expr_ node.expression
    if needs-parens_ node.expression: context.write ")"
    context.write " is $node.type.name"
    return null

  visit-Binary node/Binary -> any:
    write-arg_ node.left
    context.write " $node.op "
    write-arg_ node.right
    return null

  visit-Named node/Named -> any:
    context.write "--$node.parameter.name="
    expr_ node.value
    return null

  write-arg_ arg/Expression -> none:
    if needs-parens_ arg:
      context.write "("
      expr_ arg
      context.write ")"
    else:
      expr_ arg

  stream-block-body_ body/Statement omit/bool -> none:
    context.write-line ""
    context.indent
    old-omit := omit-trailing-newline_
    omit-trailing-newline_ = omit
    body.accept this
    omit-trailing-newline_ = old-omit
    context.dedent

next-hash-code_ := 0

interface Node:
  hash-code -> int
  operator == other/any -> bool
  accept visitor/NodeVisitor -> any

abstract class BaseNode_ implements Node:
  hash-code/int ::= next-hash-code_++
  abstract accept visitor/NodeVisitor -> any
  operator == other/any -> bool:
    return identical this other

class Program extends BaseNode_:
  libraries/List ::= []

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Program this

  assign-names_ -> none:
    namers := {:}
    // Phase 1: Reserve fixed (pre-assigned) names.
    this.accept (FixedNamingVisitor namers)

    // Phase 2: Assign class and global variable names.
    libraries.do: | library/Library |
      global-namer/GlobalNamer := namers[library]
      library.classes.do: | cls/Class |
        if not cls.name:
          cls.name = global-namer.use-class cls.preferred-name
      library.globals.do: | g/VarDefinition |
        if not g.name:
          g.name = global-namer.use-global g.preferred-name

    // Phase 3: Assign function names, field names, and static field names.
    // Uses shared naming so that overloaded functions and fields with
    // the same preferred name get the same assigned name.
    libraries.do: | library/Library |
      global-namer/GlobalNamer := namers[library]
      global-cache := {:}
      library.functions.do: | fun/Function |
        if not fun.name:
          fun.name = global-namer.use-shared-global fun.preferred-name --cache=global-cache
      library.classes.do: | cls/Class |
        member-namer/MemberNamer := namers[cls]
        member-cache := {:}
        cls.members.do: | fun/Function |
          if not fun.name:
            fun.name = member-namer.use-shared-member fun.preferred-name --private=fun.is-static --cache=member-cache
        cls.static-functions.do: | fun/Function |
          if not fun.name:
            fun.name = member-namer.use-shared-member fun.preferred-name --private=fun.is-static --cache=member-cache
        cls.fields.do: | field/VarDefinition |
          if not field.name:
            field.name = member-namer.use-shared-member field.preferred-name --cache=member-cache
        cls.static-fields.do: | field/VarDefinition |
          if not field.name:
            field.name = member-namer.use-shared-member field.preferred-name --cache=member-cache

    // Phase 4: Assign named parameter names.
    // Uses shared naming so overloaded functions with the same named
    // parameter get the same assigned parameter name.
    libraries.do: | library/Library |
      global-namer/GlobalNamer := namers[library]
      global-param-cache := {:}
      library.functions.do: | fun/Function |
        fun.parameters.do: | param/VarDefinition |
          if not param.name and param.is-named:
            param.name = global-namer.use-shared-global param.preferred-name --cache=global-param-cache
      library.classes.do: | cls/Class |
        member-namer/MemberNamer := namers[cls]
        member-param-cache := {:}
        cls.members.do: | fun/Function |
          fun.parameters.do: | param/VarDefinition |
            if not param.name and param.is-named:
              param.name = member-namer.use-shared-member param.preferred-name --cache=member-param-cache
        cls.static-functions.do: | fun/Function |
          fun.parameters.do: | param/VarDefinition |
            if not param.name and param.is-named:
              param.name = member-namer.use-shared-member param.preferred-name --cache=member-param-cache

    // Phase 5: Assign unnamed, non-block parameter names.
    this.accept (UnnamedParamNamingVisitor namers)

    // Phase 6: Assign prefixes and remaining local names.
    // Collect all already-assigned names to ensure prefixes don't
    // clash with any name in any scope.
    all-names := {}
    namers.do: | _ namer/Namer |
      all-names.add-all namer.used-names
    libraries.do: | library/Library |
      global-namer/GlobalNamer := namers[library]
      library.imports.do: | imp/Import |
        if imp.preferred-prefix:
          imp.prefix = global-namer.use-prefix imp.preferred-prefix
              --also-avoid=all-names
    this.accept (LocalNamingVisitor namers)

  gen -> none:
    assign-names_
    libraries.do: | library/Library |
      path := library.path
      dir := fs.dirname path
      if not file.is-directory dir:
        if file.is-file dir:
          throw "Cannot create directory $dir: A file with that name exists."
        directory.mkdir --recursive dir
      stream := file.Stream.for-write path
      context := WriteContext_ stream.out
      library.gen_ context
      stream.close

  gen --in-memory/True -> Map:
    assign-names_
    result := {:}
    libraries.do: | library/Library |
      buffer := io.Buffer
      context := WriteContext_ buffer
      library.gen_ context
      code := buffer.to-string
      result[library.path] = code
    return result

class Library extends BaseNode_:
  path/string
  imports/List ::= []  // Of Import.
  exports/List ::= []  // Of Export.
  statics/List ::= []
  classes/List ::= []  // Of Class.
  globals/List ::= []  // Of VarDefinition.
  functions/List ::= []  // Of Function.

  constructor .path:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Library this

  gen_ context/WriteContext_ -> none:
    visitor := GeneratingVisitor context
    visitor.visit-Library this

class Import extends BaseNode_:
  is-relative/bool
  segments/List  // Of string.
  preferred-prefix/string? := null
  prefix/string? := null
  show-all/bool
  refs/List ::= []  // Of ImportedRef.

  constructor .segments
      --.preferred-prefix=null
      --.is-relative=false
      --.show-all=false:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Import this

  is-core -> bool:
    return segments.size == 1 and segments[0] == "core"

class Export extends BaseNode_:
  exports/List ::= []  // Of Ref.

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Export this

class Class extends BaseNode_ implements RefTarget:
  static CLASS ::= 0
  static INTERFACE ::= 1
  static MIXIN ::= 2

  kind/int
  preferred-name/string
  name/string? := null
  fields/List ::= []  // Of VarDefinition.
  members/List ::= []  // Of Function.
  static-fields/List ::= []
  static-functions/List ::= []
  is-abstract/bool
  super-class/Ref?

  constructor .preferred-name --.is-abstract=false --.kind --.super-class=null:

  /**
  A core class.

  Should only be used as a $RefTarget. As such, most of the fields don't matter.
  */
  constructor.core .name/string:
    kind = CLASS
    preferred-name = name
    is-abstract = false
    super-class = null

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Class this

class Function extends BaseNode_ implements RefTarget:
  preferred-name/string
  name/string? := null
  parameters/List ::= []  // Of VarDefinition.
  return-type/Ref?
  body/Statement? := null
  is-abstract/bool
  is-static/bool
  is-constructor/bool := false

  constructor .preferred-name
      --.parameters
      --.return-type
      --.is-abstract=false
      --.is-static=false
      .body=null:

  constructor.constr --.parameters --name/string?=null .body=null:
    if not name:
      preferred-name = "constructor"
      this.name = "constructor"
    else:
      preferred-name = name
    is-abstract = false
    is-static = false
    return-type = null
    is-constructor = true

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Function this

class Operator extends Function:
  operator-string/string

  constructor .operator-string --parameters/List --return-type/Ref?=null --is-abstract/bool=false body/Statement?:
    op-name := "operator $operator-string"
    super op-name
        --parameters=parameters
        --return-type=return-type
        --is-abstract=is-abstract
        body

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Operator this

class VarDefinition extends BaseNode_ implements RefTarget:
  preferred-name/string
  name/string? := null
  type/Ref?
  initial/Expression?
  is-nullable/bool  // Only used if $type is not null.
  is-block/bool
  is-named/bool
  is-final/bool

  constructor.parameter .preferred-name
      --.type=null
      --.initial=null
      --.is-block=false
      --.is-named=false
      --.is-nullable=false
      --.is-final=false:

  constructor.ignored:
    preferred-name = "_"
    name = "_"
    is-block = false
    is-named = false
    is-nullable = false
    initial = null
    type = null
    is-final = false

  constructor.it:
    preferred-name = "it"
    name = "it"
    is-block = false
    is-named = false
    is-nullable = false
    initial = null
    type = null
    is-final = false

  constructor.local .preferred-name
      --.type=null
      --.is-nullable=false
      --.is-final=false
      --.initial/Expression:
    is-block = false
    is-named = false

  constructor.field .preferred-name
      --.type=null
      --.is-nullable=false
      --.is-final=true
      --.initial/Expression?:
    is-block = false
    is-named = false

  accept visitor/NodeVisitor -> any:
    return visitor.visit-VarDefinition this

/**
A Toit statement.

Strictly speaking, Toit doesn't have the distinction between
  statements and expressions.
In practice, however, some constructs clearly are only used in
  statement-like positions.
*/
abstract class Statement extends BaseNode_:
  constructor expr/Expression:
    return ExpressionStatement expr

  constructor:

  abstract accept visitor/NodeVisitor -> any

class Sequence extends Statement:
  statements/List ::= []  // Of Statement.

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Sequence this

  add statement/Statement -> none:
    statements.add statement

  define preferred-name/string -> VarDefinition
      --type/Ref?=null
      initial/Expression:
    definition := VarDefinition.local preferred-name
        --initial=initial
        --type=type
    add (LocalDefinition definition)
    return definition

  call target/Expression -> none:
    call target --arguments=[]

  call target/Expression arg0/Expression -> none:
    call target --arguments=[arg0]

  call target/Expression arg0/Expression arg1/Expression -> none:
    call target --arguments=[arg0, arg1]

  call target/Expression --arguments/List -> none:
    expr := Call target --arguments=arguments
    add (Statement expr)

  iff condition/Expression then-branch/Statement else-branch/Statement?=null -> none:
    if-statement := If condition then-branch else-branch
    add if-statement

  ret value/Expression?=null -> none:
    return-statement := Return value
    add return-statement

  assign target/RefTarget value/Expression -> none:
    assign := Assign target value
    add (Statement assign)

class If extends Statement:
  condition/Expression
  then-branch/Statement
  else-branch/Statement? := null

  constructor .condition .then-branch .else-branch=null:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-If this

class Return extends Statement:
  value/Expression? := null

  constructor .value=null:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Return this

class ExpressionStatement extends Statement:
  expression/Expression

  constructor .expression:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-ExpressionStatement this

class LocalDefinition extends Statement:
  definition/VarDefinition

  constructor .definition:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-LocalDefinition this


abstract class Expression extends BaseNode_:
  abstract accept visitor/NodeVisitor -> any

class Call extends Expression:
  target/Expression
  method-name/string? := null
  arguments/List  // Of Expression.

  constructor .target .method-name=null --.arguments=[]:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Call this

class Index extends Expression:
  target/Expression
  index/Expression

  constructor .target .index:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Index this

class Assign extends Expression:
  target/RefTarget
  value/Expression

  constructor .target .value:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Assign this

class Block extends Expression:
  parameters/List  // Of VarDefinition.
  body/Statement

  constructor .body --.parameters=[]:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Block this

class Lambda extends Expression:
  parameters/List  // Of VarDefinition.
  body/Statement

  constructor .body --.parameters=[]:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Lambda this

class Literal extends Expression:
  value/any

  constructor .value:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Literal this

class LateInitialized extends Expression:
  accept visitor/NodeVisitor -> any:
    return visitor.visit-LateInitialized this

interface RefTarget:
  name -> string?

class Ref extends Expression:
  target/RefTarget

  constructor .target:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Ref this

class ImportedRef extends Ref:
  imp/Import

  constructor .imp target/RefTarget:
    super target
    imp.refs.add this

  accept visitor/NodeVisitor -> any:
    return visitor.visit-ImportedRef this

class As extends Expression:
  expression/Expression
  type/RefTarget

  constructor .expression .type:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-As this

class Is extends Expression:
  expression/Expression
  type/RefTarget

  constructor .expression .type:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Is this

class Binary extends Expression:
  left/Expression
  op/string
  right/Expression

  constructor .left .op .right:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Binary this

class Named extends Expression:
  parameter/VarDefinition
  value/Expression

  constructor .parameter .value:

  accept visitor/NodeVisitor -> any:
    return visitor.visit-Named this
