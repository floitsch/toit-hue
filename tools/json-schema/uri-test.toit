import expect show *
import .uri

main:
  test-merge

test-merge:
  // Merge base URI without an authority.
  base := UriReference
      --scheme=null
      --authority=null
      --path="/foo/bar/bogus"
      --query=null
      --fragment=null
  relative-path := "relative"
  expected := "/foo/bar/relative"
  actual := UriReference.merge_ --base=base --relative-path=relative-path
  expect-equals expected actual

  // Merge base URI with an authority and path.
  base = UriReference
      --scheme=null
      --authority="authority"
      --path="/foo/bar/bogus"
      --query=null
      --fragment=null
  relative-path = "relative"
  expected = "/foo/bar/relative"
  actual = UriReference.merge_ --base=base --relative-path=relative-path
  expect-equals expected actual
