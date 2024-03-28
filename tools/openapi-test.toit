import expect show *

import .openapi
import .json-schema.json-pointer show JsonPointer

/**
All examples with section numbers are from https://spec.openapis.org/oas/v3.1.0.
*/

main:
  test-info
  test-contact
  test-license
  test-server
  test-components
  test-paths
  test-path-item
  test-operation
  test-external-documenation
  test-parameter
  test-request-body
  test-media-type
  test-encoding
  test-responses
  test-response
  test-callback
  test-example
  test-link
  test-header
  test-reference
  test-schema

// Example from 4.8.2.2.
INFO-EXAMPLE ::= {
  "title": "Sample Pet Store App",
  "summary": "A pet store manager.",
  "description": "This is a sample server for a pet store.",
  "termsOfService": "https://example.com/terms/",
  "contact": {
    "name": "API Support",
    "url": "https://www.example.com/support",
    "email": "support@example.com"
  },
  "license": {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  },
  "version": "1.0.1"
}

INFO-MINIMAL ::= {
  "title": "Sample Pet Store App",
  "version": "1.0.1"
}

context := BuildContext

test-info:
  info := Info.build INFO-EXAMPLE context JsonPointer
  expect-equals "Sample Pet Store App" info.title
  expect-equals "A pet store manager." info.summary
  expect-equals "This is a sample server for a pet store." info.description
  expect-equals "https://example.com/terms/" info.terms-of-service
  contact/Contact := info.contact
  expect-equals "API Support" contact.name
  expect-equals "https://www.example.com/support" contact.url
  expect-equals "support@example.com" contact.email
  expect-equals "Apache 2.0" info.license.name
  expect-equals "https://www.apache.org/licenses/LICENSE-2.0.html" info.license.url
  expect-equals "1.0.1" info.version


  json := info.to-json
  expect-structural-equals INFO-EXAMPLE json

  info = Info.build INFO-MINIMAL context JsonPointer
  expect-equals "Sample Pet Store App" info.title
  expect-equals "1.0.1" info.version
  expect_null info.summary
  expect_null info.description
  expect_null info.terms-of-service
  expect_null info.contact
  expect_null info.license

  json = info.to-json
  expect-structural-equals INFO-MINIMAL json


// Example from 4.8.3.2.
CONTACT-EXAMPLE ::= {
  "name": "API Support",
  "url": "https://www.example.com/support",
  "email": "support@example.com",
}

CONTACT-MINIMAL ::= {:}

test-contact:
  contact := Contact.build CONTACT-EXAMPLE context JsonPointer
  expect-equals "API Support" contact.name
  expect-equals "https://www.example.com/support" contact.url
  expect-equals "support@example.com" contact.email

  json := contact.to-json
  expect-structural-equals CONTACT-EXAMPLE json


  contact = Contact.build CONTACT-MINIMAL context JsonPointer
  expect_null contact.name
  expect_null contact.url
  expect_null contact.email

  json = contact.to-json
  expect-structural-equals CONTACT-MINIMAL json


// Example from 4.8.4.2.
LICENSE-EXAMPLE ::= {
  "name": "Apache 2.0",
  "identifier": "Apache-2.0"
}

test-license:
  license := License.build LICENSE-EXAMPLE context JsonPointer
  expect-equals "Apache 2.0" license.name
  expect-equals "Apache-2.0" license.identifier

  json := license.to-json
  expect-structural-equals LICENSE-EXAMPLE json


// Example from 4.8.5.2.
SERVER-EXAMPLE ::= {
  "url": "https://development.gigantic-server.com/v1",
  "description": "Development server"
}

// Example from 4.8.5.2.
SERVER-LIST-EXAMPLE ::= [
  {
    "url": "https://development.gigantic-server.com/v1",
    "description": "Development server"
  },
  {
    "url": "https://staging.gigantic-server.com/v1",
    "description": "Staging server"
  },
  {
    "url": "https://api.gigantic-server.com/v1",
    "description": "Production server"
  }
]

// Example from 4.8.5.2.
SERVER-VARIABLE-EXAMPLE ::= {
  "url": "https://{username}.gigantic-server.com:{port}/{basePath}",
  "description": "The production API server",
  "variables": {
    "username": {
      "default": "demo",
      "description": "this value is assigned by the service provider, in this example `gigantic-server.com`"
    },
    "port": {
      "enum": [
        "8443",
        "443"
      ],
      "default": "8443"
    },
    "basePath": {
      "default": "v2"
    }
  }
}

