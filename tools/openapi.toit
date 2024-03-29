import .json-schema as json-schema
import .json-schema.json-pointer show JsonPointer

/**
A base class for OpenAPI class that can have extensions.
*/
// https://spec.openapis.org/oas/v3.1.0#specification-extensions
class Extensionable_:
  /**
  A map of OpenAPI extensions.

  Extension are not directly supported by the OpenAPI Specification,
    but may be supported by tools or used by spec extensions.
  Each key must start with 'x-'.
  Keys beginning with `x-oai-` and `x-oas-` are reserved for uses
    defined by the OpenAPI Initiative.
  Values can be `null`, a primitive, a $List or a $Map.
  */
  extensions/Map?  // from string (starting with "x-" to any.

  constructor --.extensions:

  static extract-extensions o/Map -> Map?:
    extensions/Map? := null
    o.do: | key/string value/any |
      if key.starts-with "x-":
        if extensions == null: extensions = {:}
        extensions[key] = value
    return extensions

  add-extensions-to-json_ m/Map -> none:
    if extensions:
      extensions.do: | key value |
        m[key] = value

class BuildContext:
  json-schema-dialect/string? := null
  json-schema-context := json-schema.BuildContext
      --default-vocabulary-uri=json-schema.OPENAPI-3-1-URI

/** The root object of the OpenAPI document. */
// https://spec.openapis.org/oas/v3.1.0#openapi-object
class OpenApi extends Extensionable_:
  /**
  The URL where the OpenAPI document was originally retrieved from.
  The $Server.url field may be relative to this field.
  */
  url/string?

  /**
  The version number of the OpenAPI specification.
  This field should be used by tooling to interpret the OpenAPI document. It
    is not related to the $Info.version string.
  */
  openapi/string

  /**
  The metadata about the API.
  May be used by tooling as required.
  */
  info/Info

  /**
  The default value for the \$schema keyword within Schema Objects contained within this OpenAPI document.
  */
  json-schema-dialect/string?

  /**
  A list of $Server objects, which provide connectivity information to a target server.
  If the servers property is not provided, or is an empty array, the default value would be a Server Object with a url value of /.
  */
  servers/List?

  /**
  The available paths and operations for the API.
  */
  paths/Paths

  /**
  The incoming webhooks that may be received as part of this API, and
    that the API consumer may choose to implement.

  Closely related to the $Components.callbacks feature, this section
    describes requests initiated other than by an API call, for example
    by an out of band registration. The key name is a unique string to
    refer to each webhook, while the (optionally referenced) $PathItem
    object describes a request that may be initiated by the API provider
    and the expected responses.
  */
  webhooks/Map?  // from string to PathItem.

  /**
  An element to hold various schemas for the document.
  */
  components/Components?

  /**
  A declaration of which security mechanisms can be used across the API.
  The list of values includes alternative security requirement objects
    that can be used. Only one of the security requirement objects need
    to be satisfied to authorize a request.
  Individual operations can override this definition.
  // TODO(florian): empty security requirement {} doesn't work.
  To make security optional, an empty security requirement ({}) can be included in the array.
  */
  security/List?  // of SecurityRequirement.

  /**
  A list of $Tag objects used by the specification with additional metadata.
  The order of the tags can be used to reflect on their order by the
    parsing tools. Not all tags that are used by the $Operation object
    must be declared. The tags that are not declared may be organized
    randomly or based on the tools' logic.
  Each tag name in the list must be unique.
  */
  tags/List?  // of Tag.

  /**
  Additional external documentation.
  */
  external-docs/ExternalDocumentation?

  constructor
      --.url=null
      --.openapi="3.0.0"
      --.info
      --.json-schema-dialect=null
      --.servers=null
      --.paths
      --.webhooks=null
      --.components=null
      --.security=null
      --.tags=null
      --.external-docs=null
      --extensions/Map?=null:
    super --extensions=extensions

  /**
  Constructs an OpenApi object from a JSON object $o.
  The $url parameter is the URL where the OpenAPI document was originally
    retrieved from.
  */
  static build --url/string?=null o/Map -> OpenApi:
    schema-dialect := o.get "jsonSchemaDialect"
    pointer := JsonPointer
    context := BuildContext
    context.json-schema-dialect = schema-dialect

    tags/List? := null
    o.get "tags" --if-present=: | json-tags/List |
        tags = []
        json-tags.size.repeat: | i |
          tag := Tag.build json-tags[i] context pointer[i]
          tags.add tag
    result := OpenApi
      --openapi=o["openapi"]
      --info=Info.build o["info"] context pointer["info"]
      --json-schema-dialect=o.get schema-dialect
      --servers=o.get "servers"
      --paths=Paths.build o["paths"] context pointer["paths"]
      --webhooks=o.get "webhooks"
      --components=o.get "components"
      --security=o.get "security"
      --tags=tags
      --external-docs=o.get "externalDocs"
      --extensions=Extensionable_.extract-extensions o
    json-schema.resolve --context=context.json-schema-context
    return result

  to-json -> Map:
    result := {
      "openapi": openapi,
      "info": info.to-json,
      "paths": paths.to-json,
    }
    if json-schema-dialect: result["jsonSchemaDialect"] = json-schema-dialect
    if servers: result["servers"] = servers
    if webhooks: result["webhooks"] = webhooks
    if components: result["components"] = components.to-json
    if security: result["security"] = security
    if tags: result["tags"] = tags.map: it.to-json
    if external-docs: result["externalDocs"] = external-docs.to-json
    add-extensions-to-json_ result
    return result

/**
The object provides metadata about the API.
The metadata may be used by the clients if needed, and may be presented
  in editing or documentation generation tools for convenience.
*/
// https://spec.openapis.org/oas/v3.1.0#info-object
class Info extends Extensionable_:
  /** The title of the API. */
  title/string

  /** A short summary of the API. */
  summary/string?

  /**
  A description of the API.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  A URL to the Terms of Service for the API.
  Must be in the format of a URL.
  */
  terms-of-service/string?

  /**
  The contact information for the exposed API.
  */
  contact/Contact?

  /**
  The license information for the exposed API.
  */
  license/License?

  /**
  The version of the OpenAPI document.
  This version is distinct from the $OpenApi.openapi version, or the
    API implementation version.
  */
  version/string

  constructor
      --.title
      --.summary=null
      --.description=null
      --.terms-of-service=null
      --.contact=null
      --.license=null
      --.version
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Info:
    return Info
      --title=o["title"]
      --summary=o.get "summary"
      --description=o.get "description"
      --terms-of-service=o.get "termsOfService"
      --contact=o.get "contact" --if-present=: Contact.build it context pointer["contact"]
      --license=o.get "license" --if-present=: License.build it context pointer["license"]
      --version=o["version"]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "title": title,
      "version": version,
    }
    if summary: result["summary"] = summary
    if description: result["description"] = description
    if terms-of-service: result["termsOfService"] = terms-of-service
    if contact: result["contact"] = contact.to-json
    if license: result["license"] = license.to-json
    add-extensions-to-json_ result
    return result

/** Contact information for the exposed API. */
// https://spec.openapis.org/oas/v3.1.0#contact-object
class Contact extends Extensionable_:
  /** The identifying name of the contact person/organization. */
  name/string?

  /**
  The URL pointing to the contact information.
  Must be in the format of a URL.
  */
  url/string?

  /**
  The email address of the contact person/organization.
  Must be in the format of an email address.
  */
  email/string?

  constructor
      --.name=null
      --.url=null
      --.email=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Contact:
    return Contact
      --name=o.get "name"
      --url=o.get "url"
      --email=o.get "email"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if name: result["name"] = name
    if url: result["url"] = url
    if email: result["email"] = email
    add-extensions-to-json_ result
    return result


/** License information for the exposed API. */
// https://spec.openapis.org/oas/v3.1.0#license-object
class License extends Extensionable_:
  /** The license name used for the API. */
  name/string

  /**
  An SPDX license expression for the API.
  The identifier field is mutually exclusive of the $url field.

  See https://spdx.org/spdx-specification-21-web-version#h.jxpfx0ykyb60.
  */
  identifier/string?

  /**
  A URL to the license used for the API.
  This must be in the format of a URL.
  The url field is mutually exclusive of the $identifier field.
  */
  url/string?

  constructor
      --.name
      --.identifier=null
      --.url=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> License:
    return License
      --name=o["name"]
      --identifier=o.get "identifier"
      --url=o.get "url"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "name": name,
    }
    if identifier: result["identifier"] = identifier
    if url: result["url"] = url
    add-extensions-to-json_ result
    return result

