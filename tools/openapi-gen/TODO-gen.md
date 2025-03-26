- authentication should probably be an interface:

```
interface StoreAuthentication:
  ...
```

with individual `PetAuthentication`,... as fields.

- the URLs of individual api-clients need to be computed.
  Use the following hierarchy:
  * servers (may be multiple, and the user can choose which one). Default is first.
  * path-items also have servers that override the above.

  If a server is relative, it is relative to the base-url (the URL the
  openapi document came from. If no server is specified at all, it should
  be "/" (thus using the server of the open-api document).
