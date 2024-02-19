POSTGRES_ALPINE = "postgres:alpine3.18"
KEYCLOAK = "quay.io/keycloak/keycloak:22.0.4"
OC_CI_WAIT_FOR = "owncloudci/wait-for:latest"
OC_CI_ALPINE = "owncloudci/alpine:latest"
OC_OCIS = "owncloud/ocis:5.0.0-rc.3"
OC_CI_GOLANG = "owncloudci/golang:1.21"
OC_CI_NODEJS = "owncloudci/nodejs:18"

OCIS_ENV = {
    "OCIS_INSECURE": "true",
    "PROXY_ENABLE_BASIC_AUTH": "true",
    "IDM_ADMIN_PASSWORD": "admin",
    "OCIS_URL": "https://ocis:9200",
    "PROXY_TRANSPORT_TLS_KEY": "/usr/local/share/ca-certificates/ocis.pem",
    "PROXY_TRANSPORT_TLS_CERT": "/usr/local/share/ca-certificates/ocis.crt",
}

def postgresService():
    return [
        {
            "name": "postgres",
            "image": POSTGRES_ALPINE,
            "environment": {
                "POSTGRES_DB": "keycloak",
                "POSTGRES_USER": "keycloak",
                "POSTGRES_PASSWORD": "keycloak",
            },
        },
    ]

def keycloakService():
    return [
        {
            "name": "wait-for-postgres",
            "image": OC_CI_WAIT_FOR,
            "commands": [
                "wait-for -it postgres:5432 -t 300",
            ],
        },
        {
            "name": "keycloak",
            "image": KEYCLOAK,
            "detach": True,
            "environment": {
                "OCIS_DOMAIN": "host.docker.internal:9200",
                "KC_HOSTNAME": "keycloak:8080",
                "KC_DB": "postgres",
                "KC_DB_URL": "jdbc:postgresql://postgres:5432/keycloak",
                "KC_DB_USERNAME": "keycloak",
                "KC_DB_PASSWORD": "keycloak",
                "KC_FEATURES": "impersonation",
                "KEYCLOAK_ADMIN": "admin",
                "KEYCLOAK_ADMIN_PASSWORD": "admin",
            },
            "commands": [
                "ls -al",
                "mkdir -p /opt/keycloak/data/import",
                "cp ocis-realm.dist.json /opt/keycloak/data/import/ocis-realm.json",
                "/opt/keycloak/bin/kc.sh start-dev --proxy edge --spi-connections-http-client-default-disable-trust-manager=true --import-realm --health-enabled=true",
            ],
        },
        {
            "name": "wait-for-keycloak",
            "image": OC_CI_WAIT_FOR,
            "commands": [
                "wait-for -it keycloak:8080 -t 300",
            ],
        },
    ]

def ocisService():
    ocis_bin = "ocis/ocis/bin/ocis"
    environment = {
        "OCIS_URL": "https://ocis:9200",
        "OCIS_LOG_LEVEL": "error",
        "IDM_ADMIN_PASSWORD": "admin",  # override the random admin password from `ocis init`
        "PROXY_AUTOPROVISION_ACCOUNTS": "true",
        "PROXY_ROLE_ASSIGNMENT_DRIVER": "oidc",
        "OCIS_OIDC_ISSUER": "http://keycloak:8080/realms/oCIS",
        "PROXY_OIDC_REWRITE_WELLKNOWN": "true",
        "WEB_OIDC_CLIENT_ID": "web",
        "PROXY_USER_OIDC_CLAIM": "preferred_username",
        "PROXY_USER_CS3_CLAIM": "username",
        "OCIS_ADMIN_USER_ID": "",
        "OCIS_EXCLUDE_RUN_SERVICES": "idp",
        "GRAPH_ASSIGN_DEFAULT_USER_ROLE": "false",
        "GRAPH_USERNAME_MATCH": "none",
        "WEB_ASSET_PATH": "/home/amrita/yuna/owncloud/web/dist",
        "WEB_UI_CONFIG_FILE": "/home/amrita/yuna/owncloud/web/tests/drone/config-ocis.json",
    }

    return [
        {
            "name": "ocis",
            "image": OC_CI_GOLANG,
            "detach": True,
            "environment": environment,
            "commands": [
                "ls -al /home/amrita/yuna/owncloud/web",
                "%s init --insecure true" % ocis_bin,
                "%s server" % ocis_bin,
            ],
        },
        {
            "name": "wait-for-ocis-server",
            "image": OC_CI_WAIT_FOR,
            "commands": [
                "wait-for -it ocis:9200 -t 300",
            ],
        },
    ]

def buildOcis():
    ocis_repo_url = "https://github.com/owncloud/ocis.git"
    return [
        {
            "name": "clone-ocis",
            "image": OC_CI_GOLANG,
            "commands": [
                "git clone -b master --single-branch %s" % ocis_repo_url,
                "cd ocis",
            ],
        },
        {
            "name": "generate-ocis",
            "image": OC_CI_NODEJS,
            "commands": [
                # we cannot use the $GOPATH here because of different base image
                "cd ocis",
                "retry -t 3 'make ci-node-generate'",
            ],
        },
        {
            "name": "build-ocis",
            "image": OC_CI_GOLANG,
            "commands": [
                "cd ocis/ocis",
                "retry -t 3 'make build'",
            ],
        },
    ]

def e2e_tests():
    return [
        {
            "name": "e2e-tests",
            "image": OC_CI_NODEJS,
            "environment": {
                "BASE_URL_OCIS": "ocis:9200",
                "HEADLESS": "true",
                "RETRY": "1",
                "REPORT_TRACING": "true",
                "KEYCLOAK": "true",
                "KEYCLOAK_HOST": "http://keycloak:8080",
            },
            "commands": [
                "sleep 10",
                "pnpm test:e2e:cucumber tests/e2e/cucumber/features/journeys/kindergarten.feature",
            ],
        },
    ]

def main(ctx):
    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "start-services",
        "steps": buildOcis() + keycloakService() + ocisService() + e2e_tests(),
        "services": postgresService(),
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/heads/stable-*",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }]