/** An object representing a server. */
// https://spec.openapis.org/oas/v3.1.0#server-object
class Server extends Extensionable_:
  /**
  A URL to the target host.
  This URL supports server variables and may be relative, to indicate that
    the host location is relative to the location where the OpenAPI document is
    being served.
  Variable substitutions will be made when a variable is named in {brackets}.
  */
  url/string

  /**
  An optional string describing the host designated by the URL.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  A map between a variable name and its value.
  The value is used for substitution in the server's URL template.
  */
  variables/Map?  // from string to ServerVariable.

  constructor
      --.url
      --.description=null
      --.variables=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Server:
    variables := o.get "variables" --if-present=: | o/Map |
      result := {:}
      o.do: | key value |
        result[key] = ServerVariable.build value context pointer[key]
      result
    return Server
      --url=o["url"]
      --description=o.get "description"
      --variables=variables
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "url": url,
    }
    if description: result["description"] = description
    if variables: result["variables"] = variables.map: | key value | value.to-json
    add-extensions-to-json_ result
    return result

/** An object representing a server variable for server URL template substitution. */
// https://spec.openapis.org/oas/v3.1.0#server-variable-object
class ServerVariable extends Extensionable_:
  /**
  An enumeration of string values to be used if the substitution options are
    from a limited set.
  The list must not be empty.
  */
  enum-values/List?  // of string.

  /**
  The default value to use for substitution, which shall be sent if an
    alternate value is not supplied.
  Note this behavior is different than the $Schema's treatment of default values, because in those cases parameter values are optional.
  If the $enum-values is defined, the value must exist in the enum's values.
  */
  default/string

  /**
  An optional description for the server variable.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  constructor
      --.enum-values=null
      --.default
      --.description=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> ServerVariable:
    return ServerVariable
      --enum-values=o.get "enum"
      --default=o["default"]
      --description=o.get "description"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "default": default,
    }
    if enum-values: result["enum"] = enum-values
    if description: result["description"] = description
    add-extensions-to-json_ result
    return result

/**
Holds a set of reusable objects for different aspects of the OpenAPI specification.
All objects defined within the components object will have no effect on the API
  unless they are explicitly referenced from properties outside the components
  object.

For all fields ($schemas, $responses, $parameters, $examples, $request-bodies,
  $headers, $security-schemes, $links, $callbacks), the keys used must match
  the regular expression: ^[a-zA-Z0-9\.\-_]+$.

Example field names: `User`, `User_1`, `User_Name`, `user-name`, `my.org.User`.
*/
// https://spec.openapis.org/oas/v3.1.0#components-object
class Components extends Extensionable_:
  /** An object to hold reusable $Schema objects. */
  schemas/Map? // from string to Schema.

  /** An object to hold reusable $Response objects. */
  responses/Map? // from string to Response or Reference.

  /** An object to hold reusable $Parameter objects. */
  parameters/Map? // from string to Parameter or Reference.

  /** An object to hold reusable $Example objects. */
  examples/Map? // from string to Example or Reference.

  /** An object to hold reusable $RequestBody objects. */
  request-bodies/Map? // from string to RequestBody or Reference.

  /**
  An object to hold reusable $Parameter objects, for which the field
    $Parameter.is-header is set.
  */
  headers/Map? // from string to Header or Reference.

  /** An object to hold reusable $SecurityScheme objects. */
  security-schemes/Map? // from string to SecurityScheme or Reference.

  /** An object to hold reusable $Link objects. */
  links/Map? // from string to Link or Reference.

  /** An object to hold reusable $Callback objects. */
  callbacks/Map? // from string to Callback or Reference.

  /** An object to hold reusable $PathItem objects. */
  path-items/Map? // from string to PathItem.

  constructor
      --.schemas=null
      --.responses=null
      --.parameters=null
      --.examples=null
      --.request-bodies=null
      --.headers=null
      --.security-schemes=null
      --.links=null
      --.callbacks=null
      --.path-items=null
      --extensions/Map?=null:
    super --extensions=extensions

  static map-values_ -> Map?
      components/Map
      key/string
      context/BuildContext
      pointer/JsonPointer
      [construct]
  :
    o := components.get key
    if not o: return null
    o-pointer := pointer[key]
    result := {:}
    return o.map: | entry-key value |
      entry-pointer := o-pointer[entry-key]
      value.get "\$ref"
          --if-present=: Reference.build value context entry-pointer
          --if-absent=: construct.call value context entry-pointer

  static build o/Map context/BuildContext pointer/JsonPointer -> Components:
    return Components
        --schemas=o.get "schemas" --if-present=:
            schemas-pointer := pointer["schemas"]
            it.map: | key value |
              Schema.build value context schemas-pointer[key]
        --responses=map-values_ o "responses" context pointer: | v c p | Response.build v c p
        --parameters=map-values_ o "parameters" context pointer: | v c p | Parameter.build v c p
        --examples=map-values_ o "examples" context pointer: | v c p | Example.build v c p
        --request-bodies=map-values_  o "requestBodies" context pointer: | v c p | RequestBody.build v c p
        --headers=map-values_ o "headers" context pointer: | v c p | Parameter.build-header v c p
        --security-schemes=map-values_ o "securitySchemes" context pointer: | v c p | SecurityScheme.build v c p
        --links=map-values_ o "links" context pointer: | v c p | Link.build v c p
        --callbacks=map-values_ o "callbacks" context pointer: | v c p | Callback.build v c p
        --path-items=map-values_ o "pathItems" context pointer: | v c p | PathItem.build v c p
        --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if schemas: result["schemas"] = schemas.map: | key value | value.to-json
    if responses: result["responses"] = responses.map: | key value | value.to-json
    if parameters: result["parameters"] = parameters.map: | key value | value.to-json
    if examples: result["examples"] = examples.map: | key value | value.to-json
    if request-bodies: result["requestBodies"] = request-bodies.map: | key value | value.to-json
    if headers: result["headers"] = headers.map: | key value | value.to-json
    if security-schemes: result["securitySchemes"] = security-schemes.map: | key value | value.to-json
    if links: result["links"] = links.map: | key value | value.to-json
    if callbacks: result["callbacks"] = callbacks.map: | key value | value.to-json
    if path-items: result["pathItems"] = path-items.map: | key value | value.to-json
    add-extensions-to-json_ result
    return result

/**
Holds the relative paths to the given endpoints and their operations.

The path is appended to the URL from the $Server Object in order to construct
  the full URL. The Paths may be empty, due to Access Control List (ACL)
  constraints. See https://spec.openapis.org/oas/v3.1.0#securityFiltering.
*/
// https://spec.openapis.org/oas/v3.1.0#paths-object
class Paths extends Extensionable_:
  /**
  A map from a path to a $PathItem.

  Each key is a relative path to an individual endpoint.

  ## Endpoints
  The key (relative path to an individual endpoint) must
    begin with a forward slash (`/`). The path is appended (no relative
    URL resolution) to the expanded URL from the $Server.url field in
    order to construct the full URL.
  Path templating is allowed.
  When matching URLs, concrete (non-templated) paths would be matched
    before their templated counterparts. Templated paths with the same
    hierarchy but different templated names must not exist as they are
    identical. In case of ambiguous matching, it's up to the tooling to
    decide which one to use.
  */
  paths/Map

  constructor
      --.paths
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Paths:
    return Paths
      --paths=o.map: | key value | PathItem.build value context pointer[key]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := paths.map: | key value | value.to-json
    add-extensions-to-json_ result
    return result


