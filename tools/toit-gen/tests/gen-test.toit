// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *
import toit-gen

main:
  test-basic-class
  test-nested-calls
  test-block-vs-named
  test-constructor-shortcut
  test-cascading-calls
  test-classes-and-mixins
  test-control-flow
  test-expressions
  test-imports-and-exports
  test-nested-expressions
  test-nested-blocks-and-lambdas
  test-multiple-blocks
  test-toitdocs
  test-toitdoc-class
  test-toitdoc-field
  test-toitdoc-function
  test-toitdoc-member-params
  test-toitdoc-exact-named-block

test-basic-class:
  cls := toit-gen.Class "MyClass" --kind=toit-gen.Class.CLASS
  fun := toit-gen.Function "myMethod" --parameters=[] --return-type=null
  cls.members.add fun

  seq := toit-gen.Sequence
  seq.add (toit-gen.Return (toit-gen.Literal 42))
  fun.body = seq

  lib := toit-gen.Library "test.toit"
  lib.classes.add cls

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test.toit"]

  expected := """
    class MyClass:
      my-method:
        return 42"""
  expect-equals expected code.trim

test-nested-calls:
  fun1 := toit-gen.Function "my-function" --parameters=[] --return-type=null
  fun1.name = "my-function"
  fun2 := toit-gen.Function "other-function" --parameters=[] --return-type=null
  fun2.name = "other-function"

  call2 := toit-gen.Call (toit-gen.Ref fun2) --arguments=[toit-gen.Literal 1, toit-gen.Literal 2]
  call1 := toit-gen.Call (toit-gen.Ref fun1) --arguments=[call2]

  seq1 := toit-gen.Sequence
  seq1.add (toit-gen.ExpressionStatement call1)

  lib1 := toit-gen.Library "test1.toit"
  fun-wrap1 := toit-gen.Function "wrap1" --parameters=[] --return-type=null
  fun-wrap1.body = seq1
  lib1.functions.add fun-wrap1

  call3 := toit-gen.Call (toit-gen.Ref fun2) --arguments=[toit-gen.Literal 2]
  binary := toit-gen.Binary (toit-gen.Literal 1) "+" call3
  call4 := toit-gen.Call (toit-gen.Ref fun1) --arguments=[binary]

  seq2 := toit-gen.Sequence
  seq2.add (toit-gen.ExpressionStatement call4)

  fun-wrap2 := toit-gen.Function "wrap2" --parameters=[] --return-type=null
  fun-wrap2.body = seq2
  lib1.functions.add fun-wrap2

  program := toit-gen.Program
  program.libraries.add lib1

  generated := program.gen --in-memory
  code := generated["test1.toit"]

  expected := """
    wrap1:
      my-function (other-function 1 2)

    wrap2:
      my-function (1 + (other-function 2))"""
  expect-equals expected code.trim

test-block-vs-named:
  list-ref-var := toit-gen.VarDefinition.local "list" --initial=(toit-gen.Literal [])
  list-ref-var.name = "list"
  list-ref := toit-gen.Ref list-ref-var

  item-param := toit-gen.VarDefinition.parameter "item" --is-block=true
  item-param.name = "item"
  lambda-body := toit-gen.Return (toit-gen.Binary (toit-gen.Ref item-param) "+" (toit-gen.Literal 1))
  block := toit-gen.Block lambda-body --parameters=[item-param]
  call-block := toit-gen.Call list-ref "map" --arguments=[block]

  method-def := toit-gen.Function "my-method" --parameters=[] --return-type=null
  method-def.name = "my-method"
  method-ref := toit-gen.Ref method-def
  arg1 := toit-gen.Literal "arg1"
  param1 := toit-gen.VarDefinition.parameter "named1" --is-named=true
  param1.name = "named1"
  named1 := toit-gen.Named param1 (toit-gen.Literal "foo")
  param2 := toit-gen.VarDefinition.parameter "named2" --is-named=true
  param2.name = "named2"
  named2 := toit-gen.Named param2 (toit-gen.Literal "bar")
  call-named := toit-gen.Call method-ref --arguments=[arg1, named1, named2]

  seq := toit-gen.Sequence
  seq.add (toit-gen.ExpressionStatement call-block)
  seq.add (toit-gen.ExpressionStatement call-named)

  lib := toit-gen.Library "test2.toit"
  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test2.toit"]

  expected := """
    wrap:
      list.map: | item |
        return item + 1
      my-method "arg1"
          --named1="foo"
          --named2="bar""""
  expect-equals expected code.trim

