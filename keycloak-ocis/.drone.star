POSTGRES_ALPINE = "postgres:alpine3.18"
KEYCLOAK = "quay.io/keycloak/keycloak:22.0.4"
OC_CI_WAIT_FOR = "owncloudci/wait-for:latest"
OC_CI_ALPINE = "owncloudci/alpine:latest"
OC_OCIS = "owncloud/ocis:5.0.0-rc.3"
OC_CI_GOLANG = "owncloudci/golang:1.22"
OC_CI_NODEJS = "owncloudci/nodejs:18"
OC_UBUNTU = "owncloud/ubuntu:20.04"

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

def generateCerts():
    return [
        {
            "name": "generate-keycloak-certs",
            "image": OC_UBUNTU,
            "commands": [
                "apt install openssl -y",
                "mkdir keycloak-certs",
                "openssl req -x509  -newkey rsa:2048 -keyout keycloak-certs/keycloakkey.pem -out keycloak-certs/keycloakcrt.pem -nodes -days 365 -subj '/CN=keycloak'",
                "ls -al",
                "chmod -R 777 keycloak-certs",
                "ls -al",
            ],
            "volumes": [
                {
                    "name": "certs",
                    "path": "keycloak-certs",
                },
            ],
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
                "KC_HOSTNAME": "keycloak:8443",
                "KC_DB": "postgres",
                "KC_DB_URL": "jdbc:postgresql://postgres:5432/keycloak",
                "KC_DB_USERNAME": "keycloak",
                "KC_DB_PASSWORD": "keycloak",
                "KC_FEATURES": "impersonation",
                "KEYCLOAK_ADMIN": "admin",
                "KEYCLOAK_ADMIN_PASSWORD": "admin",
                "KC_HTTPS_CERTIFICATE_FILE": "./keycloak-certs/keycloakcrt.pem",
                "KC_HTTPS_CERTIFICATE_KEY_FILE": "./keycloak-certs/keycloakkey.pem",
            },
            "commands": [
                "cat keycloak-certs/keycloakkey.pem",
                "ls -al",
                "pwd",
                "ls -al",
                "mkdir -p /opt/keycloak/data/import",
                "cp ocis-realm.dist.json /opt/keycloak/data/import/ocis-realm.json",
                "/opt/keycloak/bin/kc.sh start-dev --proxy edge --spi-connections-http-client-default-disable-trust-manager=false --import-realm --health-enabled=true",
            ],
            "volumes": [
                {
                    "name": "certs",
                    "path": "keycloak-certs",
                },
            ],
        },
        {
            "name": "wait-for-keycloak",
            "image": OC_CI_WAIT_FOR,
            "commands": [
                "wait-for -it keycloak:8443 -t 300",
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
        "OCIS_OIDC_ISSUER": "https://keycloak:8443/realms/oCIS",
        "PROXY_OIDC_REWRITE_WELLKNOWN": "true",
        "WEB_OIDC_CLIENT_ID": "web",
        "PROXY_USER_OIDC_CLAIM": "preferred_username",
        "PROXY_USER_CS3_CLAIM": "username",
        "OCIS_ADMIN_USER_ID": "",
        "OCIS_EXCLUDE_RUN_SERVICES": "idp",
        "GRAPH_ASSIGN_DEFAULT_USER_ROLE": "false",
        "GRAPH_USERNAME_MATCH": "none",
        "WEB_ASSET_PATH": "web/dist",
    }

    return [
        {
            "name": "ocis",
            "image": OC_CI_GOLANG,
            "detach": True,
            "environment": environment,
            "commands": [
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
                "KEYCLOAK_HOST": "keycloak:8443",
            },
            "commands": [
                "cd web",
                "pnpm test:e2e:cucumber tests/e2e/cucumber/features/smoke/admin-settings/users.feature:20",
                "pnpm test:e2e:cucumber tests/e2e/cucumber/features/smoke/admin-settings/spaces.feature",
                "pnpm test:e2e:cucumber tests/e2e/cucumber/features/journey",
            ],
        },
    ]

def main(ctx):
    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "start-services",
        "steps": keycloakService() + buildOcis() + ocisService() + e2e_tests(),
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
