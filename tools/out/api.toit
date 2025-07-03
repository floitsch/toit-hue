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
  - $body: Update an existent pet in the store
  */
  update-pet
      body
  :
    // TODO.

  /**
  Add a new pet to the store
  - $body: Create a new pet in the store
  */
  add-pet
      body
  :
    // TODO.

  /**
  Multiple status values can be provided with comma separated strings
  - $status: Status values that need to be considered for filter
  */
  find-pets-by-status
      --status=null
  :
    // TODO.

  /**
  Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.
  - $tags: Tags to filter by
  */
  find-pets-by-tags
      --tags=null
  :
    // TODO.

  /**
  Returns a single pet
  - $pet-id: ID of pet to return
  */
  get-pet-by-id
      --pet-id
  :
    // TODO.

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

  /**
  
  - $api-key: 
  - $pet-id: Pet id to delete
  */
  delete-pet
      --api-key=null
      --pet-id
  :
    // TODO.

  /**
  
  - $pet-id: ID of pet to update
  - $additional-metadata: Additional Metadata
  - $body: 
  */
  upload-file
      --pet-id
      --additional-metadata=null
      body
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
  - $body: 
  */
  place-order
      body
  :
    // TODO.

  /**
  For valid response try integer IDs with value &lt;= 5 or &gt; 10. Other values will generate exceptions.
  - $order-id: ID of order that needs to be fetched
  */
  get-order-by-id
      --order-id
  :
    // TODO.

  /**
  For valid response try integer IDs with value &lt; 1000. Anything above 1000 or nonintegers will generate API errors
  - $order-id: ID of the order that needs to be deleted
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
  - $body: Created user object
  */
  create-user
      body
  :
    // TODO.

  /**
  Creates list of users with given input array
  - $body: 
  */
  create-users-with-list-input
      body
  :
    // TODO.

  /**
  
  - $username: The user name for login
  - $password: The password for login in clear text
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
  
  - $username: The name that needs to be fetched. Use user1 for testing. 
  */
  get-user-by-name
      --username
  :
    // TODO.

  /**
  This can only be done by the logged in user.
  - $username: name that needs to be updated
  - $body: Update an existent user in the store
  */
  update-user
      --username
      body
  :
    // TODO.

  /**
  This can only be done by the logged in user.
  - $username: The name that needs to be deleted
  */
  delete-user
      --username
  :
    // TODO.