test-constructor-shortcut:
  cls := toit-gen.Class "Foo" --kind=toit-gen.Class.CLASS
  // field_/int
  field := toit-gen.VarDefinition.field "field_" --type=(toit-gen.Ref (toit-gen.Class.core "int")) --initial=null --is-final=true
  cls.fields.add field

  // field2/int := ?
  field2 := toit-gen.VarDefinition.field "field2" --type=(toit-gen.Ref (toit-gen.Class.core "int")) --initial=null --is-final=false
  cls.fields.add field2

  // field3/int ::= 42
  field3 := toit-gen.VarDefinition.field "field3" --type=(toit-gen.Ref (toit-gen.Class.core "int")) --initial=(toit-gen.Literal 42) --is-final=true
  cls.fields.add field3

  // field4/int := 43
  field4 := toit-gen.VarDefinition.field "field4" --type=(toit-gen.Ref (toit-gen.Class.core "int")) --initial=(toit-gen.Literal 43) --is-final=false
  cls.fields.add field4

  // field5 ::= ?
  field5 := toit-gen.VarDefinition.field "field5" --initial=null
  cls.fields.add field5

  // field6 ::= 44
  field6 := toit-gen.VarDefinition.field "field6" --initial=(toit-gen.Literal 44) --is-final=true
  cls.fields.add field6

  // field7 := 45
  field7 := toit-gen.VarDefinition.field "field7" --initial=(toit-gen.Literal 45) --is-final=false
  cls.fields.add field7

  // field8 := ?
  field8 := toit-gen.VarDefinition.field "field8" --initial=null --is-final=false
  cls.fields.add field8

  param := toit-gen.VarDefinition.parameter ".field_"
  param.name = ".field_"

  param2 := toit-gen.VarDefinition.parameter ".field2"
  param2.name = ".field2"

  param5 := toit-gen.VarDefinition.parameter ".field5"
  param5.name = ".field5"

  param8 := toit-gen.VarDefinition.parameter ".field8"
  param8.name = ".field8"

  constr := toit-gen.Function.constr --parameters=[param, param2, param5, param8]
  cls.members.add constr

  seq := toit-gen.Sequence
  x-def := seq.define "x" (toit-gen.Literal 1)
  x-def.name = "x"
  seq.assign x-def (toit-gen.Literal 2)

  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq
  cls.members.add fun

  lib := toit-gen.Library "test3.toit"
  lib.classes.add cls

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test3.toit"]

  expected := """
    class Foo:
      field_/int
      field2/int := ?
      field3/int ::= 42
      field4/int := 43
      field5 ::= ?
      field6 ::= 44
      field7 := 45
      field8 := ?

      constructor .field_ .field2 .field5 .field8:

      wrap:
        x := 1
        x = 2"""
  expect-equals expected code.trim

test-toitdocs:
  lib := toit-gen.Library "test-toitdocs.toit"
  lib.toitdoc = ["Some lib comment."]

  // Class A with two overloaded foo methods.
  cls := toit-gen.Class "A" --kind=toit-gen.Class.CLASS

  param-x := toit-gen.VarDefinition.parameter "x"
  param-x.name = "x"
  foo1 := toit-gen.Function "foo" --parameters=[param-x] --return-type=null

  param-x2 := toit-gen.VarDefinition.parameter "x"
  param-x2.name = "x"
  param-y := toit-gen.VarDefinition.parameter "y"
  param-y.name = "y"
  foo2 := toit-gen.Function "foo" --parameters=[param-x2, param-y] --return-type=null

  cls.members.add foo1
  cls.members.add foo2
  lib.classes.add cls

  // Top-level function bar with a toitdoc that references A.foo.
  bar := toit-gen.Function "bar" --parameters=[] --return-type=null
  bar.toitdoc = [
    "A toitdoc that references:\n",
    "- all ", toit-gen.ToitdocNameRef foo1 --holder=cls, " (name-based)\n",
    "- the specific ", toit-gen.ToitdocExactRef foo2 --holder=cls, " member with 2 arguments.",
  ]
  lib.functions.add bar

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-toitdocs.toit"]

  expected := """
    /** Some lib comment. */
    class A:
      foo x:

      foo x y:


    /**
    A toitdoc that references:
    - all \$A.foo (name-based)
    - the specific \$(A.foo x y) member with 2 arguments.
    */
    bar:"""
  expect-equals expected code.trim


  // Test scope-aware ref: inside class B, holder should be omitted.
  cls2 := toit-gen.Class "B" --kind=toit-gen.Class.CLASS
  param-z := toit-gen.VarDefinition.parameter "z"
  param-z.name = "z"
  baz := toit-gen.Function "baz" --parameters=[param-z] --return-type=null
  baz.toitdoc = [
    "See ", toit-gen.ToitdocNameRef baz,
    " and ", toit-gen.ToitdocExactRef baz,
    " and ", toit-gen.ToitdocSuperRef, ".",
  ]
  cls2.members.add baz

  lib2 := toit-gen.Library "test-toitdocs2.toit"
  lib2.classes.add cls2

  program2 := toit-gen.Program
  program2.libraries.add lib2

  generated2 := program2.gen --in-memory
  code2 := generated2["test-toitdocs2.toit"]

  expected2 := """
    class B:
      /** See \$baz and \$(baz z) and \$super. */
      baz z:"""
  expect-equals expected2 code2.trim

