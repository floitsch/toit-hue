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

  constructor .writer/io.Writer:

  indent -> none:
    indent-level += 1

  dedent -> none:
    indent-level -= 1
    if indent-level < 0:
      throw "INVALID_STATE"

  write-line line/string -> none:
    writer.write "  " * indent-level
    writer.write line
    writer.write "\n"

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
      if old is MemberNamer: (old as MemberNamer).reserve node.name --deep=true
      else if old is GlobalNamer: (old as GlobalNamer).reserve node.name
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
        (current-namer as MemberNamer).reserve node.name --deep=true
      else if current-namer is GlobalNamer:
        (current-namer as GlobalNamer).reserve node.name
    super node
    return null

class PublicNamingVisitor extends TraversingVisitor:
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
    if not node.name: node.name = (old as GlobalNamer).use-class node.preferred-name
    member-namer := namers[node]
    current-namer = member-namer
    super node
    member-namer.used-names.do: | member-name/string |
      if not (old as GlobalNamer).used-names.contains member-name:
        (old as GlobalNamer).reserve member-name --deep=false --check=false
    current-namer = old
    return null

  visit-Function node/Function -> any:
    old := current-namer
    if not node.name:
      if old is MemberNamer:
        node.name = (old as MemberNamer).use-member node.preferred-name --private=node.is-static
      else if old is GlobalNamer:
        node.name = (old as GlobalNamer).use-global node.preferred-name
    current-namer = namers[node]
    super node
    current-namer = old
    return null

  visit-VarDefinition node/VarDefinition -> any:
    if not node.name:
      if current-namer is GlobalNamer:
        node.name = (current-namer as GlobalNamer).use-global node.preferred-name
      else if current-namer is MemberNamer:
        node.name = (current-namer as MemberNamer).use-member node.preferred-name
      else if current-namer is LocalNamer and node.is-named:
        outer := (current-namer as LocalNamer).outer-namer
        if outer is MemberNamer:
          node.name = (outer as MemberNamer).use-member node.preferred-name
        else if outer is GlobalNamer:
          node.name = (outer as GlobalNamer).use-global node.preferred-name
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

class RemainingNamingVisitor extends TraversingVisitor:
  namers/Map
  current-namer/Namer? := null

  constructor .namers:

  visit-Program node/Program -> any:
    node.libraries.do: | library/Library |
      current-namer = namers[library]
      library.accept this
      current-namer = null
    return null

  visit-Import node/Import -> any:
    if node.preferred-prefix:
      node.prefix = (current-namer as GlobalNamer).use-prefix node.preferred-prefix
    super node
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
    this.accept (FixedNamingVisitor namers)
    this.accept (PublicNamingVisitor namers)
    this.accept (UnnamedParamNamingVisitor namers)
    this.accept (RemainingNamingVisitor namers)

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
    imports.do: | imp/Import |
      if imp.refs.is-empty: continue.do
      line := "import "
      if imp.is-relative:
        line += "."
      line += imp.segments.join "."
      if imp.show-all:
        line += " show *"
      else if imp.prefix:
        line += " as $imp.prefix"
      else:
        line += " show "
        ref-names := imp.refs.map: | ref/Ref | ref.target.name
        line += ref-names.join " "
      context.write-line line

    // TODO(florian): implement rest.

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

class Function extends BaseNode_:
  preferred-name/string
  name/string? := null
  parameters/List ::= []  // Of VarDefinition.
  return-type/Ref?
  body/Statement? := null
  is-abstract/bool
  is-static/bool

  constructor .preferred-name
      --.parameters
      --.return-type
      --.is-abstract=false
      --.is-static=false
      .body=null:

  constructor.constr --.parameters .body=null:
    preferred-name = "constructor"
    name = "constructor"
    is-abstract = false
    is-static = false
    return-type = null

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
