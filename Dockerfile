# Container image that runs your code
FROM node:14.16

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY *.sh /

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
