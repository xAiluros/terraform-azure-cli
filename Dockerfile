# Build arguments
ARG AZURE_CLI_VERSION
ARG TERRAFORM_VERSION
ARG PYTHON_MAJOR_VERSION=3.9
ARG DEBIAN_VERSION=bullseye-20221004-slim

# Download Terraform binary
FROM debian:${DEBIAN_VERSION} as terraform-cli
ARG TERRAFORM_VERSION
RUN apt-get update
RUN apt-get install --no-install-recommends -y curl
RUN apt-get install --no-install-recommends -y ca-certificates
RUN apt-get install --no-install-recommends -y unzip
RUN apt-get install --no-install-recommends -y gnupg
WORKDIR /workspace
RUN echo "Using terraform version: ${TERRAFORM_VERSION}"
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig
COPY hashicorp.asc hashicorp.asc
RUN gpg --import hashicorp.asc
RUN gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN grep terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS | sha256sum -c -
RUN unzip -j terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install az CLI using PIP
FROM debian:${DEBIAN_VERSION} as azure-cli
ARG AZURE_CLI_VERSION
ARG PYTHON_MAJOR_VERSION
RUN apt-get update
RUN apt-get install -y --no-install-recommends python${PYTHON_MAJOR_VERSION}
RUN apt-get install -y --no-install-recommends python3-pip
RUN pip3 install --no-cache-dir setuptools
RUN pip3 install --no-cache-dir azure-cli==${AZURE_CLI_VERSION}

# Build final image
FROM debian:${DEBIAN_VERSION}
LABEL maintainer="bgauduch@github"
ARG PYTHON_MAJOR_VERSION
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    python${PYTHON_MAJOR_VERSION} \
    python3-distutils \
    gosu \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_MAJOR_VERSION} 1
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
WORKDIR /workspace
COPY --from=terraform-cli /workspace/terraform /usr/local/bin/terraform
COPY --from=azure-cli /usr/local/bin/az* /usr/local/bin/
COPY --from=azure-cli /usr/local/lib/python${PYTHON_MAJOR_VERSION}/dist-packages /usr/local/lib/python${PYTHON_MAJOR_VERSION}/dist-packages
COPY --from=azure-cli /usr/lib/python3/dist-packages /usr/lib/python3/dist-packages

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]