/**
Describes the operations available on a single path.

A path item may be empty, due to Access Control List (ACL) constraints.
The path itself is still exposed to the documentation viewer but they will
  not know which operations and parameters are available.
*/
class PathItem extends Extensionable_:
  /**
  Allows for a referenced definition of this path item.

  The referenced structure must be in the format of a $PathItem.

  In case a path item object field appears both in the defined object
    and the referenced object, the behavior is undefined.
  */
  ref/string?

  /**
  An optional, string summary, intended to apply to all operations in this path.
  */
  summary/string?

  /**
  An optional, string description, intended to apply to all operations in this path.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  A definition of a GET operation on this path.
  */
  get/Operation?

  /**
  A definition of a PUT operation on this path.
  */
  put/Operation?

  /**
  A definition of a POST operation on this path.
  */
  post/Operation?

  /**
  A definition of a DELETE operation on this path.
  */
  delete/Operation?

  /**
  A definition of a OPTIONS operation on this path.
  */
  options/Operation?

  /**
  A definition of a HEAD operation on this path.
  */
  head/Operation?

  /**
  A definition of a PATCH operation on this path.
  */
  patch/Operation?

  /**
  A definition of a TRACE operation on this path.
  */
  trace/Operation?

  /**
  An alternative $Server list to service all operations in this path.
  */
  servers/List?  // of Server.

  /**
  A list of parameters that are applicable for all the operations described
    under this path.
  These parameters can be overridden at the operation level, but cannot be
    removed there.
  The list must not include duplicated parameters.
  A unique parameter is defined by a combination of a name and location.
  The list can use the $Reference Object to link to parameters that are
    defined at the $Components.parameters level.
  */
  parameters/List?  // of Parameter or Reference.

  constructor
      --.ref=null
      --.summary=null
      --.description=null
      --.get=null
      --.put=null
      --.post=null
      --.delete=null
      --.options=null
      --.head=null
      --.patch=null
      --.trace=null
      --.servers=null
      --.parameters=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> PathItem:
    parameters/List? := null
    o.get "parameters" --if-present=: | json-parameters/List |
        parameters-pointer := pointer["parameters"]
        parameters = []
        json-parameters.size.repeat: | i |
          parameter-pointer := parameters-pointer[i]
          entry := json-parameters[i]
          parameter := entry.get "\$ref"
              --if-present=: Reference.build entry context parameter-pointer
              --if-absent=: Parameter.build entry context parameter-pointer
          parameters.add parameter

    return PathItem
      --ref=o.get "\$ref"
      --summary=o.get "summary"
      --description=o.get "description"
      --get=o.get "get" --if-present=: Operation.build it context pointer["get"]
      --put=o.get "put" --if-present=: Operation.build it context pointer["put"]
      --post=o.get "post" --if-present=: Operation.build it context pointer["post"]
      --delete=o.get "delete" --if-present=: Operation.build it context pointer["delete"]
      --options=o.get "options" --if-present=: Operation.build it context pointer["options"]
      --head=o.get "head" --if-present=: Operation.build it context pointer["head"]
      --patch=o.get "patch" --if-present=: Operation.build it context pointer["patch"]
      --trace=o.get "trace" --if-present=: Operation.build it context pointer["trace"]
      --servers=o.get "servers"
      --parameters=parameters
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if ref: result["\$ref"] = ref
    if summary: result["summary"] = summary
    if description: result["description"] = description
    if get: result["get"] = get.to-json
    if put: result["put"] = put.to-json
    if post: result["post"] = post.to-json
    if delete: result["delete"] = delete.to-json
    if options: result["options"] = options.to-json
    if head: result["head"] = head.to-json
    if patch: result["patch"] = patch.to-json
    if trace: result["trace"] = trace.to-json
    if servers: result["servers"] = servers
    if parameters: result["parameters"] = parameters.map: | value | value.to-json
    add-extensions-to-json_ result
    return result

/** Describes a single API operation on a path. */
class Operation extends Extensionable_:
  /**
  A list of tags for API documentation control.
  Tags can be used for logical grouping of operations by resources or any
    other qualifier.
  */
  tags/List?  // of string.

  /** A short summary of what the operation does. */
  summary/string?

  /**
  A verbose explanation of the operation behavior.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /** Additional external documentation for this operation. */
  external-docs/ExternalDocumentation?

  /**
  Unique string used to identify the operation.

  The id must be unique among all operations described in the API.
  The id value is case-sensitive.
  Tools and libraries may use the operation id to uniquely identify an
    operation, therefore, it is recommended to follow common programming
    naming conventions.
  */
  operation-id/string?

  /**
  A list of parameters that are applicable for this operation.
  If a parameter is already defined at the $PathItem level, the new
    definition will override it, but can never remove it.
  The list must not include duplicated parameters.
  A unique parameter is defined by a combination of a name and location.
  The list can use the $Reference Object to link to parameters that are
    defined at the $Components.parameters level.
  */
  parameters/List?  // of Parameter or Reference.

  /**
  The request body applicable for this operation.
  The requestBody is only supported in HTTP methods where the HTTP 1.1
    specification RFC7231 has explicitly defined semantics for request
    bodies. See https://httpwg.org/specs/rfc7231.html.
  In other cases where the HTTP spec is vague (such as `GET`, `HEAD`
    and `DELETE`), a $request-body is permitted but does not have
    well-defined semantics and should be avoided if possible.
  */
  request-body/any  // Either a RequestBody or a Reference.

  /**
  The list of possible responses as they are returned from executing this operation.
  */
  responses/Responses?

  /**
  A map of possible out-of band callbacks related to the parent operation.
  The key is a unique identifier for the $Callback Object.
  Each value in the map is a $Callback Object that describes a request
    that may be initiated by the API provider and the expected responses.
  */
  callbacks/Map?  // from string to Callback or Reference.

  /**
  Declares this operation to be deprecated.
  Consumers should refrain from usage of the declared operation.
  Default value is `false`.
  */
  deprecated/bool?

  /**
  A declaration of which security mechanisms can be used for this operation.

  The list of values includes alternative security requirement objects
    that can be used. Only one of the security requirement objects need
    to be satisfied to authorize a request.

  // TODO(florian): empty security requirement {} doesn't work.
  To make security optional, an empty security requirement ({}) can be
    included in the list.

  This definition overrides any declared top-level security.
  To remove a top-level security declaration, an empty list can be used.
  */
  security/List?  // of SecurityRequirement.

  /**
  An alternative $Server array to service this operation.
  If an alternative $Server object is specified at the $PathItem or
    $Components level, it will be overridden by this value.
  */
  servers/List?  // of Server.

  constructor
      --.tags=null
      --.summary=null
      --.description=null
      --.external-docs=null
      --.operation-id=null
      --.parameters=null
      --.request-body=null
      --.responses
      --.callbacks=null
      --.deprecated=null
      --.security=null
      --.servers=null
      --extensions/Map?=null:
    super --extensions=extensions

  static ref-or-object_ o context/BuildContext pointer/JsonPointer [construct] -> any:
    return o.get "\$ref"
        --if-present=: Reference.build o context pointer
        --if-absent=: construct.call o context pointer

  static map-list_ list/List pointer/JsonPointer [construct] -> List:
    result := []
    list.size.repeat: | i |
      entry :=list[i]
      result.add (construct.call entry pointer[i])
    return result

  static build o/Map context/BuildContext pointer/JsonPointer -> Operation:
    return Operation
      --tags=o.get "tags"
      --summary=o.get "summary"
      --description=o.get "description"
      --external-docs=o.get "externalDocs" --if-present=: ExternalDocumentation.build it context pointer["externalDocs"]
      --operation-id=o.get "operationId"
      --parameters=o.get "parameters" --if-present=: | json-parameters/List |
          parameters-pointer := pointer["parameters"]
          map-list_ json-parameters parameters-pointer: | ref-or-parameter parameter-pointer/JsonPointer |
            ref-or-object_ ref-or-parameter context parameter-pointer: | v c p | Parameter.build v c p
      --request-body=o.get "requestBody" --if-present=:
          ref-or-object_ it context pointer["requestBody"]: | v c p | RequestBody.build v c p
      --responses=o.get "responses" --if-present=: Responses.build it context pointer["responses"]
      --callbacks=o.get "callbacks" --if-present=: | json-callbacks/Map |
          callbacks-pointer := pointer["callbacks"]
          json-callbacks.map: | entry-key ref-or-callback |
            ref-or-object_ ref-or-callback context callbacks-pointer[entry-key]: | v c p | Callback.build v c p
      --deprecated=o.get "deprecated"
      --security=o.get "security" --if-present=: | json-security/List |
          map-list_ json-security pointer["security"]: | json-security/Map p/JsonPointer |
            SecurityRequirement.build json-security context p
      --servers=o.get "servers" --if-present=: | json-servers/List |
          map-list_ json-servers pointer["servers"]: | server/Map p/JsonPointer |
            Server.build server context p
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if tags: result["tags"] = tags
    if summary: result["summary"] = summary
    if description: result["description"] = description
    if external-docs: result["externalDocs"] = external-docs.to-json
    if operation-id: result["operationId"] = operation-id
    if parameters: result["parameters"] = parameters.map: | value | value.to-json
    if request-body: result["requestBody"] = request-body.to-json
    if responses: result["responses"] = responses.to-json
    if callbacks: result["callbacks"] = callbacks.map: | key value | value.to-json
    if deprecated: result["deprecated"] = deprecated
    if security: result["security"] = security.map: | value | value.to-json
    if servers: result["servers"] = servers.map: | value | value.to-json
    add-extensions-to-json_ result
    return result