test-toitdoc-class:
  // Test toitdoc on a class.
  lib := toit-gen.Library "test-toitdoc-class.toit"
  cls := toit-gen.Class "MyClass" --kind=toit-gen.Class.CLASS

  p := toit-gen.VarDefinition.parameter "v"
  p.name = "v"
  member := toit-gen.Function "do-something" --parameters=[p] --return-type=null
  cls.members.add member

  // Class toitdoc references its own member (scope-aware: no qualifier).
  cls.toitdoc = [
    "A class that can ", toit-gen.ToitdocNameRef member, ".",
  ]
  lib.classes.add cls

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-toitdoc-class.toit"]

  expected := """
    /** A class that can \$do-something. */
    class MyClass:
      do-something v:"""
  expect-equals expected code.trim

test-toitdoc-field:
  // Test toitdoc on a field.
  lib := toit-gen.Library "test-toitdoc-field.toit"
  cls := toit-gen.Class "Config" --kind=toit-gen.Class.CLASS

  field := toit-gen.VarDefinition.field "timeout"
      --type=(toit-gen.Ref (toit-gen.Class.core "int"))
      --initial=(toit-gen.Literal 30)
      --is-final=false
  field.toitdoc = ["The timeout in seconds."]
  cls.fields.add field
  lib.classes.add cls

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-toitdoc-field.toit"]

  expected := """
    class Config:
      /** The timeout in seconds. */
      timeout/int := 30"""
  expect-equals expected code.trim

test-toitdoc-function:
  // Test toitdoc on a top-level function referencing its own parameter.
  lib := toit-gen.Library "test-toitdoc-function.toit"

  p1 := toit-gen.VarDefinition.parameter "host"
  p1.name = "host"
  p2 := toit-gen.VarDefinition.parameter "port"
  p2.name = "port"
  fun := toit-gen.Function "connect" --parameters=[p1, p2] --return-type=null
  fun.toitdoc = [
    "Connects to the given ", toit-gen.ToitdocNameRef p1,
    " on ", toit-gen.ToitdocNameRef p2, ".",
  ]
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-toitdoc-function.toit"]

  expected := """
    /** Connects to the given \$host on \$port. */
    connect host port:"""
  expect-equals expected code.trim

test-toitdoc-member-params:
  // Test toitdoc on a member function referencing its own parameters
  // (including named and block params).
  lib := toit-gen.Library "test-toitdoc-member-params.toit"
  cls := toit-gen.Class "Client" --kind=toit-gen.Class.CLASS

  p-url := toit-gen.VarDefinition.parameter "url"
  p-url.name = "url"
  p-timeout := toit-gen.VarDefinition.parameter "timeout" --is-named=true
  p-timeout.name = "timeout"
  p-callback := toit-gen.VarDefinition.parameter "callback" --is-block=true
  p-callback.name = "callback"

  fetch := toit-gen.Function "fetch" --parameters=[p-url, p-timeout, p-callback] --return-type=null
  fetch.toitdoc = [
    "Fetches the ", toit-gen.ToitdocNameRef p-url, ".\n",
    "Uses the given ", toit-gen.ToitdocNameRef p-timeout, " and\n",
    "  invokes ", toit-gen.ToitdocNameRef p-callback, " on completion.",
  ]
  cls.members.add fetch
  lib.classes.add cls

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-toitdoc-member-params.toit"]

  expected := """
    class Client:
      /**
      Fetches the \$url.
      Uses the given \$timeout and
        invokes \$callback on completion.
      */
      fetch url --timeout callback:"""
  expect-equals expected code.trim

