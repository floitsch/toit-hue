import encoding.json
import host.file
import host.directory

import .json-schema as json-schema

import encoding.url

total-counter := 0
success-counter := 0

class TestLoader extends json-schema.HttpResourceLoader:
  static LOCALHOST-PREFIX ::= "http://localhost:1234/"
  remote-path/string

  constructor .remote-path:

  load url/string:
    if url.starts-with LOCALHOST-PREFIX:
      local-path := url[LOCALHOST-PREFIX.size..]
      content := file.read-content "$remote-path/$local-path"
      return json.decode content
    else:
      return super url

main args:
  remote-path := args[0]
  tests := args[1]

  resource-loader := TestLoader remote-path

  if file.is-file tests:
    run-test-file tests --resource-loader=resource-loader
  else:
    stream := directory.DirectoryStream tests
    while entry := stream.next:
      file-path := "$tests/$entry"
      if file.is-file file-path:
        run-test-file file-path --resource-loader=resource-loader
    stream.close
  print "Success: $success-counter/$total-counter"

run-test-file file-path/string --resource-loader/json-schema.ResourceLoader:
  test-json := json.decode (file.read-content file-path)
  already-printed := false
  run-tests test-json --resource-loader=resource-loader --print-header=:
    if not already-printed:
      already-printed = true
      print "Running $file-path"

run-tests test-json/List --resource-loader/json-schema.ResourceLoader [--print-header]:
  test-json.do: | entry/Map |
    total-counter += entry["tests"].size

    already-printed-suite := false
    print-suite := :
      if not already-printed-suite:
        already-printed-suite = true
        print-header.call
        print "  Running suite $entry["description"]"
    schema/json-schema.JsonSchema? := null
    exception := catch --trace:
      schema = json-schema.build entry["schema"] --resource-loader=resource-loader
    if exception:
      print-suite.call
      print "    Suite schema construction failed: $exception"
      continue.do
    else:
    entry["tests"].do: | test/Map |
      result/json-schema.Result? := null
      test-exception := catch --trace:
        result = schema.validate test["data"] --no-collect-annotations
      is-valid := result ? result.is-valid : false
      if test-exception: is-valid = not test["valid"]
      if test["valid"] == is-valid: success-counter++
      if test["valid"] != is-valid:
        print-suite.call
        print "    Running test $test["description"]"
        print "      Test result: $result - $(test["valid"] == result ? "OK" : "FAIL")"
