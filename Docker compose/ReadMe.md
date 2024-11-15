## Start Services
docker compose up

## Setup Keycloak

URL: https://host.docker.internal:8443/

1. Create new realm: `ocis`
2. Add a new client:

- Client ID: `web`
- Root URL: `https://host.docker.internal:9200`

3. Add realm roles:

- Role name: `ocisAdmin`

4. Add a user:

- Username: `admin` and other info
- Create password
- Role Mapping: Assign `ocisAdmin` role

5. Update `roles` Client scope: `Client Scopes` -> `roles`

- `Mappers` -> `realm roles` -> `Token Claim Name=roles`

## oCIS Login

Login to the oCIS using the user created in the Keycloak.

URL: https://host.docker.internal:9200