test-server:
  server := Server.build SERVER-EXAMPLE context JsonPointer
  expect-equals "https://development.gigantic-server.com/v1" server.url
  expect-equals "Development server" server.description

  json := server.to-json
  expect-structural-equals SERVER-EXAMPLE json

  servers := SERVER-LIST-EXAMPLE.map: Server.build it context JsonPointer
  expect-equals 3 servers.size
  json-list := servers.map: it.to-json
  expect-structural-equals SERVER-LIST-EXAMPLE json-list

  server = Server.build SERVER-VARIABLE-EXAMPLE context JsonPointer
  expect-equals "https://{username}.gigantic-server.com:{port}/{basePath}" server.url
  expect-equals "The production API server" server.description
  expect-equals 3 server.variables.size
  expect-equals
      "demo"
      server.variables["username"].default
  expect-equals
      "this value is assigned by the service provider, in this example `gigantic-server.com`"
      server.variables["username"].description
  expect-list-equals
      ["8443", "443"]
      server.variables["port"].enum-values
  expect-equals
      "8443"
      server.variables["port"].default
  expect-equals "v2" server.variables["basePath"].default

  json = server.to-json
  expect-structural-equals SERVER-VARIABLE-EXAMPLE json

// Example from 4.8.7.2.
COMPONENTS-EXAMPLE ::= {
  "schemas": {
    "GeneralError": {
      "type": "object",
      "properties": {
        "code": {
          "type": "integer",
          "format": "int32"
        },
        "message": {
          "type": "string"
        }
      }
    },
    "Category": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "name": {
          "type": "string"
        }
      }
    },
    "Tag": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "name": {
          "type": "string"
        }
      }
    }
  },
  "parameters": {
    "skipParam": {
      "name": "skip",
      "in": "query",
      "description": "number of items to skip",
      "required": true,
      "schema": {
        "type": "integer",
        "format": "int32"
      }
    },
    "limitParam": {
      "name": "limit",
      "in": "query",
      "description": "max records to return",
      "required": true,
      "schema" : {
        "type": "integer",
        "format": "int32"
      }
    }
  },
  "responses": {
    "NotFound": {
      "description": "Entity not found."
    },
    "IllegalInput": {
      "description": "Illegal input for operation."
    },
    "GeneralError": {
      "description": "General Error",
      "content": {
        "application/json": {
          "schema": {
            "\$ref": "#/components/schemas/GeneralError"
          }
        }
      }
    }
  },
  "securitySchemes": {
    "api_key": {
      "type": "apiKey",
      "name": "api_key",
      "in": "header"
    },
    "petstore_auth": {
      "type": "oauth2",
      "flows": {
        "implicit": {
          "authorizationUrl": "https://example.org/api/oauth/dialog",
          "scopes": {
            "write:pets": "modify pets in your account",
            "read:pets": "read your pets"
          }
        }
      }
    }
  }
}

test-components:
  print "TODO: test components"

// Example from 4.8.8.3.
PATHS-EXAMPLE ::= {
  "/pets": {
    "get": {
      "description": "Returns all pets from the system that the user has access to",
      "responses": {
        "200": {
          "description": "A list of pets.",
          "content": {
            "application/json": {
              "schema": {
                "type": "array",
                "items": {
                  "\$ref": "#/components/schemas/pet"
                }
              }
            }
          }
        }
      }
    }
  }
}

test-paths:
  paths := Paths.build PATHS-EXAMPLE context JsonPointer
  expect-equals 1 paths.paths.size
  expect-equals "/pets" paths.paths.keys.first
  path-item/PathItem := paths.paths["/pets"]
  get/Operation := path-item.get
  expect-equals "Returns all pets from the system that the user has access to" get.description
  expect-equals 1 get.responses.responses.size
  expect-equals "A list of pets." get.responses.responses["200"].description
  expect-equals 1 get.responses.responses["200"].content.size
  expect-equals "application/json" get.responses.responses["200"].content.keys.first

  json := paths.to-json
  expect-structural-equals PATHS-EXAMPLE json