/**
Allows referencing an external resource for extended documentation.
*/
class ExternalDocumentation extends Extensionable_:
  /**
  A description of the target documentation.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  The URL for the target documentation.
  Value must be in the format of a URL.
  */
  url/string

  constructor --.description=null --.url --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> ExternalDocumentation:
    return ExternalDocumentation
      --description=o.get "description"
      --url=o["url"]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "url": url,
    }
    if description: result["description"] = description
    add-extensions-to-json_ result
    return result

/**
A description for a single operation parameter.

A unique parameter is defined by a combination of a name and location.

# Parameter Locations
There are four possible parameter locations specified by the `in` field:
- `path` - Used together with Path Templating, where the parameter value is
  actually part of the operation's URL. This does not include the host or base
  path of the API. For example, in `/items/{itemId}`, the path parameter is
  `itemId`.
- `query` - Parameters that are appended to the URL. For example, in
  `/items?id=###`, the query parameter is `id`.
- `header` - Custom headers that are expected as part of the request.
  Note that [RFC7230](https://datatracker.ietf.org/doc/html/rfc7230#section-3.2)
  states header names are case insensitive.
- `cookie` - Used to pass a specific cookie value to the API.

A parameter must have either $schema or $content set, but not both.

# Headers
Headers are the same as parameters, except for the following differences:
- The $Parameter.name field only exists in parameters but not in headers. For
  header objects, the name is given in the corresponding headers map, and the
  $name field is set to "".
- The $Parameter.in is implicitly set to $HEADER.
*/
class Parameter extends Extensionable_:
  static PATH ::= "path"
  static QUERY ::= "query"
  static HEADER ::= "header"
  static COOKIE ::= "cookie"

  /**
  Path-style parameter defined by
    [RFC6570](https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.7).

  Type: primitive, array, object.
  $in: `"path"` ($PATH).
  */
  static STYLE-MATRIX ::= "matrix"
  /**
  Label style parameters defined by
    [RFC6570](https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.5).

  Type: primitive, array, object.
  $in: `"path"` ($PATH).
  */
  static STYLE-LABEL ::= "label"
  /**
  Form style parameters defined by
    [RFC6570](https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.8).

  This option replaces `collectionFormat` with a `csv` (when $explode is
    false), `multi` (when $explode is true) value from OpenAPI 2.0.

  Type: primitive, array, object.
  $in: `"query"` ($QUERY), `"cookie"` ($COOKIE).
  */
  static STYLE-FORM ::= "form"
  /**
  Simple style parameters defined by
    [RFC6570](https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.2).

  This option replaces `collectionFormat` with a `csv` value from OpenAPI 2.0.

  Type: array.
  $in: `"path"` ($PATH), `"header"` ($HEADER).
  */
  static STYLE-SIMPLE ::= "simple"
  /**
  Space separated array or object values.

  This option replaces `collectionFormat` equal to `ssv` from OpenAPI 2.0.

  Type: array, object.
  $in: `"query"` ($QUERY).
  */
  static STYLE-SPACE-DELIMITED ::= "spaceDelimited"
  /**
  Pipe separated array or object values.

  This option replaces `collectionFormat` equal to `pipes` from OpenAPI 2.0.

  Type: array, object.
  $in: `"query"` ($QUERY).
  */
  static STYLE-PIPE-DELIMITED ::= "pipeDelimited"
  /**
  Provides a simple way of rendering nested objects using form parameters.

  Type: object.
  $in: `"query"` ($QUERY).
  */
  static STYLE-DEEP-OBJECT ::= "deepObject"

  /**
  The name of the parameter.
  Parameter names are case sensitive.

  - If $in is equal to `"path"` ($PATH), the name field must correspond
    to the associated path segment from the path field in the $Paths
    Object. See
    [Path Templating](https://spec.openapis.org/oas/v3.1.0#pathTemplating)
    for further information.
  - If $in is equal to `"header"` ($HEADER) and this $name field is
    equal to "Accept", "Content-Type" or "Authorization", this parameter
    definition shall be ignored.
  - For all other cases, this $name corresponds to the parameter name used
    by the $in property.
  */
  name/string

  /**
  The location of the parameter.

  Possible values are `"path"` ($PATH), `"query"` ($QUERY), `"header"` ($HEADER)
    or `"cookie"` ($COOKIE).
  */
  in/string

  /**
  A brief description of the parameter.

  This could contain examples of use.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  Whether this parameter is mandatory.

  If the parameter location $in is `"path"` ($PATH), this property is required
    and its value must be `true`.
  Otherwise, the property may be included and its default value is `false`.
  */
  required/bool?

  /**
  Whether this parameter is deprecated.

  Default value is `false`.
  */
  deprecated/bool?

  /**
  Sets the ability to pass empty-valued parameters.

  This is valid only for query parameters and allows sending a parameter
    with an empty value.

  Default value is `false`.
  */
  allow-empty-value/bool?

  /**
  Describes how the parameter value will be serialized depending on the type
    of the parameter value.

  Default values (based on value of $in):
  - for "query" ($QUERY): `"form"`
  - for "path" ($PATH): `"simple"`
  - for "header" ($HEADER): `"simple"`
  - for "cookie" ($COOKIE): `"form"`

  This field is mutually exclusive with the $content field.

  # Examples
  See https://spec.openapis.org/oas/v3.1.0#style-examples.

  Assume a parameter named `color` has one of the following values:
  - `string -> "blue"`
  - `array -> ["blue", "black", "brown"]`
  - `object -> {"R": 100, "G": 200, "B": 150}`

  The following entries show examples of rendering differences for each value:
  - $style == $STYLE-MATRIX, $explode == false
    - empty: `;color`
    - string: `;color=blue`
    - array: `;color=blue,black,brown`
    - object: `;color=R,100,G,200,B,150`
  - $style == $STYLE-MATRIX, $explode == true
    - empty: `;color`
    - string: `;color=blue`
    - array: `;color=blue;color=black;color=brown`
    - object: `;R,100;G,200;B,150`
  - $style == $STYLE-LABEL, $explode == false
    - empty: `.` (dot character)
    - string: `.blue`
    - array: `.blue.black.brown`
    - object: `.R.100.G.200.B.150`
  - $style == $STYLE-LABEL, $explode == true
    - empty: `.` (dot character)
    - string: `.blue`
    - array: `.blue.black.brown`
    - object: `.R=100.G=200.B=150`
  - $style == $STYLE-FORM, $explode == false
    - empty: `color=`
    - string: `color=blue`
    - array: `color=blue,black,brown`
    - object: `color=R,100,G,200,B,150`
  - $style == $STYLE-FORM, $explode == true
    - empty: `color=`
    - string: `color=blue`
    - array: `color=blue&color=black&color=brown`
    - object: `R=100&G=200&B=150`
  - $style == $STYLE-SIMPLE, $explode == false
    - empty: not available
    - string: `blue`
    - array: `blue,black,brown`
    - object: `R,100,G,200,B,150`
  - $style == $STYLE-SIMPLE, $explode == true
    - empty: not available
    - string: `blue`
    - array: `blue,black,brown`
    - object: `R=100,G=200,B=150`
  - $style == $STYLE-SPACE-DELIMITED, $explode == false
    - empty: not available
    - string: not available
    - array: `blue%20black%20brown`
    - object: `R%20100%20G%20200%20B%20150`
  - $style == $STYLE-PIPE-DELIMITED, $explode == false
    - empty: not available
    - string: not available
    - array: `blue|black|brown`
    - object: `R|100|G|200|B|150`
  - $style == $STYLE-DEEP-OBJECT, $explode == true
    - empty: not available
    - string: not available
    - array: not available
    - object: `color[R]=100&color[G]=200&color[B]=150`
  */
  style/string?

  /**
  Whether parameter values of type `array` or `object` generate separate
    parameters for each value of the array or key-value pair of the map.
  For other types of parameters this property has no effect.

  When $style is `"form"`, the default value is `true`.
  For all other styles, the default value is `false`.
  */
  explode/bool?

  /**
  Whether the parameter value should allow reserved characters, as defined
    by [RFC3986](https://datatracker.ietf.org/doc/html/rfc3986#section-2.2)
    `:/?#[]@!$&'()*+,;=` to be included without percent-encoding.
  This property only applies to parameters with an $in value of `"query"`
    ($QUERY). The default value is `false`.
  */
  allow-reserved/bool?

  /**
  The schema defining the type used for the parameter.
  */
  schema/Schema?

  /**
  Example of the parameter's potential value.

  The example should match the specified schema and encoding properties
    if present.
  This example field is mutually exclusive with the $examples field.
  If referencing a $schema that contains an example, the $example value
    shall override the example provided by the schema.
  To represent examples of media types that cannot naturally be represented
    in JSON or YAML, a string value can contain the example with escaping
    where necessary.
  */
  example/any?

  /**
  Examples of the parameter's potential value.

  Each example should contain a value in the correct format as specified
    in the parameter encoding.
  The examples field is mutually exclusive with the $example field.
  If referencing a $schema that contains an example, the
    examples value shall override the example provided by the schema.
  */
  examples/Map?  // From string to Example or Reference.

  /**
  A map containing the representations for the parameter.

  The key is the media type and the value describes it.
  The map must only contain one entry.
  */
  content/Map?  // From string to MediaType.

  /**
  Whether this object is a header.
  */
  is-header/bool

  constructor
      --.name
      --.in
      --.description=null
      --.required=null
      --.deprecated=null
      --.allow-empty-value=null
      --.style=null
      --.explode=null
      --.allow-reserved=null
      --.schema=null
      --.example=null
      --.examples=null
      --.content=null
      --.is-header
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Parameter:
    return build_ o o["name"] o["in"] --is-header=false context pointer

  static build-header o/Map context/BuildContext pointer/JsonPointer -> Parameter:
    return build_ o "" HEADER --is-header=true context pointer

  static build_ -> Parameter
      o/Map
      name/string
      in/string
      --is-header/bool
      context/BuildContext
      pointer/JsonPointer
  :
    return Parameter
      --name=name
      --in=in
      --description=o.get "description"
      --required=o.get "required"
      --deprecated=o.get "deprecated"
      --allow-empty-value=o.get "allowEmptyValue"
      --style=o.get "style"
      --explode=o.get "explode"
      --allow-reserved=o.get "allowReserved"
      --schema=o.get "schema" --if-present=: Schema.build it context pointer["schema"]
      --example=o.get "example"
      --examples=o.get "examples" --if-present=: | json-examples/Map |
          examples-pointer := pointer["examples"]
          json-examples.map: | example-key/string value/Map |
            example-pointer := examples-pointer[example-key]
            value.get "\$ref"
                --if-present=: Reference.build value context example-pointer
                --if-absent=: Example.build value context example-pointer
      --content=o.get "content" --if-present=: | json-content/Map |
          content-pointer := pointer["content"]
          json-content.map: | key/string value/Map |
            MediaType.build value context content-pointer[key]
      --is-header=is-header
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if not is-header:
      result["name"] = name
      result["in"] = in
    if description: result["description"] = description
    if required: result["required"] = required
    if deprecated: result["deprecated"] = deprecated
    if allow-empty-value: result["allowEmptyValue"] = allow-empty-value
    if style: result["style"] = style
    if explode: result["explode"] = explode
    if allow-reserved: result["allowReserved"] = allow-reserved
    if schema: result["schema"] = schema.to-json
    if example: result["example"] = example
    if examples: result["examples"] = examples.map: | _ value | value.to-json
    if content: result["content"] = content.map: | _ value | value.to-json
    add-extensions-to-json_ result
    return result

