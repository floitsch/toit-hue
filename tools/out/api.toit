import http
import net
import openapi

/**
The client that does the actual requests.
*/
class ApiClient:
  client_/http.Client? := ?

  constructor network/net.Client:
    client_ = http.Client network

  close:
    if client_:
      client_.close
      client_ = null

class Api:
  api-client_/ApiClient? := ?

  constructor --api-client/ApiClient:
    api-client_ = api-client

  constructor network/net.Client:
    api-client_ = ApiClient network

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

  api-client_/ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:

  /**
  Update an existing pet by Id
  */
  update-pet
  :
    // TODO.

  /**
  Add a new pet to the store
  */
  add-pet
  :
    // TODO.

  /**
  Multiple status values can be provided with comma separated strings
  - $status: 
  */
  find-pets-by-status
      --status=null
  :
    // TODO.

  /**
  Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.
  - $tags: 
  */
  find-pets-by-tags
      --tags=null
  :
    // TODO.

  /**
  Returns a single pet
  - $pet-id: 
  */
  get-pet-by-id
      --pet-id
  :
    // TODO.

  /**
  
  - $pet-id: 
  - $name: 
  - $status: 
  */
  update-pet-with-form
      --pet-id
      --name=null
      --status=null
  :
    // TODO.

  /**
  
  - $api-key: 
  - $pet-id: 
  */
  delete-pet
      --api-key=null
      --pet-id
  :
    // TODO.

  /**
  
  - $pet-id: 
  - $additional-metadata: 
  */
  upload-file
      --pet-id
      --additional-metadata=null
  :
    // TODO.


class StoreApi:
  authentication/openapi.Authentication?

  api-client_/ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:

  /**
  Returns a map of status codes to quantities
  */
  get-inventory
  :
    // TODO.

  /**
  Place a new order in the store
  */
  place-order
  :
    // TODO.

  /**
  For valid response try integer IDs with value &lt;= 5 or &gt; 10. Other values will generate exceptions.
  - $order-id: 
  */
  get-order-by-id
      --order-id
  :
    // TODO.

  /**
  For valid response try integer IDs with value &lt; 1000. Anything above 1000 or nonintegers will generate API errors
  - $order-id: 
  */
  delete-order
      --order-id
  :
    // TODO.


class UserApi:
  authentication/openapi.Authentication?

  api-client_/ApiClient
  // group_/GroupedApi? := null

  constructor .api-client_
      --.authentication=null:

  /**
  This can only be done by the logged in user.
  */
  create-user
  :
    // TODO.

  /**
  Creates list of users with given input array
  */
  create-users-with-list-input
  :
    // TODO.

  /**
  
  - $username: 
  - $password: 
  */
  login-user
      --username=null
      --password=null
  :
    // TODO.

  /**
  
  */
  logout-user
  :
    // TODO.

  /**
  
  - $username: 
  */
  get-user-by-name
      --username
  :
    // TODO.

  /**
  This can only be done by the logged in user.
  - $username: 
  */
  update-user
      --username
  :
    // TODO.

  /**
  This can only be done by the logged in user.
  - $username: 
  */
  delete-user
      --username
  :
    // TODO.


