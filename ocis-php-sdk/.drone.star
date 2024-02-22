POSTGRES_ALPINE = "postgres:alpine3.18"
KEYCLOAK = "quay.io/keycloak/keycloak:22.0.4"
OC_CI_WAIT_FOR = "owncloudci/wait-for:latest"
OC_CI_ALPINE = "owncloudci/alpine:latest"
OC_OCIS = "owncloud/ocis:5.0.0-rc.3"
OC_CI_GOLANG = "owncloudci/golang:1.21"
OC_CI_NODEJS = "owncloudci/nodejs:18"
OC_CI_PHP = "owncloudci/php:%s"

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
                "OCIS_DOMAIN": "ocis:9200",
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
    }

    return [
        {
            "name": "ocis",
            "image": OC_CI_GOLANG,
            "detach": True,
            "environment": environment,
            "commands": [
                "%s init --insecure true" % ocis_bin,
                "ls -al",
                "./ocis/tests/ociswrapper/bin/ociswrapper serve --bin ocis/ocis/bin/ocis --url %s" % "https://ocis:9200",
            ],
        },
        {
            "name": "wait-for-ocis-server",
            "image": OC_CI_WAIT_FOR,
            "commands": [
                "wait-for -it ocis:9200 -t 300",
            ],
        },
        {
            "name": "php-integration",
            "image": OC_CI_PHP % 8.2,
            "environment": {
                "OCIS_URL": "https://ocis:9200",
                "OCISWRAPPER_URL": "http://ocis:5200",
            },
            "commands": [
                "git clone https://github.com/ocis-php-sdk",
                "ls -al",
                "cd sdk",
                "composer install",
                "make test-php-integration-ci",
            ],
        },
    ]

def buildOcis():
    ocis_repo_url = "https://github.com/rhafer/ocis.git"
    return [
        {
            "name": "clone-ocis",
            "image": OC_CI_GOLANG,
            "commands": [
                "git clone -b issue/8080 --single-branch %s" % ocis_repo_url,
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

def main(ctx):
    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "start-services",
        "steps": keycloakService() + ocisService(),
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