/**
A single request body.
*/
class RequestBody extends Extensionable_:
  /**
  A brief description of the request body.
  This could contain examples of use.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  The content of the request body.
  The key is a media type or media type range and the value describes it.
  For requests that match multiple keys, only the most specific key is
    applicable. For example, `text/plain` overrides `text/\*`

  For media type range see https://tools.ietf.org/html/rfc7231#appendix-D.
  */
  content/Map  // From string to MediaType.

  /**
  Whether the request body is required in the request.
  Defaults to `false`.
  */
  required/bool?

  constructor --.description=null --.content --.required=null --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> RequestBody:
    content-json := o["content"]
    content-pointer := pointer["content"]
    content := content-json.map: | key value |
      MediaType.build value context content-pointer[key]
    return RequestBody
      --description=o.get "description"
      --content=content
      --required=o.get "required"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "content": content.map: | _ value | value.to-json
    }
    if description: result["description"] = description
    if required: result["required"] = required
    add-extensions-to-json_ result
    return result

/**
Groups the schema, examples and encoding definitions for a single media type.
*/
class MediaType extends Extensionable_:
  /**
  The schema defining the content of the request, response, or parameter.
  */
  schema/Schema?

  /**
  Example of the media type.
  The example object should be in the correct format as specified by the
    media type.
  The example field is mutually exclusive with the $examples field.
  If referencing a $schema that contains an example, the $example value
    shall override the example provided by the schema.
  */
  example/any?

  /**
  Examples of the media type.

  Each example object should match the media type and specified schema if
    present.
  The examples field is mutually exclusive with the $example field.
  If referencing a $schema that contains an example, the
    examples value shall override the example provided by the schema.
  */
  examples/Map?  // From string to Example or Reference.

  /**
  A map between a property name and its encoding information.

  The key, being the property name, must exist in the schema as a property.
  The encoding object shall only apply to `requestBody` objects when the
    media type is `multipart` or `application/x-www-form-urlencoded`.
  */
  encoding/Map?  // From string to Encoding.

  constructor
      --.schema=null
      --.example=null
      --.examples=null
      --.encoding=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> MediaType:
    return MediaType
      --schema=o.get "schema" --if-present=: Schema.build it context pointer["schema"]
      --example=o.get "example"
      --examples=o.get "examples" --if-present=: | json-examples/Map |
          examples-pointer := pointer["examples"]
          json-examples.map: | key value |
            example-pointer := examples-pointer[key]
            value.get "\$ref"
                --if-present=: Reference.build value context example-pointer
                --if-absent=: Example.build value context example-pointer
      --encoding=o.get "encoding" --if-present=: | json-encoding/Map |
          encoding-pointer := pointer["encoding"]
          json-encoding.map: | key value | Encoding.build value context encoding-pointer[key]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if schema: result["schema"] = schema.to-json
    if example: result["example"] = example
    if examples: result["examples"] = examples.map: | _ value | value.to-json
    if encoding: result["encoding"] = encoding.map: | _ value | value.to-json
    add-extensions-to-json_ result
    return result

