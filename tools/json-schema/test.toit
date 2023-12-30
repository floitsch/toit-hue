import encoding.json
import host.file
import host.directory

import .json-schema as json-schema

import encoding.url

total-counter := 0
success-counter := 0

main args:
  tests := args[0]
  if file.is-file tests:
    run-test-file tests
  else:
    stream := directory.DirectoryStream tests
    while entry := stream.next:
      file-path := "$tests/$entry"
      if file.is-file file-path:
        run-test-file file-path
    stream.close
  print "Success: $success-counter/$total-counter"

run-test-file file-path/string:
  test-json := json.decode (file.read-content file-path)
  already-printed := false
  run-tests test-json --print-header=:
    if not already-printed:
      already-printed = true
      print "Running $file-path"

run-tests test-json/List [--print-header]:
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
      schema = json-schema.build entry["schema"]
    if exception:
      print "    Suite schema construction failed: $exception"
      continue.do
    else:
    entry["tests"].do: | test/Map |
      result := null
      test-exception := catch --trace:
        result = schema.validate test["data"]
      if test-exception: result = not test["valid"]
      if test["valid"] == result: success-counter++
      if test["valid"] != result:
        print-suite.call
        print "    Running test $test["description"]"
        print "      Test result: $result - $(test["valid"] == result ? "OK" : "FAIL")"
