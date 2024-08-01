import encoding.yaml
import host.file
import host.directory

import .openapi as openapi

main args:
  input-path := args[0]
  walk input-path: | path/string |
    if not path.ends-with "yaml" or path.ends-with "yml":
      continue.walk

    exception := catch --trace:
      data := read-yaml-file path
      api-version := data.get "openapi"
      if not api-version:
        // Probably an old swagger file.
        continue.walk

      // It's not clear if we support all 3.x versions, but let's try.
      if not api-version.starts-with "3.":
        continue.walk

      openapi.build data
    if exception: print "Testing $path done with $exception"

read-yaml-file path/string:
  content := file.read-content path
  return yaml.decode content

walk path/string [block]:
  if file.is-file path:
    block.call path
    return

  if not file.is-directory path:
    return

  stream := directory.DirectoryStream path
  while name := stream.next:
    full-path := "$path/$name"
    if file.is-file full-path:
      block.call full-path
    else if file.is-directory full-path:
      walk full-path block
  stream.close