/**
A single encoding definition applied to a single schema property.
*/
class Encoding extends Extensionable_:
  /**
  The Content-Type for encoding a specific property.

  The default value depends on the property type:
  - for `object-application/json` the default is defined based on the inner type.
  - for `array` the default is defined based on the inner type.
  - for all other types the default is `application/octet-stream`.

  The value can be a specific media type (e.g. `application/json`),
    a wildcard media type (e.g. `image/\*`), or a comma-separated list of
    the two types.
  */
  content-type/string?

  /**
  A map allowing additional information to be provided as headers, for example
    `Content-Disposition`. `Content-Type` is described separately and is
    ignored in this section. This property is ignored if the request
    body media type is not a `multipart`.

  The values are either of type $Parameter, with $Parameter.is-header set to true
    or of type $Reference.
  */
  headers/Map?

  /**
  Describes how a specific property value will be serialized depending on
    its type.

  See $Parameter for details on the style property.

  The behavior follows the same values as `query` parameters, including default values.
  This property is ignored if the request body media type is not
    `application/x-www-form-urlencoded` or `multipart/form-data`.
  If a value is explicitly defined, then the value of $content-type (implicit or
    explicit) is ignored.
  */
  style/string?

  /**
  Whether property values of type `array` or `object` should be exploded.

  When this is set to true, property values of type `array` or `object`
    generate separate parameters for each value of the array, or key-value
    pair of the map. For other types of properties this property has no effect.

  When $style is `form`, the default value is true. For all other styles,
    the default value is false.

  This property is ignored if the request body media type is not
    `application/x-www-form-urlencoded` or `multipart/form-data`.

  If a value is explicitly defined, then the value of $content-type (implicit
    or explicit) is ignored.
  */
  explode/bool?

  /**
  Whether parameter values allow reserved characters.

  Determines whether the parameter value allows reserved characters, as defined
    by [RFC3986](https://datatracker.ietf.org/doc/html/rfc3986#section-2.2)
    `:/?#[]@!$&'()*+,;=` to be included without percent-encoding.

  The default value is false.

  This property is ignored if the request body media type is not
    `application/x-www-form-urlencoded` or `multipart/form-data`.

  If a value is explicitly defined, then the value of $content-type (implicit
    or explicit) is ignored.
  */
  allow-reserved/bool?

  constructor
      --.content-type=null
      --.headers=null
      --.style=null
      --.explode=null
      --.allow-reserved=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Encoding:
    headers := o.get "headers" --if-present=: | json-headers/Map |
        headers-pointer := pointer["headers"]
        json-headers.map: | key value |
          value.get "\$ref"
              --if-present=: Reference.build value context headers-pointer[key]
              --if-absent=: Parameter.build-header value context headers-pointer[key]
    return Encoding
      --content-type=o.get "contentType"
      --headers=headers
      --style=o.get "style"
      --explode=o.get "explode"
      --allow-reserved=o.get "allowReserved"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if content-type: result["contentType"] = content-type
    if headers: result["headers"] = headers.map: | _ value | value.to-json
    if style: result["style"] = style
    if explode: result["explode"] = explode
    if allow-reserved: result["allowReserved"] = allow-reserved
    add-extensions-to-json_ result
    return result

/**
A container for the expected responses of an operation.
Maps a HTTP response code to the expected response.

The documentation is not necessarily expected to cover all possible HTTP
  response codes because they may not be known in advance. However, documentation
  is expected to cover a successful operation response and any known errors.

The $default field may be used as a default response object for all HTTP codes
  that are not covered individually by this object.

An instance of this class must contain at least one response code, and if
  only one response code is provided, it should be the response for a
  successful operation call.
*/
class Responses extends Extensionable_:
  /**
  The documentation of responses other than the ones declared for specific
    HTTP response codes.

  It can be used to cover undeclared responses.
  */
  default/any  // Either a Response or a Reference.

  /**
  A map from status code (string) to the expected response.

  This map may contain entries for ranges of response codes. In that case,
    the key is of the form `2XX` where the `X` is a wildcard. The following
    ranges are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
  If a response is defined using an explicit code, then the explicit code
    takes precedence over the range definition for that code.
  */
  responses/Map  // From string to Response or Reference.

  constructor --.default=null --.responses={:} --extensions/Map?=null:
    if not default and responses.size == 0:
      throw "Responses must contain at least one response"
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Responses:
    default := o.get "default" --if-present=: | response-json/Map |
      default-pointer := pointer["default"]
      response-json.get "\$ref"
          --if-present=: Reference.build response-json context default-pointer
          --if-absent=: Response.build response-json context default-pointer

    responses := {:}
    o.do: | key/string value/any |
      // The key must either be a status code (3 digits) or a range (1 digit
      // followed by 2 'X' characters).
      if key.size == 3 and
          '1' <= key[0] <= '5' and
          ((key[1] == 'X' and key[2] == 'X') or
            ('0' <= key[1] <= '9' and '0' <= key[2] <= '9')):
        code := key
        response-json := value
        response-pointer := pointer[code]
        response := response-json.get "\$ref"
            --if-present=: Reference.build response-json context response-pointer
            --if-absent=: Response.build response-json context response-pointer
        responses[code] = response

    return Responses
        --default=default
        --responses=responses
        --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if default: result["default"] = default.to-json
    responses.do: | key value |
      result[key] = value.to-json
    add-extensions-to-json_ result
    return result

/**
A single response from an API Operation, including design-time, static
  links to operations based on the response.
*/
class Response extends Extensionable_:
  /**
  A short description of the response.
  CommonMark syntax may be used for rich text representation.
  */
  description/string

  /**
  The list of headers that are sent with the response.

  Maps a header name to its definition.
  Following [RFC7230](https://datatracker.ietf.org/doc/html/rfc7230#section-3.2),
    header names are case-insensitive.

  If a response header is defined with the name "Content-Type", it is ignored.
  */
  headers/Map?  // From string to Header or Reference.

  /**
  A map containing descriptions of potential response payloads.
  The key is a media type or media type range and the value describes it.
  For responses that match multiple keys, only the most specific key is
    applicable. For example, `text/plain` overrides `text/\*`.

  For media type range see https://tools.ietf.org/html/rfc7231#appendix-D.
  */
  content/Map?  // From string to MediaType.

  /**
  A map of operations links that can be followed from the response.
  The key of the map is a short name for the link, following the naming
    constraints of the names for Component Objects.
  */
  links/Map?  // From string to Link or Reference.

  constructor --.description=null --.headers=null --.content --.links=null --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Response:
    headers := o.get "headers" --if-present=: | json-headers/Map |
        headers-pointer := pointer["headers"]
        json-headers.map: | key value |
          value.get "\$ref"
              --if-present=: Reference.build value context headers-pointer[key]
              --if-absent=: Parameter.build-header value context headers-pointer[key]
    content := o.get "content" --if-present=: | json-content/Map |
        content-pointer := pointer["content"]
        json-content.map: | key value |
          MediaType.build value context content-pointer[key]
    links := o.get "links" --if-present=: | json-links/Map |
        links-pointer := pointer["links"]
        json-links.map: | key value |
          value.get "\$ref"
              --if-present=: Reference.build value context links-pointer[key]
              --if-absent=: Link.build value context links-pointer[key]
    return Response
      --description=o["description"]
      --headers=headers
      --content=content
      --links=links
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "description": description,
    }
    if headers: result["headers"] = headers.map: | _ value | value.to-json
    if content: result["content"] = content.map: | _ value | value.to-json
    if links: result["links"] = links.map: | _ value | value.to-json
    add-extensions-to-json_ result
    return result

/**
A runtime expression as defined by
  https://spec.openapis.org/oas/v3.1.0#runtime-expressions
*/
class RuntimeExpression:
  expression/string

  constructor .expression:

  hash-code -> int:
    return expression.hash-code

  operator == other -> bool:
    return other is RuntimeExpression and expression == other.expression

  static try-parse str/string -> RuntimeExpression?:
    // TODO(florian): implement this.
    return str.starts-with "\$"
        ? RuntimeExpression str
        : null

/**
A map of possible out-of band callbacks related to the parent operation.
*/
class Callback extends Extensionable_:
  /**
  A map of possible out-of band callbacks related to the parent operation.

  Each key is a $RuntimeExpression.
  Each value is a $PathItem (or $Reference) that describes a
    set of requests that may be initiated by the API provider and the
    expected responses.

  See $OpenApi.webhooks to describe incoming requests from the API provider
    independent from another API call.
  */
  callbacks/Map  // From RuntimeExpression to PathItem or Reference.

  constructor --.callbacks --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer:
    callbacks := {:}
    o.do: | key/string value |
      callbacks[RuntimeExpression key] = value.get "\$ref"
          --if-present=: Reference.build value context pointer[key]
          --if-absent=: PathItem.build value context pointer[key]
    return Callback
        --callbacks=callbacks
        --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    callbacks.do: | key value |
      result[key.expression] = value.to-json
    return result