PATH-ITEM-EXAMPLE ::= {
  "get": {
    "description": "Returns pets based on ID",
    "summary": "Find pets by ID",
    "operationId": "getPetsById",
    "responses": {
      "200": {
        "description": "pet response",
        "content": {
          "*/*": {
            "schema": {
              "type": "array",
              "items": {
                "\$ref": "#/components/schemas/Pet"
              }
            }
          }
        }
      },
      "default": {
        "description": "error payload",
        "content": {
          "text/html": {
            "schema": {
              "\$ref": "#/components/schemas/ErrorModel"
            }
          }
        }
      }
    }
  },
  "parameters": [
    {
      "name": "id",
      "in": "path",
      "description": "ID of pet to use",
      "required": true,
      "schema": {
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "style": "simple"
    }
  ]
}

test-path-item:
  path-item := PathItem.build PATH-ITEM-EXAMPLE context JsonPointer
  get := path-item.get
  expect-equals "Returns pets based on ID" get.description
  expect-equals "Find pets by ID" get.summary
  expect-equals "getPetsById" get.operation-id
  expect-equals 1 get.responses.responses.size
  expect-equals "pet response" get.responses.responses["200"].description
  expect-equals 1 get.responses.responses["200"].content.size
  expect-equals "*/*" get.responses.responses["200"].content.keys.first
  expect-not-null get.responses.default
  expect-equals "error payload" get.responses.default.description
  expect-equals 1 get.responses.default.content.size
  expect-equals "text/html" get.responses.default.content.keys.first
  parameters := path-item.parameters
  expect-equals 1 parameters.size
  parameter := parameters.first
  expect-equals "id" parameter.name
  expect-equals Parameter.PATH parameter.in
  expect-equals "ID of pet to use" parameter.description
  expect parameter.required
  expect-equals "simple" parameter.style

  json := path-item.to-json
  expect-structural-equals PATH-ITEM-EXAMPLE json

OPERATION-EXAMPLE ::= {
  "tags": [
    "pet"
  ],
  "summary": "Updates a pet in the store with form data",
  "operationId": "updatePetWithForm",
  "parameters": [
    {
      "name": "petId",
      "in": "path",
      "description": "ID of pet that needs to be updated",
      "required": true,
      "schema": {
        "type": "string"
      }
    }
  ],
  "requestBody": {
    "content": {
      "application/x-www-form-urlencoded": {
        "schema": {
          "type": "object",
          "properties": {
            "name": {
              "description": "Updated name of the pet",
              "type": "string"
            },
            "status": {
              "description": "Updated status of the pet",
              "type": "string"
            }
          },
          "required": ["status"]
        }
      }
    }
  },
  "responses": {
    "200": {
      "description": "Pet updated.",
      "content": {
        "application/json": {:},
        "application/xml": {:}
      }
    },
    "405": {
      "description": "Method Not Allowed",
      "content": {
        "application/json": {:},
        "application/xml": {:}
      }
    }
  },
  "security": [
    {
      "petstore_auth": [
        "write:pets",
        "read:pets"
      ]
    }
  ]
}

test-operation:
  print "TODO: test operation"
  /*
  operation := Operation.build OPERATION-EXAMPLE context JsonPointer
  expect-equals 1 operation.tags.size
  expect-equals "pet" operation.tags.first
  expect-equals "Updates a pet in the store with form data" operation.summary
  expect-equals "updatePetWithForm" operation.operation-id
  expect-equals 1 operation.parameters.size
  parameter/Parameter := operation.parameters.first
  expect-equals "petId" parameter.name
  expect-equals "path" parameter.in
  expect-equals "ID of pet that needs to be updated" parameter.description
  expect parameter.required
  body/RequestBody := operation.request-body
  expect-equals 1 body.content.size
  expect-equals "application/x-www-form-urlencoded" body.content.keys.first
  responses := operation.responses
  expect-equals 2 responses.responses.size
  response-200 := responses.responses["200"]
  expect-equals "Pet updated." response-200.description
  expect-equals 2 response-200.content.size
  expect-equals "application/json" response-200.content.keys.first
  expect-equals "application/xml" response-200.content.keys[1]
  response-405 := responses.responses["405"]
  expect-equals "Method Not Allowed" response-405.description
  expect-equals 2 response-405.content.size
  expect-equals "application/json" response-405.content.keys.first
  expect-equals "application/xml" response-405.content.keys[1]
  expect-equals 1 operation.security.size
  security := operation.security.first
  expect-equals 2 security["petstore_auth"].size
  */


EXTERNAL-DOCUMENTATION-EXAMPLE ::= {
  "description": "Find more info here",
  "url": "https://example.com"
}

test-external-documenation:
  documentation := ExternalDocumentation.build EXTERNAL-DOCUMENTATION-EXAMPLE context JsonPointer
  expect-equals "Find more info here" documentation.description
  expect-equals "https://example.com" documentation.url

  json := documentation.to-json
  expect-structural-equals EXTERNAL-DOCUMENTATION-EXAMPLE json

  expect-throw "key 'url' not found": documentation = ExternalDocumentation.build {:} context JsonPointer
  expect-throw "key 'url' not found": documentation = ExternalDocumentation.build {
    "description": "Find more info here",
  }  context JsonPointer
  documentation = ExternalDocumentation.build {
    "url": "https://example.com"
  } context JsonPointer
  expect_null documentation.description
  expect-equals "https://example.com" documentation.url

PARAMETER-EXAMPLES ::= {
  "name": "token",
  "in": "header",
  "description": "token to be passed as a header",
  "required": true,
  "schema": {
    "type": "array",
    "items": {
      "type": "integer",
      "format": "int64"
    }
  },
  "style": "simple"
}

test-parameter:
  parameter := Parameter.build PARAMETER-EXAMPLES context JsonPointer
  expect-equals "token" parameter.name
  expect-equals "header" parameter.in
  expect-equals "token to be passed as a header" parameter.description
  expect parameter.required
  expect-equals "simple" parameter.style

  json := parameter.to-json
  expect-structural-equals PARAMETER-EXAMPLES json

REQUEST-BODY-EXAMPLE ::= {
  "description": "user to add to the system",
  "content": {
    "application/json": {
      "schema": {
        "\$ref": "#/components/schemas/User"
      },
      "examples": {
          "user" : {
            "summary": "User Example",
            "externalValue": "https://foo.bar/examples/user-example.json"
          }
        }
    },
    "application/xml": {
      "schema": {
        "\$ref": "#/components/schemas/User"
      },
      "examples": {
          "user" : {
            "summary": "User example in XML",
            "externalValue": "https://foo.bar/examples/user-example.xml"
          }
        }
    },
    "text/plain": {
      "examples": {
        "user" : {
            "summary": "User example in Plain text",
            "externalValue": "https://foo.bar/examples/user-example.txt"
        }
      }
    },
    "*/*": {
      "examples": {
        "user" : {
            "summary": "User example in other format",
            "externalValue": "https://foo.bar/examples/user-example.whatever"
        }
      }
    }
  }
}

REQUEST-BODY2-EXAMPLE ::= {
  "description": "user to add to the system",
  "required": true,
  "content": {
    "text/plain": {
      "schema": {
        "type": "array",
        "items": {
          "type": "string"
        }
      }
    }
  }
}

test-request-body:
  request-body := RequestBody.build REQUEST-BODY-EXAMPLE context JsonPointer
  expect-equals "user to add to the system" request-body.description
  content := request-body.content
  expect-equals 4 content.size
  expect-equals "application/json" content.keys.first
  expect-equals "application/xml" content.keys[1]
  expect-equals "text/plain" content.keys[2]
  expect-equals "*/*" content.keys[3]

  media-type/MediaType := content["application/json"]
  expect-equals 1 media-type.examples.size
  example/Example := media-type.examples["user"]
  expect-equals "User Example" example.summary
  expect-equals "https://foo.bar/examples/user-example.json" example.external-value

  media-type = content["application/xml"]
  expect-equals 1 media-type.examples.size
  example = media-type.examples["user"]
  expect-equals "User example in XML" example.summary
  expect-equals "https://foo.bar/examples/user-example.xml" example.external-value

  media-type = content["text/plain"]
  expect-equals 1 media-type.examples.size
  example = media-type.examples["user"]
  expect-equals "User example in Plain text" example.summary
  expect-equals "https://foo.bar/examples/user-example.txt" example.external-value

  media-type = content["*/*"]
  expect-equals 1 media-type.examples.size
  example = media-type.examples["user"]
  expect-equals "User example in other format" example.summary

  json := request-body.to-json
  expect-structural-equals REQUEST-BODY-EXAMPLE json

  request-body = RequestBody.build REQUEST-BODY2-EXAMPLE context JsonPointer
  expect-equals "user to add to the system" request-body.description
  expect request-body.required
  content = request-body.content
  expect-equals 1 content.size
  expect-equals "text/plain" content.keys.first
  media-type = content["text/plain"]

  json = request-body.to-json
  expect-structural-equals REQUEST-BODY2-EXAMPLE json

MEDIA-TYPE-EXAMPLE ::= {
  "application/json": {
    "schema": {
        "\$ref": "#/components/schemas/Pet"
    },
    "examples": {
      "cat" : {
        "summary": "An example of a cat",
        "value":
          {
            "name": "Fluffy",
            "petType": "Cat",
            "color": "White",
            "gender": "male",
            "breed": "Persian"
          }
      },
      "dog": {
        "summary": "An example of a dog with a cat's name",
        "value" :  {
          "name": "Puma",
          "petType": "Dog",
          "color": "Black",
          "gender": "Female",
          "breed": "Mixed"
        },
      },
      "frog": {
          "\$ref": "#/components/examples/frog-example"
        }
      }
  }
}

test-media-type:
  media-type := MediaType.build MEDIA-TYPE-EXAMPLE["application/json"] context JsonPointer
  expect-equals 3 media-type.examples.size
  example/Example := media-type.examples["cat"]
  expect-equals "An example of a cat" example.summary
  expect-structural-equals {
    "name": "Fluffy",
    "petType": "Cat",
    "color": "White",
    "gender": "male",
    "breed": "Persian",
  } example.value
  example = media-type.examples["dog"]
  expect-equals "An example of a dog with a cat's name" example.summary
  expect-structural-equals {
    "name": "Puma",
    "petType": "Dog",
    "color": "Black",
    "gender": "Female",
    "breed": "Mixed",
  } example.value
  reference-example/Reference := media-type.examples["frog"]
  expect-equals "#/components/examples/frog-example" reference-example.ref

  json := media-type.to-json
  expect-structural-equals MEDIA-TYPE-EXAMPLE["application/json"] json

ENCODING-EXAMPLE1 ::= {
  "contentType": "application/xml; charset=utf-8"
}

ENCODING-EXAMPLE2 ::= {
  "contentType": "image/png, image/jpeg",
  "headers": {
    "X-Rate-Limit-Limit": {
      "description": "The number of allowed requests in the current period",
      "schema": {
        "type": "integer"
      }
    }
  }
}

test-encoding:
  encoding := Encoding.build ENCODING-EXAMPLE1 context JsonPointer
  expect-equals "application/xml; charset=utf-8" encoding.content-type
  expect-null encoding.headers

  json := encoding.to-json
  expect-structural-equals ENCODING-EXAMPLE1 json

  encoding = Encoding.build ENCODING-EXAMPLE2 context JsonPointer
  expect-equals "image/png, image/jpeg" encoding.content-type
  expect-equals 1 encoding.headers.size
  header/Parameter := encoding.headers["X-Rate-Limit-Limit"]
  expect header.is-header
  expect-equals "The number of allowed requests in the current period" header.description

  json = encoding.to-json
  expect-structural-equals ENCODING-EXAMPLE2 json

RESPONSES-EXAMPLE ::= {
  "200": {
    "description": "a pet to be returned",
    "content": {
      "application/json": {
        "schema": {
          "\$ref": "#/components/schemas/Pet"
        }
      }
    }
  },
  "default": {
    "description": "unexpected error",
    "content": {
      "application/json": {
        "schema": {
          "\$ref": "#/components/schemas/Error"
        }
      }
    }
  }
}

test-responses:
  responses := Responses.build RESPONSES-EXAMPLE context JsonPointer
  expect-equals 1 responses.responses.size
  response-200 := responses.responses["200"]
  expect-equals "a pet to be returned" response-200.description
  expect-equals 1 response-200.content.size
  expect-equals "application/json" response-200.content.keys.first
  response-default := responses.default
  expect-equals "unexpected error" response-default.description
  expect-equals 1 response-default.content.size
  expect-equals "application/json" response-default.content.keys.first

  json := responses.to-json
  expect-structural-equals RESPONSES-EXAMPLE json

RESPONSE-EXAMPLE1 ::= {
  "description": "A complex object array response",
  "content": {
    "application/json": {
      "schema": {
        "type": "array",
        "items": {
          "\$ref": "#/components/schemas/VeryComplexType"
        }
      }
    }
  }
}

RESPONSE-EXAMPLE2 ::= {
  "description": "A simple string response",
  "content": {
    "text/plain": {
      "schema": {
        "type": "string"
      }
    }
  }
}

RESPONSE-EXAMPLE3 ::= {
  "description": "A simple string response",
  "content": {
    "text/plain": {
      "schema": {
        "type": "string",
        "example": "whoa!"
      }
    }
  },
  "headers": {
    "X-Rate-Limit-Limit": {
      "description": "The number of allowed requests in the current period",
      "schema": {
        "type": "integer"
      }
    },
    "X-Rate-Limit-Remaining": {
      "description": "The number of remaining requests in the current period",
      "schema": {
        "type": "integer"
      }
    },
    "X-Rate-Limit-Reset": {
      "description": "The number of seconds left in the current period",
      "schema": {
        "type": "integer"
      }
    }
  }
}

RESPONSE-EXAMPLE4 ::= {
  "description": "object created"
}

test-response:
  response := Response.build RESPONSE-EXAMPLE1 context JsonPointer
  expect-equals "A complex object array response" response.description
  expect-equals 1 response.content.size
  expect-equals "application/json" response.content.keys.first

  json := response.to-json
  expect-structural-equals RESPONSE-EXAMPLE1 json

  response = Response.build RESPONSE-EXAMPLE2 context JsonPointer
  expect-equals "A simple string response" response.description
  expect-equals 1 response.content.size
  expect-equals "text/plain" response.content.keys.first

  json = response.to-json
  expect-structural-equals RESPONSE-EXAMPLE2 json

  response = Response.build RESPONSE-EXAMPLE3 context JsonPointer
  expect-equals "A simple string response" response.description
  expect-equals 1 response.content.size
  expect-equals "text/plain" response.content.keys.first

  expect-equals 3 response.headers.size
  header := response.headers["X-Rate-Limit-Limit"]
  expect header.is-header
  expect-equals "The number of allowed requests in the current period" header.description
  header = response.headers["X-Rate-Limit-Remaining"]
  expect header.is-header
  expect-equals "The number of remaining requests in the current period" header.description
  header = response.headers["X-Rate-Limit-Reset"]
  expect header.is-header
  expect-equals "The number of seconds left in the current period" header.description

  json = response.to-json
  expect-structural-equals RESPONSE-EXAMPLE3 json

CALLBACK-EXAMPLE ::= {
  "{\$request.query.queryUrl}": {
    "post": {
      "requestBody": {
        "description": "callback payload",
        "content": {
          "application/json": {
            "schema": {
              "\$ref": "#/components/schemas/SomePayload"
            }
          }
        }
      },
      "responses": {
        "200": {
          "description": "callback successfully processed"
        }
      }
    }
  }
}

test-callback:
  callback := Callback.build CALLBACK-EXAMPLE context JsonPointer
  expect-equals 1 callback.callbacks.size
  runtime-expression := callback.callbacks.keys.first
  expect-equals "{\$request.query.queryUrl}" runtime-expression.expression
  post := callback.callbacks[runtime-expression].post
  request-body := post.request-body
  expect-not-null request-body
  expect-equals "callback payload" request-body.description
  expect-equals 1 request-body.content.size
  expect-equals "application/json" request-body.content.keys.first
  responses := post.responses
  expect-equals 1 responses.responses.size
  response-200 := responses.responses["200"]
  expect-equals "callback successfully processed" response-200.description

EXAMPLE-REQUEST-BODY-TEST ::= {
  "content": {
    "application/json": {
      "schema": {
        "\$ref": "#/components/schemas/Address"
      },
      "examples": {
        "foo": {
          "summary": "A foo example",
          "value": {
            "foo": "bar"
          }
        },
        "bar": {
          "summary": "A bar example",
          "value": {
            "bar": "baz"
          }
        }
      }
    },
    "application/xml": {
      "examples": {
        "xmlExample": {
          "summary": "This is an example in XML",
          "externalValue": "https://example.org/examples/address-example.xml"
        }
      }
    },
    "text/plain": {
      "examples": {
        "textExample": {
          "summary": "This is a text example",
          "externalValue": "https://foo.bar/examples/address-example.txt"
        }
      }
    }
  }
}

EXAMPLE-PARAMETERS-TEST ::= {
  "name": "zipCode",
  "in": "query",
  "schema": {
    "type": "string",
    "format": "zip-code"
  },
  "examples": {
    "zip-example": {
      "\$ref": "#/components/examples/zip-example"
    }
  }
}

EXAMPLE-RESPONSE-TEST ::= {
  "responses": {
    "200": {
      "description": "your car appointment has been booked",
      "content": {
        "application/json": {
          "schema": {
            "\$ref": "#/components/schemas/SuccessResponse"
          },
          "examples": {
            "confirmation-success": {
              "\$ref": "#/components/examples/confirmation-success"
            }
          }
        }
      }
    }
  }
}

test-example:
  request-body := RequestBody.build EXAMPLE-REQUEST-BODY-TEST context JsonPointer
  expect-equals 3 request-body.content.size
  content := request-body.content["application/json"]
  examples := content.examples
  expect-equals 2 examples.size
  foo := examples["foo"]
  expect-equals "A foo example" foo.summary
  expect-structural-equals {"foo": "bar"} foo.value
  bar := examples["bar"]
  expect-equals "A bar example" bar.summary
  expect-structural-equals {"bar": "baz"} bar.value
  content = request-body.content["application/xml"]
  examples = content.examples
  expect-equals 1 examples.size
  xml-example := examples["xmlExample"]
  expect-equals "This is an example in XML" xml-example.summary
  expect-equals "https://example.org/examples/address-example.xml" xml-example.external-value
  content = request-body.content["text/plain"]
  examples = content.examples
  expect-equals 1 examples.size
  text-example := examples["textExample"]
  expect-equals "This is a text example" text-example.summary
  expect-equals "https://foo.bar/examples/address-example.txt" text-example.external-value

  json := request-body.to-json
  expect-structural-equals EXAMPLE-REQUEST-BODY-TEST json

  parameter := Parameter.build EXAMPLE-PARAMETERS-TEST context JsonPointer
  expect-equals 1 parameter.examples.size
  reference-example/Reference := parameter.examples["zip-example"]
  expect-equals "#/components/examples/zip-example" reference-example.ref

  json = parameter.to-json
  expect-structural-equals EXAMPLE-PARAMETERS-TEST json

  operation := Operation.build EXAMPLE-RESPONSE-TEST context JsonPointer
  responses := operation.responses
  expect-equals 1 responses.responses.size
  response-200 := responses.responses["200"]
  response-content := response-200.content["application/json"]
  examples = response-content.examples
  expect-equals 1 examples.size
  reference-example = examples["confirmation-success"]
  expect-equals "#/components/examples/confirmation-success" reference-example.ref

  json = operation.to-json
  expect-structural-equals EXAMPLE-RESPONSE-TEST json

LINK-EXAMPLE1 ::= {
  "paths": {
    "/users/{id}": {
      "parameters": [
        {
          "name": "id",
          "in": "path",
          "required": true,
          "description": "the user identifier, as userId",
          "schema": {
            "type": "string"
          }
        }
      ],
      "get": {
        "responses": {
          "200": {
            "description": "the user being returned",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "uuid": {
                      "type": "string",
                      "format": "uuid"
                    }
                  }
                }
              }
            },
            "links": {
              "address": {
                "operationId": "getUserAddress",
                "parameters": {
                  "userId": "\$request.path.id"
                }
              }
            }
          }
        }
      }
    },
    "/users/{userid}/address": {
      "parameters": [
        {
          "name": "userid",
          "in": "path",
          "required": true,
          "description": "the user identifier, as userId",
          "schema": {
            "type": "string"
          }
        }
      ],
      "get": {
        "operationId": "getUserAddress",
        "responses": {
          "200": {
            "description": "the user's address"
          }
        }
      }
    }
  }
}

