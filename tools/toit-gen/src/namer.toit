// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

COMMON-ABBREVIATIONS_ := {
  "XML",
  "HTTP",
  "HTML",
  "JSON",
  "API",
}

unique name/string [--is-reserved]:
  if not is-reserved.call name:
    return name
  i := 1
  while is-reserved.call "$name-$i":
    i++
  return "$name-$i"

toit-class-name name/string -> string:
  return to-caml-case (toit-identifier name)

toit-member-name name/string -> string:
  return to-kebab-case (toit-identifier name)

toit-local-name name/string -> string:
  return to-kebab-case (toit-identifier name)

toit-identifier str/string -> string:
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

to-kebab-case id/string -> string:
  chunks := split-into-chunks_ id
  chunks.map --in-place: | str/string |
    str.to-ascii-lower
  return chunks.join "-"

to-caml-case id/string -> string:
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
      else if last-was-upper and COMMON-ABBREVIATIONS_.contains str[start .. i]:
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
