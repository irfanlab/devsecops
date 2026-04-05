#!/bin/bash

dockerImageName=$(awk 'NR==1 {print $2}' Dockerfile)
echo $dockerImageName

scan_failed=0

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ aquasec/trivy:0.69.3 -q image --exit-code 1 --severity LOW --light $dockerImageName
exit_code=$?
echo "LOW severity scan exit code: $exit_code"
if [[ "${exit_code}" == 1 ]]; then
    echo "LOW severity vulnerabilities found!"
    scan_failed=1
fi

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ aquasec/trivy:0.69.3 -q image --exit-code 1 --severity HIGH --light $dockerImageName
exit_code=$?
echo "HIGH severity scan exit code: $exit_code"
if [[ "${exit_code}" == 1 ]]; then
    echo "HIGH severity vulnerabilities found!"
    scan_failed=1
fi

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ aquasec/trivy:0.69.3 -q image --exit-code 1 --severity CRITICAL --light $dockerImageName
exit_code=$?
echo "CRITICAL severity scan exit code: $exit_code"
if [[ "${exit_code}" == 1 ]]; then
    echo "CRITICAL severity vulnerabilities found!"
    scan_failed=1
fi

# Final result
if [[ "${scan_failed}" == 1 ]]; then
    echo "Image scanning failed. Vulnerabilities found"
    exit 1;
else
    echo "Image scanning passed. No vulnerabilities found"
fi;