test-toitdoc-exact-named-block:
  // Test exact ref rendering with named and block params in the signature.
  lib := toit-gen.Library "test-toitdoc-exact-named-block.toit"
  cls := toit-gen.Class "Server" --kind=toit-gen.Class.CLASS

  p1 := toit-gen.VarDefinition.parameter "path"
  p1.name = "path"
  p2 := toit-gen.VarDefinition.parameter "method" --is-named=true
  p2.name = "method"
  p3 := toit-gen.VarDefinition.parameter "handler" --is-block=true
  p3.name = "handler"

  route := toit-gen.Function "route" --parameters=[p1, p2, p3] --return-type=null
  cls.members.add route

  // A top-level function that references the exact overload with all param types.
  helper := toit-gen.Function "setup" --parameters=[] --return-type=null
  helper.toitdoc = [
    "Sets up a route using ", toit-gen.ToitdocExactRef route --holder=cls, ".",
  ]
  lib.functions.add helper
  lib.classes.add cls

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-toitdoc-exact-named-block.toit"]

  expected := """
    class Server:
      route path --method handler:


    /** Sets up a route using \$(Server.route path --method [handler]). */
    setup:"""
  expect-equals expected code.trim


test-cascading-calls:
  tree-var := toit-gen.VarDefinition.local "tree" --initial=(toit-gen.Literal null)
  tree-var.name = "tree"
  tree := toit-gen.Ref tree-var
  target-uri-var := toit-gen.VarDefinition.local "target-uri" --initial=(toit-gen.Literal null)
  target-uri-var.name = "target-uri"
  target-uri := toit-gen.Ref target-uri-var

  init-param := toit-gen.VarDefinition.parameter "init" --is-named=true --is-block=true
  init-param.name = "init"
  init-block := toit-gen.Block (toit-gen.Return (toit-gen.Literal []))
  init-named := toit-gen.Named init-param init-block

  get-call := toit-gen.Call tree "get" --arguments=[target-uri, init-named]

  schema-var := toit-gen.VarDefinition.local "schema" --initial=(toit-gen.Literal null)
  schema-var.name = "schema"
  schema := toit-gen.Ref schema-var
  add-call := toit-gen.Call get-call "add" --arguments=[schema]

  seq := toit-gen.Sequence
  seq.add (toit-gen.ExpressionStatement add-call)

  lib := toit-gen.Library "test4.toit"
  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test4.toit"]

  expected := """
    wrap:
      (tree.get target-uri --init=:
        return []).add schema"""
  expect-equals expected code.trim

test-classes-and-mixins:
  lib := toit-gen.Library "test5.toit"

  itf := toit-gen.Class "MyInterface" --kind=toit-gen.Class.INTERFACE
  mx := toit-gen.Class "MyMixin" --kind=toit-gen.Class.MIXIN
  abstr := toit-gen.Class "MyAbstract" --kind=toit-gen.Class.CLASS --is-abstract=true

  lib.classes.add itf
  lib.classes.add mx
  lib.classes.add abstr

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test5.toit"]

  expected := """
    interface MyInterface:

    mixin MyMixin:

    abstract class MyAbstract:"""
  expect-equals expected code.trim

