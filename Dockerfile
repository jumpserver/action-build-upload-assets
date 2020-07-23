# Container image that runs your code
FROM maven:3-jdk-8

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY *.sh /

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
