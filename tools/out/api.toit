import http
import net
import .lib.auth as openapi

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
  updatePet
  :
    // TODO.

  /**
  Add a new pet to the store
  */
  addPet
  :
    // TODO.

  /**
  Multiple status values can be provided with comma separated strings
  - $status: 
  */
  findPetsByStatus
      --status=null
  // MUSTACHE:: 
  :
    // TODO.

  /**
  Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.
  - $tags: 
  */
  findPetsByTags
      --tags=null
  // MUSTACHE:: 
  :
    // TODO.

  /**
  Returns a single pet
  - $pet-id: 
  */
  getPetById
      --pet-id

  :
    // TODO.

  /**
  
  - $pet-id: 
  - $name: 
  - $status: 
  */
  updatePetWithForm
      --pet-id

      --name=null
  // MUSTACHE:: 
      --status=null
  // MUSTACHE:: 
  :
    // TODO.

  /**
  
  - $api-key: 
  - $pet-id: 
  */
  deletePet
      --api-key=null
  // MUSTACHE:: 
      --pet-id

  :
    // TODO.

  /**
  
  - $pet-id: 
  - $additional-metadata: 
  */
  uploadFile
      --pet-id

      --additional-metadata=null
  // MUSTACHE:: 
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
  getInventory
  :
    // TODO.

  /**
  Place a new order in the store
  */
  placeOrder
  :
    // TODO.

  /**
  For valid response try integer IDs with value &lt;= 5 or &gt; 10. Other values will generate exceptions.
  - $order-id: 
  */
  getOrderById
      --order-id

  :
    // TODO.

  /**
  For valid response try integer IDs with value &lt; 1000. Anything above 1000 or nonintegers will generate API errors
  - $order-id: 
  */
  deleteOrder
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
  createUser
  :
    // TODO.

  /**
  Creates list of users with given input array
  */
  createUsersWithListInput
  :
    // TODO.

  /**
  
  - $username: 
  - $password: 
  */
  loginUser
      --username=null
  // MUSTACHE:: 
      --password=null
  // MUSTACHE:: 
  :
    // TODO.

  /**
  
  */
  logoutUser
  :
    // TODO.

  /**
  
  - $username: 
  */
  getUserByName
      --username

  :
    // TODO.

  /**
  This can only be done by the logged in user.
  - $username: 
  */
  updateUser
      --username

  :
    // TODO.

  /**
  This can only be done by the logged in user.
  - $username: 
  */
  deleteUser
      --username

  :
    // TODO.


