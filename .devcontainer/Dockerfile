FROM ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b

ARG TARGETARCH

ARG USERNAME=ubuntu

# Tool versions - pin these for reproducibility
ARG KUBECTL_VERSION=1.34.4
ARG HELM_VERSION=4.1.0
ARG KIND_VERSION=0.31.0
ARG TERRAFORM_VERSION=1.14.3
ARG ARGOCD_VERSION=3.3.0
ARG K9S_VERSION=0.50.18
ARG KUSTOMIZE_VERSION=5.6.0
ARG GO_VERSION=1.23.5
ARG KREW_VERSION=0.4.5
ARG STERN_VERSION=1.31.0
ARG STEP_CLI_VERSION=0.29.0
ARG YQ_VERSION=4.44.6
ARG KUBECTX_VERSION=0.9.5
ARG FZF_VERSION=0.67.0

# Install base dependencies
RUN apt-get update && apt-get install -y \
    # checkov:skip=CKV2_DOCKER_1: Acceptable for Dev container
    sudo \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    git \
    jq \
    vim \
    zsh \
    tree \
    htop \
    python3 \
    python3-pip \
    python3-boto3 \
    python3-pytest \
    pre-commit \
    net-tools \
    iputils-ping \
    ncat \
    iproute2 \
    && apt-get clean

# Add to sudoers
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# Install Tools in ONE layer with cleanup
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xz --strip-components=1 -C /usr/local/bin linux-${TARGETARCH}/helm \
    && curl -fsSL "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${TARGETARCH}" -o /usr/local/bin/kind \
    && chmod +x /usr/local/bin/kind \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/tf.zip \
    && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip \
    && curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${TARGETARCH}" -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd \
    && curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin k9s \
    && curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin \
    && git clone --depth=1 --branch v${KUBECTX_VERSION} https://github.com/ahmetb/kubectx /opt/kubectx \
    && ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && ln -s /opt/kubectx/kubens /usr/local/bin/kubens \
    && curl -fsSL "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin stern \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/aws.zip \
    && unzip -q /tmp/aws.zip -d /tmp \
    && /tmp/aws/install \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" | tar xz -C /usr/local \
    && curl -fsSL "https://dl.smallstep.com/gh-release/cli/gh-release-header/v${STEP_CLI_VERSION}/step_linux_${STEP_CLI_VERSION}_${TARGETARCH}.tar.gz" | tar xz --strip-components=2 -C /usr/local/bin step_${STEP_CLI_VERSION}/bin/step \
    && rm -rf /tmp/*

# Switch to non-root user for remaining setup
USER $USERNAME
WORKDIR /home/$USERNAME

# Set up Go paths
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/$USERNAME/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin:/home/$USERNAME/.krew/bin

# Install oh-my-zsh + plugins + krew in ONE layer
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k \
    && cd "$(mktemp -d)" \
    && OS="$(uname | tr '[:upper:]' '[:lower:]')" \
    && ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')" \
    && KREW="krew-${OS}_${ARCH}" \
    && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v${KREW_VERSION}/${KREW}.tar.gz" \
    && tar zxf "${KREW}.tar.gz" \
    && ./"${KREW}" install krew \
    && git clone --depth 1 --branch v${FZF_VERSION} https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --key-bindings --completion --no-update-rc \
    && mkdir -p /home/$USERNAME/.local/bin \
    /home/$USERNAME/.config/k9s

# Copy configuration files
COPY --chown=$USERNAME:$USERNAME .devcontainer/configs/.zshrc /home/$USERNAME/.zshrc
COPY --chown=$USERNAME:$USERNAME .devcontainer/configs/kind-config.yaml /home/$USERNAME/.local/kind-config.yaml
COPY --chown=$USERNAME:$USERNAME --chmod=755 .devcontainer/scripts/post-create.sh /home/$USERNAME/.local/bin/post-create.sh
COPY --chown=$USERNAME:$USERNAME --chmod=755 .devcontainer/scripts/post-start.sh /home/$USERNAME/.local/bin/post-start.sh
COPY --chown=$USERNAME:$USERNAME --chmod=755 .devcontainer/scripts/lab-helpers.sh /home/$USERNAME/.local/bin/lab-helpers.sh

WORKDIR /workspaces

# Add labels for tracking
LABEL maintainer="Sameer Bagwe" \
    description="GitOps Lab Devcontainer" \
    versions.kubectl="${KUBECTL_VERSION}" \
    versions.helm="${HELM_VERSION}" \
    versions.kind="${KIND_VERSION}" \
    versions.terraform="${TERRAFORM_VERSION}" \
    versions.argocd="${ARGOCD_VERSION}"
