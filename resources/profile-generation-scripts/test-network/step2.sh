#!/bin/bash
set -Eeuo pipefail
shopt -s nullglob

# command-line arguments
if [[ $# -ne 2 && $# -ne 3 ]]; then
    echo "Wrong number of arguments, usage: bash $0 <network name> <node index> [<secret0,secret1,...>]"
    exit 1
fi
NETWORK_NAME="$1"
NODE_IDX="$2"
SECRETS="${3-}"

# convenience variables
PROFILE_NAME="test-network-${NETWORK_NAME}-node${NODE_IDX}"
SCRIPT_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MEDCO_UNLYNX_VER="v1.0.0"
CONF_FOLDER="${SCRIPT_FOLDER}/../../../configuration-profiles/${PROFILE_NAME}"
COMPOSE_FOLDER="${SCRIPT_FOLDER}/../../../compose-profiles/${PROFILE_NAME}"
if [[ ! -d ${CONF_FOLDER} ]] || [[ ! -d ${COMPOSE_FOLDER} ]] || [[ -f ${CONF_FOLDER}/group.toml ]]; then
    echo "The compose or configuration profile folder does not exist, or the step 2 has already been executed. Aborting."
    exit 2
fi

read -rp "### About to finalize the configuration of node ${NODE_IDX} for profile ${PROFILE_NAME}, <Enter> to continue, <Ctrl+C> to abort."

# ===================== archive extraction ==================
echo "### Extracting archives from other nodes"
pushd "${CONF_FOLDER}"
for archive in $(ls -1 srv*-public.tar.gz); do
    tar -zxvf "${archive}"
done
popd
echo "### Archives extracted"


# ===================== unlynx keys ====================
echo "### Generating group.toml and aggregate.txt files"
cat "${CONF_FOLDER}"/srv*-public.toml > "${CONF_FOLDER}/group.toml"
docker run -v "${CONF_FOLDER}:/medco-configuration" -u "$(id -u):$(id -g)" "medco/medco-unlynx:${MEDCO_UNLYNX_VER}" \
    server getAggregateKey --file "/medco-configuration/group.toml"
echo "### group.toml and aggregate.txt files generated"

echo "### Generating secrets"
if [[ -z ${SECRETS} ]]; then
    docker run -v "${CONF_FOLDER}:/medco-configuration" -u "$(id -u):$(id -g)" "medco/medco-unlynx:${MEDCO_UNLYNX_VER}" \
        server generateTaggingSecrets --file "/medco-configuration/group.toml" --nodeIndex "${NODE_IDX}"
else
    docker run -v "${CONF_FOLDER}:/medco-configuration" -u "$(id -u):$(id -g)" "medco/medco-unlynx:${MEDCO_UNLYNX_VER}" \
        server generateTaggingSecrets --file "/medco-configuration/group.toml" --nodeIndex "${NODE_IDX}" --secrets "${SECRETS}"
fi
echo "### secrets generated"


# ===================== compose profile =====================
echo "### Updating compose profile"
declare -a MEDCO_NODES_URL OIDC_JWKS_URLS OIDC_JWT_ISSUERS OIDC_CLIENT_IDS OIDC_JWT_USER_ID_CLAIMS
pushd "${CONF_FOLDER}"
# todo: the ls is doing the sorting OK up to 9 nodes, but not after that (e.g. if 10 is present it will come right after 1)
ITER_IDX=0
for nodednsname in srv*-nodednsname.txt; do
  MEDCO_NODES_URL+=("https://$(<"${nodednsname}")/medco")
  OIDC_JWKS_URLS+=("https://$(<"${nodednsname}")/auth/realms/master/protocol/openid-connect/certs")
  OIDC_JWT_ISSUERS+=("https://$(<"${nodednsname}")/auth/realms/master")
  OIDC_CLIENT_IDS+=("medco")
  OIDC_JWT_USER_ID_CLAIMS+=("preferred_username")

  ITER_IDX=$((ITER_IDX+1))
done
popd

export IFS=, # todo: this export might affect some commands executed after if they exist
cat >> "${COMPOSE_FOLDER}/.env" <<EOF
MEDCO_NODES_URL=${MEDCO_NODES_URL[*]}
OIDC_JWKS_URLS=${OIDC_JWKS_URLS[*]}
OIDC_JWT_ISSUERS=${OIDC_JWT_ISSUERS[*]}
OIDC_CLIENT_IDS=${OIDC_CLIENT_IDS[*]}
OIDC_JWT_USER_ID_CLAIMS=${OIDC_JWT_USER_ID_CLAIMS[*]}
EOF
echo "### DONE! MedCo profile ready"
