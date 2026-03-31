#!/bin/bash

set -eo pipefail

JENKINS_URL="http://localhost:8080"
JENKINS_USER="irfan"
JENKINS_PASS="irfanirfan"

COOKIE_FILE="/tmp/jenkins_cookies.txt"

echo "Getting Jenkins crumb..."

CRUMB_RESPONSE=$(curl -s --cookie-jar $COOKIE_FILE \
  -u "$JENKINS_USER:$JENKINS_PASS" \
  "$JENKINS_URL/crumbIssuer/api/json")

echo "$CRUMB_RESPONSE" | jq . >/dev/null 2>&1 || {
  echo "Failed to get crumb:"
  echo "$CRUMB_RESPONSE"
  exit 1
}

JENKINS_CRUMB=$(echo "$CRUMB_RESPONSE" | jq -r .crumb)
CRUMB_FIELD=$(echo "$CRUMB_RESPONSE" | jq -r .crumbRequestField)

echo "Generating API token..."

TOKEN_RESPONSE=$(curl -s -X POST \
  -H "$CRUMB_FIELD:$JENKINS_CRUMB" \
  --cookie $COOKIE_FILE \
  "$JENKINS_URL/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=auto-token" \
  -u "$JENKINS_USER:$JENKINS_PASS")

echo "$TOKEN_RESPONSE" | jq . >/dev/null 2>&1 || {
  echo "Failed to generate token:"
  echo "$TOKEN_RESPONSE"
  exit 1
}

JENKINS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .data.tokenValue)

echo "Installing plugins..."

while read -r plugin; do
  [[ -z "$plugin" || "$plugin" =~ ^# ]] && continue

  echo "Installing $plugin..."

  curl -s -X POST \
    -H "Content-Type: text/xml" \
    -H "$CRUMB_FIELD:$JENKINS_CRUMB" \
    --cookie $COOKIE_FILE \
    --user "$JENKINS_USER:$JENKINS_TOKEN" \
    --data "<jenkins><install plugin='${plugin}' /></jenkins>" \
    "$JENKINS_URL/pluginManager/installNecessaryPlugins"

done < plugins.txt

echo "Restarting Jenkins..."

curl -s -X POST \
  -H "$CRUMB_FIELD:$JENKINS_CRUMB" \
  --cookie $COOKIE_FILE \
  --user "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/safeRestart"

echo "Done."
