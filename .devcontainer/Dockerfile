FROM ubuntu:24.04@sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9

ARG TARGETARCH

ARG USERNAME=ubuntu

# Tool versions - pin these for reproducibility
ARG KUBECTL_VERSION=1.34.4
ARG HELM_VERSION=4.1.1
ARG KIND_VERSION=0.31.0
ARG TERRAFORM_VERSION=1.14.5
ARG ARGOCD_VERSION=3.3.2
ARG K9S_VERSION=0.50.18
ARG KUSTOMIZE_VERSION=5.8.1
ARG GO_VERSION=1.26.0
ARG KREW_VERSION=0.4.5
ARG STERN_VERSION=1.33.1
ARG STEP_CLI_VERSION=0.29.0
ARG YQ_VERSION=4.52.4
ARG KUBECTX_VERSION=0.9.5
ARG FZF_VERSION=0.67.0

# Install base dependencies
RUN echo "==> Installing base packages" \
    && apt-get update && apt-get install -y \
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
    && apt-get clean \
    && echo "==> Base packages installed successfully"

# Add to sudoers
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# Install Tools in ONE layer with cleanup
RUN echo "==> Installing yq v${YQ_VERSION}" \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && echo "==> Installing kubectl v${KUBECTL_VERSION}" \
    && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && echo "==> Installing helm v${HELM_VERSION}" \
    && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xz --strip-components=1 -C /usr/local/bin linux-${TARGETARCH}/helm \
    && echo "==> Installing kind v${KIND_VERSION}" \
    && curl -fsSL "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${TARGETARCH}" -o /usr/local/bin/kind \
    && chmod +x /usr/local/bin/kind \
    && echo "==> Installing terraform v${TERRAFORM_VERSION}" \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/tf.zip \
    && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip \
    && echo "==> Installing argocd v${ARGOCD_VERSION}" \
    && curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${TARGETARCH}" -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd \
    && echo "==> Installing k9s v${K9S_VERSION}" \
    && curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin k9s \
    && echo "==> Installing kustomize v${KUSTOMIZE_VERSION}" \
    && curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin \
    && echo "==> Installing kubectx/kubens v${KUBECTX_VERSION}" \
    && git clone --depth=1 --branch v${KUBECTX_VERSION} https://github.com/ahmetb/kubectx /opt/kubectx \
    && ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && ln -s /opt/kubectx/kubens /usr/local/bin/kubens \
    && echo "==> Installing stern v${STERN_VERSION}" \
    && curl -fsSL "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin stern \
    && echo "==> Installing AWS CLI" \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/aws.zip \
    && unzip -q /tmp/aws.zip -d /tmp \
    && /tmp/aws/install \
    && echo "==> Installing Go v${GO_VERSION}" \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" | tar xz -C /usr/local \
    && echo "==> Installing step-cli v${STEP_CLI_VERSION}" \
    && curl -fsSL "https://dl.smallstep.com/gh-release/cli/gh-release-header/v${STEP_CLI_VERSION}/step_linux_${STEP_CLI_VERSION}_${TARGETARCH}.tar.gz" | tar xz --strip-components=2 -C /usr/local/bin step_${STEP_CLI_VERSION}/bin/step \
    && rm -rf /tmp/* \
    && echo "==> All tools installed successfully"

# Switch to non-root user for remaining setup
USER $USERNAME
WORKDIR /home/$USERNAME

# Set up Go paths
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/$USERNAME/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin:/home/$USERNAME/.krew/bin

# Install oh-my-zsh + plugins + krew in ONE layer
RUN echo "==> Installing oh-my-zsh" \
    && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && echo "==> Installing zsh plugins" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
    && echo "==> Installing powerlevel10k theme" \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k \
    && echo "==> Installing krew v${KREW_VERSION}" \
    && cd "$(mktemp -d)" \
    && OS="$(uname | tr '[:upper:]' '[:lower:]')" \
    && ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')" \
    && KREW="krew-${OS}_${ARCH}" \
    && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v${KREW_VERSION}/${KREW}.tar.gz" \
    && tar zxf "${KREW}.tar.gz" \
    && ./"${KREW}" install krew \
    && echo "==> Installing fzf v${FZF_VERSION}" \
    && git clone --depth 1 --branch v${FZF_VERSION} https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --key-bindings --completion --no-update-rc \
    && mkdir -p /home/$USERNAME/.local/bin \
    /home/$USERNAME/.config/k9s \
    && echo "==> User-space setup complete"

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
