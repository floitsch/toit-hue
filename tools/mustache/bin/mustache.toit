import cli
import mustache

main args:
  cmd := cli.Command "mustache"
      --help="""
        A parser and renderer for Mustache templates.

        The first rest argument is the main template.

        If more than one template is given, all subsequent files are
        treated as partials, with the name being the basename without
        the extension (for example "foo" for "partial/foo.mustache").

        If a file is given multiple times, the additional references are
        ignored. This allows to repeat the main template in case it is
        in the same folder as partials:
          "mustache -i in.json -o out.txt main.mustache *.mustache"

        If 'strict' is set, then tag names must only contain the following
        characters: a-z, A-Z, 0-9, underscore, dot and minus. Furthermore,
        template variables must exist during rendering.
        """
      --options=[
        cli.Flag "strict"
            --help="Whether to restrict variable names and require variables to exist."
            --default=false,
        cli.Option "input"
            --short-name="i"
            --help="The input to be rendered."
            --type="json|yaml file"
            --required,
        cli.Option "output"
            --short-name="o"
            --help="The output file for the rendered data."
            --type="file"
            --required,
      ]
      --rest=[
        cli.Option "template"
            --help="A Mustache template."
            --required
            --multi,
      ]
      --run=:: run it

run parsed/cli.Parsed:
  input := parsed["input"]
  output := parsed["output"]
  strict := parsed["strict"]
  templates := parsed["template"]

  // Filter out duplicates.
  seen := {}
  templates.filter --in-place:
    if seen.contains it:
      false
    else:
      seen.add it
      true

  main-template := mustache.parse --strict=strict templates.first
  partials := templates[1..].map: mustache.parse --strict=strict it

