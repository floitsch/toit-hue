// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Library to create Toit code.
*/

import .namer

class Program:
  libraries/List ::= []

class Library:
  path/string
  imports/List ::= []  // Of Import.
  statics/List ::= []
  classes/List ::= []  // Of Class.

  constructor .path:

interface RefTarget:

abstract class Expression:

class Local implements RefTarget:

class Ref extends Expression:
  target/RefTarget

  constructor .target:

class Named extends Expression:
  parameter/VarDefinition
  value/Expression

  constructor .parameter .value:

class Import:
  is-relative/bool
  segments/List  // Of string.
  show-all/bool
  show/List ::= []  // Of Ref.

  constructor .segments --.is-relative=false --.show-all=false:

class Export:
  exports/List ::= []  // Of Ref.

class Class implements RefTarget:
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

class Function:
  name/string
  parameters/List ::= []  // Of VarDefinition.
  return-type/Ref?
  body/Statement? := null
  is-abstract/bool

  constructor .name --.parameters --.return-type --.is-abstract=false .body=null:

class Operator extends Function:
  operator-string/string

  constructor .operator-string --parameters/List --return-type/Ref?=null --is-abstract/bool=false body/Statement?:
    op-name := "operator $operator-string"
    super op-name
        --parameters=parameters
        --return-type=return-type
        --is-abstract=is-abstract
        body

class VarDefinition implements RefTarget:
  preferred-name/string
  name/string? := null
  type/Ref?
  initial/Expression?
  is-nullable/bool  // Only used if $type is not null.
  is-block/bool
  is-named/bool

  constructor.parameter .preferred-name
      --.type=null
      --.initial=null
      --.is-block=false
      --.is-named=false
      --.is-nullable=false:

  constructor.ignored:
    preferred-name = "_"
    name = "_"
    is-block = false
    is-named = false
    is-nullable = false
    initial = null
    type = null

  constructor.it:
    preferred-name = "it"
    name = "it"
    is-block = false
    is-named = false
    is-nullable = false
    initial = null
    type = null

  constructor.local .preferred-name
      --.type=null
      --.is-nullable=false
      --.initial/Expression:
    is-block = false
    is-named = false

class Call extends Expression:
  target/Expression
  method-name/string? := null
  arguments/List  // Of Expression.

  constructor .target .method-name=null --.arguments=[]:

class Block extends Expression:
  parameters/List  // Of VarDefinition.
  body/Statement

  constructor .body --.parameters=[]:

class Lambda extends Expression:
  parameters/List  // Of VarDefinition.
  body/Statement

  constructor .body --.parameters=[]:

/**
A Toit statement.

Strictly speaking, Toit doesn't have the distinction between
  statements and expressions.
In practice, however, some constructs clearly are only used in
  statement-like positions.
*/
abstract class Statement:
  constructor expr/Expression:
    return ExpressionStatement expr

  constructor:

class Sequence extends Statement:
  statements/List ::= []  // Of Statement.

  define preferred-name/string --type/Ref?=null initial/Expression -> VarDefinition:
    definition := VarDefinition.local preferred-name --initial=initial --type=type
    statements.add definition
    return definition

  call target/Expression -> none:
    call target --arguments=[]

  call target/Expression arg0/Expression -> none:
    call target --arguments=[arg0]

  call target/Expression arg0/Expression arg1/Expression -> none:
    call target --arguments=[arg0, arg1]

  call target/Expression --arguments/List -> none:
    expr := Call target --arguments=arguments
    statements.add expr

  iff condition/Expression then-branch/Statement else-branch/Statement?=null:
    if-statement := If condition then-branch else-branch
    statements.add if-statement

  ret value/Expression?=null:
    return-statement := Return value
    statements.add return-statement

class If extends Statement:
  condition/Expression
  then-branch/Statement
  else-branch/Statement? := null

  constructor .condition .then-branch .else-branch=null:

class Return extends Statement:
  value/Expression? := null

  constructor .value=null:

class ExpressionStatement extends Statement:
  expression/Expression

  constructor .expression:

