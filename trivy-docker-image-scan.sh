#!/bin/bash

dockerImageName=$(awk 'NR==1 {print $2}' Dockerfile)
echo $dockerImageName

# -----------------------------------------------------------
# FAIL_ON_SEVERITY: Set the minimum severity that should FAIL the build
#   CRITICAL - fail only on CRITICAL
#   HIGH     - fail on HIGH + CRITICAL
#   LOW      - fail on LOW + HIGH + CRITICAL
# -----------------------------------------------------------
FAIL_ON_SEVERITY="CRITICAL"

echo "Fail threshold set to: $FAIL_ON_SEVERITY"

scan_failed=0

# LOW severity scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ -v $(pwd):/workspace aquasec/trivy:0.69.3 -q image --ignorefile /workspace/.trivyignore --exit-code 1 --severity LOW --light $dockerImageName
exit_code=$?
echo "LOW severity scan exit code: $exit_code"
if [[ "${exit_code}" == 1 ]]; then
    echo "LOW severity vulnerabilities found!"
    if [[ "${FAIL_ON_SEVERITY}" == "LOW" ]]; then
        scan_failed=1
    fi
fi

# HIGH severity scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ -v $(pwd):/workspace aquasec/trivy:0.69.3 -q image --ignorefile /workspace/.trivyignore --exit-code 1 --severity HIGH --light $dockerImageName
exit_code=$?
echo "HIGH severity scan exit code: $exit_code"
if [[ "${exit_code}" == 1 ]]; then
    echo "HIGH severity vulnerabilities found!"
    if [[ "${FAIL_ON_SEVERITY}" == "LOW" || "${FAIL_ON_SEVERITY}" == "HIGH" ]]; then
        scan_failed=1
    fi
fi

# CRITICAL severity scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ -v $(pwd):/workspace aquasec/trivy:0.69.3 -q image --ignorefile /workspace/.trivyignore --exit-code 1 --severity CRITICAL --light $dockerImageName
exit_code=$?
echo "CRITICAL severity scan exit code: $exit_code"
if [[ "${exit_code}" == 1 ]]; then
    echo "CRITICAL severity vulnerabilities found!"
    scan_failed=1
fi

# Final result
if [[ "${scan_failed}" == 1 ]]; then
    echo "Image scanning failed. Vulnerabilities found at or above ${FAIL_ON_SEVERITY} severity"
    exit 1;
else
    echo "Image scanning passed. No vulnerabilities at or above ${FAIL_ON_SEVERITY} severity"
fi;