LINK-EXAMPLE2 ::= {
  "links": {
    "address": {
      "operationId": "getUserAddressByUUID",
      "parameters": {
        "userUuid": "\$response.body#/uuid"
      }
    }
  }
}

LINK-EXAMPLE3 ::= {
  "links": {
    "UserRepositories": {
      "operationRef": "#/paths/~12.0~1repositories~1{username}/get",
      "parameters": {
        "username": "\$response.body#/username"
      }
    }
  }
}

LINK-EXAMPLE4 ::= {
  "links": {
    "UserRepositories": {
      "operationRef": "https://na2.gigantic-server.com/#/paths/~12.0~1repositories~1{username}/get",
      "parameters": {
        "username": "\$response.body#/username"
      }
    }
  }
}

test-link:
  paths := Paths.build LINK-EXAMPLE1["paths"] context JsonPointer
  // Only looking at the links entry.
  links := paths.paths["/users/{id}"].get.responses.responses["200"].links
  expect-equals 1 links.size
  link/Link := links["address"]
  expect-equals "getUserAddress" link.operation-id
  expect-equals 1 link.parameters.size
  parameter := link.parameters["userId"]
  expect-equals "\$request.path.id" parameter.expression

  json := paths.to-json
  expect-structural-equals LINK-EXAMPLE1["paths"] json

  components := Components.build LINK-EXAMPLE2 context JsonPointer
  links = components.links
  expect-equals 1 links.size
  link = links["address"]
  expect-equals "getUserAddressByUUID" link.operation-id
  expect-equals 1 link.parameters.size
  parameter = link.parameters["userUuid"]
  expect-equals "\$response.body#/uuid" parameter.expression

  json = components.to-json
  expect-structural-equals LINK-EXAMPLE2 json

  components = Components.build LINK-EXAMPLE3 context JsonPointer
  links = components.links
  expect-equals 1 links.size
  link = links["UserRepositories"]
  expect-equals "#/paths/~12.0~1repositories~1{username}/get" link.operation-ref
  expect-equals 1 link.parameters.size
  parameter = link.parameters["username"]
  expect-equals "\$response.body#/username" parameter.expression

  json = components.to-json
  expect-structural-equals LINK-EXAMPLE3 json

  components = Components.build LINK-EXAMPLE4 context JsonPointer
  links = components.links
  expect-equals 1 links.size
  link = links["UserRepositories"]
  expect-equals "https://na2.gigantic-server.com/#/paths/~12.0~1repositories~1{username}/get" link.operation-ref
  expect-equals 1 link.parameters.size
  parameter = link.parameters["username"]
  expect-equals "\$response.body#/username" parameter.expression

  json = components.to-json
  expect-structural-equals LINK-EXAMPLE4 json

