// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *

import toit-gen

main:
  test-bootstrap
  test-fixed-name-propagation
  test-unnamed-params
  test-prefixes-and-locals
  test-locals-and-blocks
  test-global-clashes

test-bootstrap:
  cls := toit-gen.Class "MyClass"
      --kind=toit-gen.Class.CLASS
  fun := toit-gen.Function "myMethod" --parameters=[] --return-type=null
  cls.members.add fun
  library := toit-gen.Library "my_library.toit"
  library.classes.add cls
  program := toit-gen.Program
  program.libraries.add library

  program.gen --in-memory  // Triggers assign-names_.
  expect-equals "MyClass" cls.name
  expect-equals "my-method" fun.name

test-fixed-name-propagation:
  // A class with a method that has a fixed parameter 'foo'
  // should block a field in that class from being named 'foo'.
  cls := toit-gen.Class "MyClass"
      --kind=toit-gen.Class.CLASS

  fixed-param := toit-gen.VarDefinition.parameter "foo"
  fixed-param.name = "foo" // Forced name.

  fun := toit-gen.Function "myMethod" --parameters=[fixed-param] --return-type=null
  cls.members.add fun

  field := toit-gen.VarDefinition.field "foo" --initial=null
  cls.fields.add field

  library := toit-gen.Library "my_library.toit"
  library.classes.add cls
  program := toit-gen.Program
  program.libraries.add library

  program.gen --in-memory

  expect-equals "foo" fixed-param.name
  // The field should be renamed from 'foo' because 'foo' is a fixed param inside the class.
  expect-not-equals "foo" field.name

test-unnamed-params:
  cls := toit-gen.Class "MyClass" --kind=toit-gen.Class.CLASS

  // Named param gets the name "foo".
  named-param := toit-gen.VarDefinition.parameter "foo" --is-named=true

  // Unnamed param also prefers "foo".
  unnamed-param := toit-gen.VarDefinition.parameter "foo" --is-named=false

  fun := toit-gen.Function "myMethod" --parameters=[named-param, unnamed-param] --return-type=null
  cls.members.add fun

  library := toit-gen.Library "my_library.toit"
  library.classes.add cls
  program := toit-gen.Program
  program.libraries.add library

  program.gen --in-memory

  expect-equals "foo" named-param.name
  // Unnamed param should yield to the named param and become foo-1.
  expect-not-equals "foo" unnamed-param.name

test-prefixes-and-locals:
  // Library with an import prefix 'my_prefix' and a class with a member 'my_prefix'.
  // The prefix should yield to the member and become 'my-prefix-1'.
  library := toit-gen.Library "my_library.toit"

  imp := toit-gen.Import ["some", "pkg"] --preferred-prefix="my_prefix"
  library.imports.add imp

  cls := toit-gen.Class "MyClass" --kind=toit-gen.Class.CLASS
  fun := toit-gen.Function "my_prefix" --parameters=[] --return-type=null
  cls.members.add fun
  library.classes.add cls

  program := toit-gen.Program
  program.libraries.add library

  program.gen --in-memory

  expect-equals "my-prefix" fun.name
  // Prefix should not clash with the member name, so it should get a suffix.
  expect-not-equals "my-prefix" imp.prefix

test-locals-and-blocks:
  // A local variable and a block parameter should not clash if they are in the same scope,
  // or rather, block parameters get unique IDs from the enclosing local namer.
  cls := toit-gen.Class "MyClass" --kind=toit-gen.Class.CLASS

  // A local named 'foo'.
  local1 := toit-gen.VarDefinition.local "foo" --initial=(toit-gen.Literal 1)
  local2 := toit-gen.VarDefinition.local "foo" --initial=(toit-gen.Literal 2)

  seq := toit-gen.Sequence
  seq.add (toit-gen.LocalDefinition local1)
  seq.add (toit-gen.LocalDefinition local2)

  fun := toit-gen.Function "myMethod" --parameters=[] --return-type=null
  fun.body = seq
  cls.members.add fun

  library := toit-gen.Library "my_library.toit"
  library.classes.add cls
  program := toit-gen.Program
  program.libraries.add library

  program.gen --in-memory

  expect-equals "foo" local1.name
  expect-not-equals "foo" local2.name

test-global-clashes:
  // Two classes with the same preferred name.
  cls1 := toit-gen.Class "Foo" --kind=toit-gen.Class.CLASS
  cls2 := toit-gen.Class "Foo" --kind=toit-gen.Class.CLASS

  library := toit-gen.Library "my_library.toit"
  library.classes.add cls1
  library.classes.add cls2

  program := toit-gen.Program
  program.libraries.add library

  program.gen --in-memory

  expect-equals "Foo" cls1.name
  // Second class gets a suffix.
  expect-not-equals "Foo" cls2.name
