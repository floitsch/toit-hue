template-to-mustache str/string -> string:
  lines := str.split "\n"
  replacements := {:}
  result := []
  lines.do: | line/string |
    trimmed := line.trim
    if trimmed.starts-with "// MUSTACHE: ":
      trimmed = trimmed.trim --left "// MUSTACHE: "
      last-curly := trimmed.index-of --last "}"
      if last-curly != -1:
        trimmed = trimmed[..last-curly + 1]
      if trimmed.contains "=":
        parts := trimmed.split "="
        replacements[parts[0]] = parts[1]
      else:
        result.add trimmed
    else if trimmed.starts-with "// xMUSTACHE":
      // Skip line.
    else:
      replacements.do: | pattern/string replacement/string |
        line = line.replace --all pattern replacement
      result.add line
  return result.join "\n"