test-control-flow:
  if-stmt := toit-gen.If (toit-gen.Literal true)
      (toit-gen.ExpressionStatement (toit-gen.Literal 1))
      (toit-gen.ExpressionStatement (toit-gen.Literal 2))

  seq := toit-gen.Sequence
  seq.add if-stmt

  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq

  lib := toit-gen.Library "test6.toit"
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test6.toit"]
  expected := """
    wrap:
      if true:
        1
      else:
        2"""
  expect-equals expected code.trim

  // Test: if condition is a call with a block, it must be parenthesized.
  // if (foo: | x | return x + 1):
  //   2
  foo-var := toit-gen.VarDefinition.local "foo" --initial=(toit-gen.Literal null)
  foo-var.name = "foo"
  foo-ref := toit-gen.Ref foo-var
  x-param := toit-gen.VarDefinition.parameter "x" --is-block=true
  x-param.name = "x"
  blk-body := toit-gen.Return (toit-gen.Binary (toit-gen.Ref x-param) "+" (toit-gen.Literal 1))
  blk := toit-gen.Block blk-body --parameters=[x-param]
  foo-call := toit-gen.Call foo-ref --arguments=[blk]

  if-stmt2 := toit-gen.If foo-call
      (toit-gen.ExpressionStatement (toit-gen.Literal 2))
      null

  seq2 := toit-gen.Sequence
  seq2.add if-stmt2

  fun2 := toit-gen.Function "wrap2" --parameters=[] --return-type=null
  fun2.body = seq2

  lib2 := toit-gen.Library "test6b.toit"
  lib2.functions.add fun2

  program2 := toit-gen.Program
  program2.libraries.add lib2

  generated2 := program2.gen --in-memory
  code2 := generated2["test6b.toit"]
  expected2 := """
    wrap2:
      if (foo: | x |
        return x + 1):
        2"""
  expect-equals expected2 code2.trim

test-expressions:
  seq := toit-gen.Sequence

  t-var := toit-gen.VarDefinition.local "t" --initial=(toit-gen.Literal "string")
  t-var.name = "t"
  t-ref := toit-gen.Ref t-var

  idx := toit-gen.Index t-ref (toit-gen.Literal 0)
  seq.add (toit-gen.ExpressionStatement idx)

  as-expr := toit-gen.As t-ref (toit-gen.Class.core "string")
  seq.add (toit-gen.ExpressionStatement as-expr)

  is-expr := toit-gen.Is t-ref (toit-gen.Class.core "string")
  seq.add (toit-gen.ExpressionStatement is-expr)

  lambda-body := toit-gen.Sequence
  lambda-body.add (toit-gen.ExpressionStatement (toit-gen.Literal null))
  lambda := toit-gen.Lambda lambda-body --parameters=[]
  seq.add (toit-gen.ExpressionStatement lambda)

  late := toit-gen.LateInitialized
  late-var := seq.define "late_var" late
  seq.assign late-var (toit-gen.Literal 42)

  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq

  other-param := toit-gen.VarDefinition.parameter "other"
  other-param.name = "other"
  op-body := toit-gen.Sequence
  op-body.add (toit-gen.Return (toit-gen.Literal true))
  op := toit-gen.Operator "==" --parameters=[other-param] op-body

  lib := toit-gen.Library "test7.toit"
  lib.functions.add fun
  lib.functions.add op

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test7.toit"]
  expected := """
    wrap:
      t[0]
      t as string
      t is string
      ::
        null
      late-var := ?
      late-var = 42

    operator-== other:
      return true"""
  expect-equals expected code.trim

test-imports-and-exports:
  lib := toit-gen.Library "test-imports-and-exports.toit"

  imp := toit-gen.Import ["my-library"]
  imp.prefix = "lib"
  lib.imports.add imp

  exp := toit-gen.Export
  lib.exports.add exp

  local-var := toit-gen.VarDefinition.local "t" --initial=(toit-gen.Literal null)
  local-var.name = "t"

  my-class-var := toit-gen.VarDefinition.local "MyClass" --initial=(toit-gen.Literal null)
  my-class-var.name = "MyClass"
  my-class-ref := toit-gen.ImportedRef imp my-class-var

  other-class-var := toit-gen.VarDefinition.local "OtherClass" --initial=(toit-gen.Literal null)
  other-class-var.name = "OtherClass"
  other-class-ref := toit-gen.Ref other-class-var
  exp.exports.add other-class-ref

  imported-ref := toit-gen.ImportedRef imp local-var

  seq := toit-gen.Sequence
  seq.add (toit-gen.ExpressionStatement imported-ref)
  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-imports-and-exports.toit"]

  expected := """
    import my-library as lib show MyClass t

    export OtherClass

    wrap:
      lib.t"""
  expect-equals expected code.trim

