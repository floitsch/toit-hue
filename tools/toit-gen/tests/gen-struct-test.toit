// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *
import toit-gen

main:
  test-basic-class
  test-classes-and-mixins
  test-imports-and-exports

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


