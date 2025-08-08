import http
import net
import openapi

class Api:
  api-client_/openapi.ApiClient? := ?

  constructor --api-client/openapi.ApiClient:
    api-client_ = api-client

  constructor network/net.Client:
    // TODO(florian): provide base-path.
    api-client_ = openapi.ApiClient network --base-path=""

  close -> none:
    if not api-client_: return
    api-client_.close
    api-client_ = null

  pet_/PetApi? := null
  pet -> PetApi:
    if not pet_: pet_ = PetApi api-client_
    return pet_

  store_/StoreApi? := null
  store -> StoreApi:
    if not store_: store_ = StoreApi api-client_
    return store_

  user_/UserApi? := null
  user -> UserApi:
    if not user_: user_ = UserApi api-client_
    return user_


class PetApi:
  authentication/openapi.Authentication?

  api-client_/openapi.ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:


  /**
  Variant of $update-pet that takes a raw body and
    returns the raw response.
  */
  update-pet --raw
      body-arg
  :
    path := "/pet"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="put"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Update an existing pet by Id
  - $body-arg: Update an existent pet in the store
  */
  update-pet
      body-arg
  :
    // TODO.
    raw := update-pet --raw
        body-arg
    // TODO.


  /**
  Variant of $add-pet that takes a raw body and
    returns the raw response.
  */
  add-pet --raw
      body-arg
  :
    path := "/pet"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="post"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Add a new pet to the store
  - $body-arg: Create a new pet in the store
  */
  add-pet
      body-arg
  :
    // TODO.
    raw := add-pet --raw
        body-arg
    // TODO.


  /**
  Variant of $find-pets-by-status that takes a raw body and
    returns the raw response.
  */
  find-pets-by-status --raw
      --status=null
  :
    path := "/pet/findByStatus"
    headers := http.Headers
    query-params := []
    cookie-params := []

    query-params.add (openapi.QueryParam "status" status)

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Multiple status values can be provided with comma separated strings
  - $status: Status values that need to be considered for filter
  */
  find-pets-by-status
      --status=null
  :
    // TODO.
    raw := find-pets-by-status --raw
        --status=status
    // TODO.


  /**
  Variant of $find-pets-by-tags that takes a raw body and
    returns the raw response.
  */
  find-pets-by-tags --raw
      --tags=null
  :
    path := "/pet/findByTags"
    headers := http.Headers
    query-params := []
    cookie-params := []

    query-params.add (openapi.QueryParam "tags" tags)

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.
  - $tags: Tags to filter by
  */
  find-pets-by-tags
      --tags=null
  :
    // TODO.
    raw := find-pets-by-tags --raw
        --tags=tags
    // TODO.


  /**
  Variant of $get-pet-by-id that takes a raw body and
    returns the raw response.
  */
  get-pet-by-id --raw
      --pet-id
  :
    path := "/pet/{petId}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("petId")}" "$pet-id"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Returns a single pet
  - $pet-id: ID of pet to return
  */
  get-pet-by-id
      --pet-id
  :
    // TODO.
    raw := get-pet-by-id --raw
        --pet-id=pet-id
    // TODO.


  /**
  Variant of $update-pet-with-form that takes a raw body and
    returns the raw response.
  */
  update-pet-with-form --raw
      --pet-id
      --name=null
      --status=null
  :
    path := "/pet/{petId}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("petId")}" "$pet-id"
    query-params.add (openapi.QueryParam "name" name)
    query-params.add (openapi.QueryParam "status" status)

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="post"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  
  - $pet-id: ID of pet that needs to be updated
  - $name: Name of pet that needs to be updated
  - $status: Status of pet that needs to be updated
  */
  update-pet-with-form
      --pet-id
      --name=null
      --status=null
  :
    // TODO.
    raw := update-pet-with-form --raw
        --pet-id=pet-id
        --name=name
        --status=status
    // TODO.


  /**
  Variant of $delete-pet that takes a raw body and
    returns the raw response.
  */
  delete-pet --raw
      --api-key=null
      --pet-id
  :
    path := "/pet/{petId}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    headers.set "api_key" api-key
    path = path.replace --all "{$("petId")}" "$pet-id"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="delete"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  
  - $api-key: 
  - $pet-id: Pet id to delete
  */
  delete-pet
      --api-key=null
      --pet-id
  :
    // TODO.
    raw := delete-pet --raw
        --api-key=api-key
        --pet-id=pet-id
    // TODO.


  /**
  Variant of $upload-file that takes a raw body and
    returns the raw response.
  */
  upload-file --raw
      --pet-id
      --additional-metadata=null
      body-arg
  :
    path := "/pet/{petId}/uploadImage"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("petId")}" "$pet-id"
    query-params.add (openapi.QueryParam "additionalMetadata" additional-metadata)

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="post"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  
  - $pet-id: ID of pet to update
  - $additional-metadata: Additional Metadata
  - $body-arg: 
  */
  upload-file
      --pet-id
      --additional-metadata=null
      body-arg
  :
    // TODO.
    raw := upload-file --raw
        --pet-id=pet-id
        --additional-metadata=additional-metadata
        body-arg
    // TODO.