test-nested-expressions:
  seq := toit-gen.Sequence

  // Test generating: ((1 + 2) * 3) - 4
  binary1 := toit-gen.Binary (toit-gen.Literal 1) "+" (toit-gen.Literal 2)
  binary2 := toit-gen.Binary binary1 "*" (toit-gen.Literal 3)
  binary3 := toit-gen.Binary binary2 "-" (toit-gen.Literal 4)
  seq.add (toit-gen.ExpressionStatement binary3)

  // Test generating: a as int as float
  a-var := toit-gen.VarDefinition.local "a" --initial=(toit-gen.Literal null)
  a-var.name = "a"
  a-ref := toit-gen.Ref a-var
  as1 := toit-gen.As a-ref (toit-gen.Class.core "int")
  as2 := toit-gen.As as1 (toit-gen.Class.core "float")
  seq.add (toit-gen.ExpressionStatement as2)

  // Test generating: (a is int) as bool
  is1 := toit-gen.Is a-ref (toit-gen.Class.core "int")
  as3 := toit-gen.As is1 (toit-gen.Class.core "bool")
  seq.add (toit-gen.ExpressionStatement as3)

  // Test generating: a[b[c[1]]]
  b-var := toit-gen.VarDefinition.local "b" --initial=(toit-gen.Literal null)
  b-var.name = "b"
  b-ref := toit-gen.Ref b-var
  c-var := toit-gen.VarDefinition.local "c" --initial=(toit-gen.Literal null)
  c-var.name = "c"
  c-ref := toit-gen.Ref c-var
  idx1 := toit-gen.Index c-ref (toit-gen.Literal 1)
  idx2 := toit-gen.Index b-ref idx1
  idx3 := toit-gen.Index a-ref idx2
  seq.add (toit-gen.ExpressionStatement idx3)

  // Test generating: (a[0])[1]
  idx4 := toit-gen.Index a-ref (toit-gen.Literal 0)
  idx5 := toit-gen.Index idx4 (toit-gen.Literal 1)
  seq.add (toit-gen.ExpressionStatement idx5)

  // Test generating: a.b.c(1)
  a-b-call := toit-gen.Call a-ref "b" --arguments=[]
  a-b-c-call := toit-gen.Call a-b-call "c" --arguments=[toit-gen.Literal 1]
  seq.add (toit-gen.ExpressionStatement a-b-c-call)

  // Test generating: a(b(c(1)))
  // First we need some functions to call!
  fun-a-var := toit-gen.VarDefinition.local "fun_a" --initial=(toit-gen.Literal null)
  fun-a-var.name = "fun_a"
  fun-a := toit-gen.Ref fun-a-var
  fun-b-var := toit-gen.VarDefinition.local "fun_b" --initial=(toit-gen.Literal null)
  fun-b-var.name = "fun_b"
  fun-b := toit-gen.Ref fun-b-var
  fun-c-var := toit-gen.VarDefinition.local "fun_c" --initial=(toit-gen.Literal null)
  fun-c-var.name = "fun_c"
  fun-c := toit-gen.Ref fun-c-var

  call-c := toit-gen.Call fun-c --arguments=[toit-gen.Literal 1]
  call-b := toit-gen.Call fun-b --arguments=[call-c]
  call-a := toit-gen.Call fun-a --arguments=[call-b]
  seq.add (toit-gen.ExpressionStatement call-a)

  // Test generating: (A).foo
  a-class := toit-gen.Class.core "A"
  a-class-ref := toit-gen.Ref a-class
  a-init-call := toit-gen.Call a-class-ref --arguments=[]
  a-foo-call := toit-gen.Call a-init-call "foo" --arguments=[]
  seq.add (toit-gen.ExpressionStatement a-foo-call)

  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq

  lib := toit-gen.Library "test-nested-expressions.toit"
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-nested-expressions.toit"]

  expected := """
    wrap:
      ((1 + 2) * 3) - 4
      (a as int) as float
      (a is int) as bool
      a[b[c[1]]]
      a[0][1]
      a.b.c 1
      fun_a (fun_b (fun_c 1))
      (A).foo"""
  expect-equals expected code.trim

