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
        print "Running $entry"
        test-json := json.decode (file.read-content file-path)
        run-tests test-json
    stream.close
  print "Success: $success-counter/$total-counter"

run-test-file file-path/string:
  print "Running $file-path"
  test-json := json.decode (file.read-content file-path)
  run-tests test-json

run-tests test-json/List:
  test-json.do: | entry/Map |
    total-counter += entry["tests"].size

    print "  Running suite $entry["description"]"
    schema/json-schema.Schema? := null
    exception := catch --trace:
      schema = json-schema.build entry["schema"]
    if exception:
      print "    Suite schema construction failed: $exception"
      continue.do
    else:
    entry["tests"].do: | test/Map |
      print "    Running test $test["description"]"
      result := null
      test-exception := catch --trace:
        result = schema.validate test["data"]
      if test-exception: result = not test["valid"]
      if test["valid"] == result: success-counter++
      print "      Test result: $result - $(test["valid"] == result ? "OK" : "FAIL")"
