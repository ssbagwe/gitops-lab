FROM ubuntu:24.04

ARG USERNAME=ubuntu

# Tool versions - pin these for reproducibility
ARG KUBECTL_VERSION=1.34.3
ARG HELM_VERSION=4.1.0
ARG KIND_VERSION=0.31.0
ARG TERRAFORM_VERSION=1.14.3
ARG ARGOCD_VERSION=3.3.0
ARG K9S_VERSION=0.50.18
ARG KUSTOMIZE_VERSION=5.6.0
ARG GO_VERSION=1.23.5
ARG KREW_VERSION=0.4.5
ARG STERN_VERSION=1.31.0

# Install base dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    apt-transport-https \
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
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Add to sudoers
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# Install Tools in ONE layer with cleanup
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar xz --strip-components=1 -C /usr/local/bin linux-amd64/helm \
    && curl -fsSL "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64" -o /usr/local/bin/kind \
    && chmod +x /usr/local/bin/kind \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/tf.zip \
    && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip \
    && curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64" -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd \
    && curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin k9s \
    && curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" | tar xz -C /usr/local/bin \
    && git clone --depth=1 https://github.com/ahmetb/kubectx /opt/kubectx \
    && ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && ln -s /opt/kubectx/kubens /usr/local/bin/kubens \
    && curl -fsSL "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz" | tar xz -C /usr/local/bin stern \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/aws.zip \
    && unzip -q /tmp/aws.zip -d /tmp \
    && /tmp/aws/install \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar xz -C /usr/local \
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
    && git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --key-bindings --completion --no-update-rc

# Create directories
RUN mkdir -p /home/$USERNAME/.local/bin \
    /home/$USERNAME/.config/k9s

# Copy configuration files
COPY --chown=$USERNAME:$USERNAME .devcontainer/configs/.zshrc /home/$USERNAME/.zshrc
COPY --chown=$USERNAME:$USERNAME .devcontainer/configs/kind-config.yaml /home/$USERNAME/.local/kind-config.yaml
COPY --chown=$USERNAME:$USERNAME .devcontainer/scripts/post-create.sh /home/$USERNAME/.local/bin/post-create.sh
COPY --chown=$USERNAME:$USERNAME .devcontainer/scripts/post-start.sh /home/$USERNAME/.local/bin/post-start.sh
COPY --chown=$USERNAME:$USERNAME .devcontainer/scripts/lab-helpers.sh /home/$USERNAME/.local/bin/lab-helpers.sh

RUN chmod +x /home/$USERNAME/.local/bin/*.sh

WORKDIR /workspaces

# Add labels for tracking
LABEL maintainer="Sameer Bagwe"
LABEL description="GitOps Lab Devcontainer"
LABEL versions.kubectl="${KUBECTL_VERSION}"
LABEL versions.helm="${HELM_VERSION}"
LABEL versions.kind="${KIND_VERSION}"
LABEL versions.terraform="${TERRAFORM_VERSION}"
LABEL versions.argocd="${ARGOCD_VERSION}"

# Healthcheck to verify essential tools are available
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD kubectl version --client && \
        helm version && \
        terraform version && \
        kind version && \
        argocd version --client || exit 1