test-nested-blocks-and-lambdas:
  seq := toit-gen.Sequence

  // Test generating:
  // a: | b |
  //   c: | d |
  //     d + 1
  a-var := toit-gen.VarDefinition.local "a" --initial=(toit-gen.Literal null)
  a-var.name = "a"
  a-ref := toit-gen.Ref a-var

  c-var := toit-gen.VarDefinition.local "c" --initial=(toit-gen.Literal null)
  c-var.name = "c"
  c-ref := toit-gen.Ref c-var

  d-param := toit-gen.VarDefinition.parameter "d" --is-block=true
  d-param.name = "d"
  d-ref := toit-gen.Ref d-param

  c-body := toit-gen.Return (toit-gen.Binary d-ref "+" (toit-gen.Literal 1))
  c-block := toit-gen.Block c-body --parameters=[d-param]

  c-call := toit-gen.Call c-ref --arguments=[c-block]

  b-param := toit-gen.VarDefinition.parameter "b" --is-block=true
  b-param.name = "b"

  a-body := toit-gen.Sequence
  a-body.add (toit-gen.ExpressionStatement c-call)
  a-block := toit-gen.Block a-body --parameters=[b-param]

  a-call := toit-gen.Call a-ref --arguments=[a-block]
  seq.add (toit-gen.ExpressionStatement a-call)

  // Test generating:
  // f ::
  //   g ::
  //     h
  f-var := toit-gen.VarDefinition.local "f" --initial=(toit-gen.Literal null)
  f-var.name = "f"
  f-ref := toit-gen.Ref f-var

  g-var := toit-gen.VarDefinition.local "g" --initial=(toit-gen.Literal null)
  g-var.name = "g"
  g-ref := toit-gen.Ref g-var

  h-var := toit-gen.VarDefinition.local "h" --initial=(toit-gen.Literal null)
  h-var.name = "h"
  h-ref := toit-gen.Ref h-var

  g-lambda := toit-gen.Lambda (toit-gen.ExpressionStatement h-ref) --parameters=[]
  g-call := toit-gen.Call g-ref --arguments=[g-lambda]

  f-lambda := toit-gen.Lambda (toit-gen.ExpressionStatement g-call) --parameters=[]
  f-call := toit-gen.Call f-ref --arguments=[f-lambda]
  seq.add (toit-gen.ExpressionStatement f-call)

  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq

  lib := toit-gen.Library "test-nested-blocks-and-lambdas.toit"
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-nested-blocks-and-lambdas.toit"]

  expected := """
    wrap:
      a: | b |
        c: | d |
          return d + 1
      f ::
        g ::
          h"""
  expect-equals expected code.trim

test-multiple-blocks:
  seq := toit-gen.Sequence
  
  my-func-var := toit-gen.VarDefinition.local "my_function" --initial=(toit-gen.Literal null)
  my-func-var.name = "my-function"
  my-func-ref := toit-gen.Ref my-func-var
  
  other-func-var := toit-gen.VarDefinition.local "other_function" --initial=(toit-gen.Literal null)
  other-func-var.name = "other-function"
  other-func-ref := toit-gen.Ref other-func-var
  
  call1 := toit-gen.Call other-func-ref --arguments=[toit-gen.Literal 1, toit-gen.Literal 2]
  call2 := toit-gen.Call my-func-ref --arguments=[call1]
  
  seq.add (toit-gen.ExpressionStatement call2)
  
  call3 := toit-gen.Call other-func-ref --arguments=[toit-gen.Literal 2]
  bin := toit-gen.Binary (toit-gen.Literal 1) "+" call3
  call4 := toit-gen.Call my-func-ref --arguments=[bin]
  
  seq.add (toit-gen.ExpressionStatement call4)
  
  a-param := toit-gen.VarDefinition.parameter "a" --is-block=true
  a-param.name = "a"
  b-param := toit-gen.VarDefinition.parameter "b" --is-block=true
  b-param.name = "b"
  
  blk1 := toit-gen.Block (toit-gen.ExpressionStatement (toit-gen.Binary (toit-gen.Ref a-param) "+" (toit-gen.Literal 1))) --parameters=[a-param]
  blk2 := toit-gen.Block (toit-gen.ExpressionStatement (toit-gen.Binary (toit-gen.Ref b-param) "+" (toit-gen.Literal 2))) --parameters=[b-param]
  
  named-blk2 := toit-gen.Named b-param blk2
  call5 := toit-gen.Call my-func-ref --arguments=[toit-gen.Literal 1, blk1, named-blk2]
  
  seq.add (toit-gen.ExpressionStatement call5)
  
  fun := toit-gen.Function "wrap" --parameters=[] --return-type=null
  fun.body = seq

  lib := toit-gen.Library "test-multiple-blocks.toit"
  lib.functions.add fun

  program := toit-gen.Program
  program.libraries.add lib

  generated := program.gen --in-memory
  code := generated["test-multiple-blocks.toit"]

  expected := """
    wrap:
      my-function (other-function 1 2)
      my-function (1 + (other-function 2))
      my-function
          1
          : | a |
            a + 1
          --b=: | b |
            b + 2"""
  expect-equals expected code.trim