/**
An example for the API operation.
*/
class Example extends Extensionable_:
  /** A short description of the example. */
  summary/string?

  /**
  A long description of the example.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  An embedded literal example.
  This field and the $external-value fields are mutually exclusive.

  Examples of media types that cannot be represent in JSON/Yaml can be
    described using a string value, escaping where necessary.
  */
  value/any?

  /**
  A URI that points to the literal example.
  This provides the capability to reference examples that cannot easily be
    included in JSON or YAML documents.

  This field and the $value field are mutually exclusive.
  */
  external-value/string?

  constructor
      --.summary=null
      --.description=null
      --.value=null
      --.external-value=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Example:
    return Example
      --summary=o.get "summary"
      --description=o.get "description"
      --value=o.get "value"
      --external-value=o.get "externalValue"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if summary: result["summary"] = summary
    if description: result["description"] = description
    if value: result["value"] = value
    if external-value: result["externalValue"] = external-value
    add-extensions-to-json_ result
    return result

class Link extends Extensionable_:
  /**
  A relative or absolute URI reference to an OAS operation.

  This field is mutually exclusive of the $operation-id field.
  It must point to an $Operation object.
  Relative $operation-ref values may be used to locate an existing
    $Operation object in the OpenAPI document.
  */
  operation-ref/string?

  /**
  The name of an existing, resolvable OAS operation, as defined with a
    unique $operation-id.

  This field is mutually exclusive of the $operation-ref field.
  */
  operation-id/string?

  /**
  A map of parameters to pass to an operation as specified with $operation-id
    or identified via $operation-ref.

  The key is the parameter name to be used.
  The value can be a constant or an $RuntimeExpression to be evaluated and passed
    to the linked operation.
  The parameter name can be qualified using the parameter location `[{in}.]{name}` for
    operations that use the same parameter name in different locations (e.g. `path.id`).
  */
  parameters/Map?  // From string to any.

  /**
  A literal value or $RuntimeExpression to use as a request body when calling
    the target operation.
  */
  request-body/any?

  /**
  A description of the link.
  */
  description/string?

  /**
  A server object to be used by the target operation.
  */
  server/Server?

  constructor
      --.operation-ref=null
      --.operation-id=null
      --.parameters={:}
      --.request-body=null
      --.description=null
      --.server=null
      --extensions/Map?=null:
    if not operation-ref and not operation-id:
      throw "Link must contain either an operation-ref or an operation-id"
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Link:
    parameters := o.get "parameters" --if-present=: | json-parameters/Map |
        json-parameters.map: | key value |
          runtime := value is string
              ? RuntimeExpression.try-parse value
              : value
          runtime or value
    request-body := o.get "requestBody" --if-present=: | json-body |
        runtime := json-body is string
            ? RuntimeExpression.try-parse json-body
            : json-body
        runtime or json-body

    return Link
      --operation-ref=o.get "operationRef"
      --operation-id=o.get "operationId"
      --parameters=parameters
      --request-body=request-body
      --description=o.get "description"
      --server=o.get "server" --if-present=: Server.build it context pointer["server"]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if operation-ref: result["operationRef"] = operation-ref
    if operation-id: result["operationId"] = operation-id
    if parameters:
      json-parameters := parameters.map: | _ value |
        value is RuntimeExpression
            ? value.expression
            : value
      result["parameters"] = json-parameters
    if request-body:
      result["requestBody"] = request-body is RuntimeExpression
          ? request-body.expression
          : request-body
    if description: result["description"] = description
    if server: result["server"] = server.to-json
    add-extensions-to-json_ result
    return result

class Tag extends Extensionable_:
  /**
  The name of the tag.
  */
  name/string

  /**
  A short description of the tag.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  /**
  Additional external documentation for this tag.
  */
  external-docs/ExternalDocumentation?

  constructor --.name --.description=null --.external-docs=null --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> Tag:
    return Tag
      --name=o["name"]
      --description=o.get "description"
      --external-docs=o.get "externalDocs" --if-present=:
          ExternalDocumentation.build it context pointer["externalDocs"]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "name": name,
    }
    if description: result["description"] = description
    if external-docs: result["externalDocs"] = external-docs.to-json
    add-extensions-to-json_ result
    return result

/**
A simple object to allow referencing other components in the OpenAPI
  document; internally and externally.

The $ref string value contains a [URI](https://tools.ietf.org/html/rfc3986)
  which identifies the location of the value being referenced.

See [Reference Object](https://spec.openapis.org/oas/v3.1.0#relativeReferencesURI)
  for more information.

Note: this class does not allow to be extended.
*/
class Reference:
  /**
  The reference identifier.
  Must be in the form of a URI.
  */
  ref/string

  /**
  A short summary.
  By default should override that of the referenced component.
  If the referenced object-type does not have a summary field, this field
    has no effect.
  */
  summary/string?

  /**
  A description.
  By default should override that of the referenced component.
  If the referenced object-type does not have a description field, this
    field has no effect.
  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  constructor --.ref --.summary=null --.description=null:

  static build o/Map context/BuildContext pointer/JsonPointer -> Reference:
    return Reference
      --ref=o["\$ref"]
      --summary=o.get "summary"
      --description=o.get "description"

  to-json -> Map:
    result := {
      "\$ref": ref,
    }
    if summary: result["summary"] = summary
    if description: result["description"] = description
    return result

class Schema:
  original-json_/Map
  schema/json-schema.JsonSchema

  constructor --original-json/Map --.schema:
    this.original-json_ = original-json

  static build o/Map context/BuildContext pointer/JsonPointer -> Schema:
    schema := json-schema.parse o --context=context.json-schema-context
    return Schema --original-json=o --schema=schema

  to-json -> Map:
    return original-json_

/**
A security scheme that can be used by the operations.

The following security schemes are supported by OpenAPI:
- HTTP authentication.
- An API key (either as a header or as a query parameter).
- Mutual TLS (use of a client certificate).
- OAuth2's common flows: implicit (deprecated), password, client credentials
  and authorization code.
  Defined in [RFC6749](https://datatracker.ietf.org/doc/html/rfc6749).
- OpenID Connect Discovery.
*/
class SecurityScheme extends Extensionable_:
  static API-KEY ::= "apiKey"
  static HTTP ::= "http"
  static MUTUAL-TLS ::= "mutualTLS"
  static OAUTH2 ::= "oauth2"
  static OPENID-CONNECT ::= "openIdConnect"

  /**
  The type of the security scheme.

  Must be one of $API-KEY, $HTTP, $MUTUAL-TLS, $OAUTH2, or $OPENID-CONNECT.
  */
  type/string

  /**
  A short description for security scheme.

  CommonMark syntax may be used for rich text representation.
  */
  description/string?

  constructor --.type --.description=null --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> SecurityScheme:
    type := o["type"]
    if type == API-KEY: return SecuritySchemeApiKey.build o context pointer
    if type == HTTP: return SecuritySchemeHttp.build o context pointer
    if type == MUTUAL-TLS: return SecuritySchemeMutualTls.build o context pointer
    if type == OAUTH2: return SecuritySchemeOAuth2.build o context pointer
    if type == OPENID-CONNECT: return SecuritySchemeOpenIdConnect.build o context pointer
    throw "Unknown security scheme type: $type"

  to-json -> Map:
    result := {
      "type": type
    }
    if description: result["description"] = description
    add-extensions-to-json_ result
    return result


class SecuritySchemeApiKey extends SecurityScheme:
  static HEADER ::= "header"
  static QUERY ::= "query"
  static COOKIE ::= "cookie"

  /**
  The name of the header, query, or cookie parameter to be used.
  */
  name/string

  /**
  The location of the API key.

  Must be one of $HEADER, $QUERY, or $COOKIE.
  */
  in/string

  constructor --.name --.in --description/string?=null --extensions/Map?=null:
    super --type=SecurityScheme.API-KEY --description=description --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> SecuritySchemeApiKey:
    return SecuritySchemeApiKey
      --name=o["name"]
      --in=o["in"]
      --description=o.get "description"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["name"] = name
    result["in"] = in
    return result