HEADER-EXAMPLE ::= {
  "description": "The number of allowed requests in the current period",
  "schema": {
    "type": "integer"
  }
}

test-header:
  header := Parameter.build-header HEADER-EXAMPLE context JsonPointer
  expect header.is-header
  expect-equals "" header.name
  expect-equals Parameter.HEADER header.in
  expect-equals "The number of allowed requests in the current period" header.description

  json := header.to-json
  expect-structural-equals HEADER-EXAMPLE json

REFERENCE-OBJECT-EXAMPLE ::= {
  "\$ref": "#/components/schemas/Pet"
}

REFERENCE-SCHEMA-DOCUMENT-EXAMPLE ::= {
  "\$ref": "Pet.json"
}

REFERENCE-EMBEDDED-SCHEMA-EXAMPLE ::= {
  "\$ref": "definitions.json#/Pet"
}

test-reference:
  reference := Reference.build REFERENCE-OBJECT-EXAMPLE context JsonPointer
  expect-equals "#/components/schemas/Pet" reference.ref
  expect-null reference.description
  expect-null reference.summary

  json := reference.to-json
  expect-structural-equals REFERENCE-OBJECT-EXAMPLE json

  reference = Reference.build REFERENCE-SCHEMA-DOCUMENT-EXAMPLE context JsonPointer
  expect-equals "Pet.json" reference.ref
  expect-null reference.description
  expect-null reference.summary

  json = reference.to-json
  expect-structural-equals REFERENCE-SCHEMA-DOCUMENT-EXAMPLE json

  reference = Reference.build REFERENCE-EMBEDDED-SCHEMA-EXAMPLE context JsonPointer
  expect-equals "definitions.json#/Pet" reference.ref
  expect-null reference.description
  expect-null reference.summary

  json = reference.to-json
  expect-structural-equals REFERENCE-EMBEDDED-SCHEMA-EXAMPLE json

SCHEMA-PRIMITIVE-EXAMPLE ::= {
  "type": "string",
  "format": "email"
}

SCHEMA-MODEL-EXAMPLE ::= {
  "type": "object",
  "required": [
    "name",
  ],
  "properties": {
    "name": {
      "type": "string",
    },
    "address": {
      "\$ref": "#/components/schemas/Address",
    },
    "age": {
      "type": "integer",
      "format": "int32",
      "minimum": 0,
    },
  },
}

test-schema:
  // Just make sure that the schemas can be parsed.
  schema := Schema.build SCHEMA-PRIMITIVE-EXAMPLE context JsonPointer
  schema = Schema.build SCHEMA-MODEL-EXAMPLE context JsonPointer