class StoreApi:
  authentication/openapi.Authentication?

  api-client_/openapi.ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:


  /**
  Variant of $get-inventory that takes a raw body and
    returns the raw response.
  */
  get-inventory --raw
  :
    path := "/store/inventory"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Returns a map of status codes to quantities
  */
  get-inventory
  :
    // TODO.
    raw := get-inventory --raw
    // TODO.


  /**
  Variant of $place-order that takes a raw body and
    returns the raw response.
  */
  place-order --raw
      body-arg
  :
    path := "/store/order"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="post"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Place a new order in the store
  - $body-arg: 
  */
  place-order
      body-arg
  :
    // TODO.
    raw := place-order --raw
        body-arg
    // TODO.


  /**
  Variant of $get-order-by-id that takes a raw body and
    returns the raw response.
  */
  get-order-by-id --raw
      --order-id
  :
    path := "/store/order/{orderId}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("orderId")}" "$order-id"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions.
  - $order-id: ID of order that needs to be fetched
  */
  get-order-by-id
      --order-id
  :
    // TODO.
    raw := get-order-by-id --raw
        --order-id=order-id
    // TODO.


  /**
  Variant of $delete-order that takes a raw body and
    returns the raw response.
  */
  delete-order --raw
      --order-id
  :
    path := "/store/order/{orderId}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("orderId")}" "$order-id"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="delete"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  For valid response try integer IDs with value < 1000. Anything above 1000 or nonintegers will generate API errors
  - $order-id: ID of the order that needs to be deleted
  */
  delete-order
      --order-id
  :
    // TODO.
    raw := delete-order --raw
        --order-id=order-id
    // TODO.


class UserApi:
  authentication/openapi.Authentication?

  api-client_/openapi.ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:


  /**
  Variant of $create-user that takes a raw body and
    returns the raw response.
  */
  create-user --raw
      body-arg
  :
    path := "/user"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="post"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  This can only be done by the logged in user.
  - $body-arg: Created user object
  */
  create-user
      body-arg
  :
    // TODO.
    raw := create-user --raw
        body-arg
    // TODO.


  /**
  Variant of $create-users-with-list-input that takes a raw body and
    returns the raw response.
  */
  create-users-with-list-input --raw
      body-arg
  :
    path := "/user/createWithList"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="post"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  Creates list of users with given input array
  - $body-arg: 
  */
  create-users-with-list-input
      body-arg
  :
    // TODO.
    raw := create-users-with-list-input --raw
        body-arg
    // TODO.


  /**
  Variant of $login-user that takes a raw body and
    returns the raw response.
  */
  login-user --raw
      --username=null
      --password=null
  :
    path := "/user/login"
    headers := http.Headers
    query-params := []
    cookie-params := []

    query-params.add (openapi.QueryParam "username" username)
    query-params.add (openapi.QueryParam "password" password)

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  
  - $username: The user name for login
  - $password: The password for login in clear text
  */
  login-user
      --username=null
      --password=null
  :
    // TODO.
    raw := login-user --raw
        --username=username
        --password=password
    // TODO.


  /**
  Variant of $logout-user that takes a raw body and
    returns the raw response.
  */
  logout-user --raw
  :
    path := "/user/logout"
    headers := http.Headers
    query-params := []
    cookie-params := []


    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  
  */
  logout-user
  :
    // TODO.
    raw := logout-user --raw
    // TODO.


  /**
  Variant of $get-user-by-name that takes a raw body and
    returns the raw response.
  */
  get-user-by-name --raw
      --username
  :
    path := "/user/{username}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("username")}" "$username"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="get"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  
  - $username: The name that needs to be fetched. Use user1 for testing. 
  */
  get-user-by-name
      --username
  :
    // TODO.
    raw := get-user-by-name --raw
        --username=username
    // TODO.


  /**
  Variant of $update-user that takes a raw body and
    returns the raw response.
  */
  update-user --raw
      --username
      body-arg
  :
    path := "/user/{username}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("username")}" "$username"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="put"
        --query-params=query-params
        --body=body-arg
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  This can only be done by the logged in user.
  - $username: name that needs to be updated
  - $body-arg: Update an existent user in the store
  */
  update-user
      --username
      body-arg
  :
    // TODO.
    raw := update-user --raw
        --username=username
        body-arg
    // TODO.


  /**
  Variant of $delete-user that takes a raw body and
    returns the raw response.
  */
  delete-user --raw
      --username
  :
    path := "/user/{username}"
    headers := http.Headers
    query-params := []
    cookie-params := []

    path = path.replace --all "{$("username")}" "$username"

    if not cookie-params.is-empty:
      headers.set "Cookie" (cookie-params.join "; ")

    return api-client_.invoke-api
        --path=path
        --method="delete"
        --query-params=query-params
        --header-params=http.Headers
        --form-params={:}
        --content-type=null

  /**
  This can only be done by the logged in user.
  - $username: The name that needs to be deleted
  */
  delete-user
      --username
  :
    // TODO.
    raw := delete-user --raw
        --username=username
    // TODO.