class SecuritySchemeHttp extends SecurityScheme:
  /**
  The name of the HTTP Authorization scheme to be used in the Authorization header
    as defined in [RFC7235](https://httpwg.org/specs/rfc7235.html).

  The value should be registered in the
    [IANA Authentication Scheme registry](https://www.iana.org/assignments/http-authschemes/http-authschemes.xhtml).
  */
  scheme/string

  /**
  A hint to the client to identify how the bearer token is formatted.

  Bearer tokens are usually generated by the server, so this information is
    primarily for documentation purposes.
  */
  bearer-format/string?

  constructor --.scheme --.bearer-format=null --description/string?=null --extensions/Map?=null:
    super --type=SecurityScheme.HTTP --description=description --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> SecuritySchemeHttp:
    return SecuritySchemeHttp
      --scheme=o["scheme"]
      --bearer-format=o.get "bearerFormat"
      --description=o.get "description"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["scheme"] = scheme
    if bearer-format: result["bearerFormat"] = bearer-format
    return result

class SecuritySchemeMutualTls extends SecurityScheme:
  constructor --description/string?=null --extensions/Map?=null:
    super --type=SecurityScheme.MUTUAL-TLS --description=description --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> SecuritySchemeMutualTls:
    return SecuritySchemeMutualTls
      --description=o.get "description"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    return super

class SecuritySchemeOAuth2 extends SecurityScheme:
  /**
  An object containing configuration information for the OAuth2 flow types.
  */
  flows/OAuthFlows

  constructor --.flows --description/string?=null --extensions/Map?=null:
    super --type=SecurityScheme.OAUTH2 --description=description --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> SecuritySchemeOAuth2:
    return SecuritySchemeOAuth2
      --flows=OAuthFlows.build o["flows"] context pointer["flows"]
      --description=o.get "description"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["flows"] = flows.to-json
    return result

class SecuritySchemeOpenIdConnect extends SecurityScheme:
  /**
  The URL to the OpenID Connect discovery document.
  This must be an absolute URL.
  */
  open-id-connect-url/string

  constructor --.open-id-connect-url --description/string?=null --extensions/Map?=null:
    super --type=SecurityScheme.OPENID-CONNECT --description=description --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> SecuritySchemeOpenIdConnect:
    return SecuritySchemeOpenIdConnect
      --open-id-connect-url=o["openIdConnectUrl"]
      --description=o.get "description"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {
      "type": SecurityScheme.OPENID-CONNECT,
      "openIdConnectUrl": open-id-connect-url,
    }
    if description: result["description"] = description
    add-extensions-to-json_ result
    return result

class OAuthFlows extends Extensionable_:
  /**
  Configuration for the OAuth Implicit flow.
  */
  implicit/OAuthFlowImplicit?

  /**
  Configuration for the OAuth Resource Owner Password flow.
  */
  password/OAuthFlowPassword?

  /**
  Configuration for the OAuth Client Credentials flow.
  */
  client-credentials/OAuthFlowClientCredentials?

  /**
  Configuration for the OAuth Authorization Code flow.
  */
  authorization-code/OAuthFlowAuthorizationCode?

  constructor
      --.implicit=null
      --.password=null
      --.client-credentials=null
      --.authorization-code=null
      --extensions/Map?=null:
    super --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> OAuthFlows:
    return OAuthFlows
      --implicit=o.get "implicit" --if-present=:
          OAuthFlowImplicit.build o["implicit"] context pointer["implicit"]
      --password=o.get "password" --if-present=:
          OAuthFlowPassword.build o["password"] context pointer["password"]
      --client-credentials=o.get "clientCredentials" --if-present=:
          OAuthFlowClientCredentials.build o["clientCredentials"] context pointer["clientCredentials"]
      --authorization-code=o.get "authorizationCode" --if-present=:
          OAuthFlowAuthorizationCode.build o["authorizationCode"] context pointer["authorizationCode"]
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := {:}
    if implicit: result["implicit"] = implicit.to-json
    if password: result["password"] = password.to-json
    if client-credentials: result["clientCredentials"] = client-credentials.to-json
    if authorization-code: result["authorizationCode"] = authorization-code.to-json
    add-extensions-to-json_ result
    return result

class OAuthFlow extends Extensionable_:
  /**
  The URL to be used for obtaining refresh tokens.
  This must be in the form of a URL.
  The OAuth2 standard requires the use of TLS.
  */
  refresh-url/string?

  /**
  The available scopes for the OAuth2 security scheme.

  A map between the scope name and a short description for it.
  The map may be empty.
  */
  scopes/Map  // From string to string.

  constructor --.scopes --.refresh-url=null --extensions/Map?=null:
    super --extensions=extensions

  to-json -> Map:
    result := {
      "scopes": scopes,
    }
    if refresh-url: result["refreshUrl"] = refresh-url
    add-extensions-to-json_ result
    return result

class OAuthFlowImplicit extends OAuthFlow:
  /**
  The authorization URL to be used for this flow.
  This must be in the form of a URL.
  The OAuth2 standard requires the use of TLS.
  */
  authorization-url/string

  constructor --.authorization-url --scopes/Map --refresh-url/string?=null --extensions/Map?=null:
    super --scopes=scopes --refresh-url=refresh-url --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> OAuthFlowImplicit:
    return OAuthFlowImplicit
      --authorization-url=o["authorizationUrl"]
      --scopes=o["scopes"]
      --refresh-url=o.get "refreshUrl"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["authorizationUrl"] = authorization-url
    return result

class OAuthFlowPassword extends OAuthFlow:
  /**
  The token URL to be used for this flow.
  This must be in the form of a URL.
  The OAuth2 standard requires the use of TLS.
  */
  token-url/string

  constructor --.token-url --scopes/Map --refresh-url/string?=null --extensions/Map?=null:
    super --scopes=scopes --refresh-url=refresh-url --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> OAuthFlowPassword:
    return OAuthFlowPassword
      --token-url=o["tokenUrl"]
      --scopes=o["scopes"]
      --refresh-url=o.get "refreshUrl"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["tokenUrl"] = token-url
    return result

class OAuthFlowClientCredentials extends OAuthFlow:
  /**
  The token URL to be used for this flow.
  This must be in the form of a URL.
  The OAuth2 standard requires the use of TLS.
  */
  token-url/string

  constructor --.token-url --scopes/Map --refresh-url/string?=null --extensions/Map?=null:
    super --scopes=scopes --refresh-url=refresh-url --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> OAuthFlowClientCredentials:
    return OAuthFlowClientCredentials
      --token-url=o["tokenUrl"]
      --scopes=o["scopes"]
      --refresh-url=o.get "refreshUrl"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["tokenUrl"] = token-url
    return result

class OAuthFlowAuthorizationCode extends OAuthFlow:
  /**
  The authorization URL to be used for this flow.
  This must be in the form of a URL.
  The OAuth2 standard requires the use of TLS.
  */
  authorization-url/string

  /**
  The token URL to be used for this flow.
  This must be in the form of a URL.
  The OAuth2 standard requires the use of TLS.
  */
  token-url/string

  constructor --.authorization-url --.token-url --scopes/Map --refresh-url/string?=null --extensions/Map?=null:
    super --scopes=scopes --refresh-url=refresh-url --extensions=extensions

  static build o/Map context/BuildContext pointer/JsonPointer -> OAuthFlowAuthorizationCode:
    return OAuthFlowAuthorizationCode
      --authorization-url=o["authorizationUrl"]
      --token-url=o["tokenUrl"]
      --scopes=o["scopes"]
      --refresh-url=o.get "refreshUrl"
      --extensions=Extensionable_.extract-extensions o

  to-json -> Map:
    result := super
    result["authorizationUrl"] = authorization-url
    result["tokenUrl"] = token-url
    return result

/**
A required security scheme to execute an operation.

The contained map references security schemes declared in $Components.security-schemes.
All the schemes must be satisfied for the operation to be permitted.
*/
// Note: the specification does not make this class extensible.
class SecurityRequirement:
  /**
  A map between the name of a security scheme and a list.
  The content of the list depends on the type of the scheme:
  - For oauth2 schemes the values list the required security scopes. The list
    may be empty if no scopes are required.
  - For other schemes, the list may contain a list of role names to require
    for the operation, but are not otherwise defined or exchanged in-band.
  */
  requirements/Map  // From string to List of string.

  constructor --.requirements/Map:

  static build o/Map context/BuildContext pointer/JsonPointer -> SecurityRequirement:
    return SecurityRequirement --requirements=o

  to-json -> Map:
    return requirements
