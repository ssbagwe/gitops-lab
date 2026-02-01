FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG USERNAME=devuser
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Tool versions - pin these for reproducibility (updated January 2025)
ARG KUBECTL_VERSION=1.34.2
ARG HELM_VERSION=4.0.4
ARG KIND_VERSION=0.31.0
ARG TERRAFORM_VERSION=1.14.3
ARG ARGOCD_VERSION=3.2.6
ARG K9S_VERSION=0.50.18
ARG KUSTOMIZE_VERSION=5.6.0

# Install base dependencies
RUN apt-get update && apt-get install -y \
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
    fzf \
    tree \
    htop \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install pre-commit
RUN pip3 install --no-cache-dir pre-commit

# Install yq (mikefarah)
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64 \
    -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Create non-root user
RUN getent group $USER_GID || groupadd --gid $USER_GID $USERNAME && \
    id -u $USERNAME >/dev/null 2>&1 || \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/zsh && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# Install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar xz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64

# Install kind
RUN curl -fsSL "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64" -o /usr/local/bin/kind \
    && chmod +x /usr/local/bin/kind

# Install Terraform
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

# Install ArgoCD CLI
RUN curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64" -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd

# Install k9s
RUN curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz -C /tmp \
    && mv /tmp/k9s /usr/local/bin/k9s \
    && rm -rf /tmp/LICENSE /tmp/README.md

# Install kustomize
RUN curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" | tar xz -C /usr/local/bin

# Install kubectx and kubens
RUN git clone https://github.com/ahmetb/kubectx /opt/kubectx \
    && ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Install stern (log tailing)
RUN curl -fsSL "https://github.com/stern/stern/releases/download/v1.31.0/stern_1.31.0_linux_amd64.tar.gz" | tar xz -C /tmp \
    && mv /tmp/stern /usr/local/bin/stern

# Install AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Go (for operator SDK work, etc.)
ARG GO_VERSION=1.23.5
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar xz -C /usr/local

# Switch to non-root user for remaining setup
USER $USERNAME
WORKDIR /home/$USERNAME

# Set up Go paths
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/$USERNAME/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin:/home/$USERNAME/.krew/bin

# Install fzf shell integration (key bindings + completion)
RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --key-bindings --completion --no-update-rc

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
    && git clone https://github.com/romkatv/powerlevel10k ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k

# Install krew (kubectl plugin manager) as user
RUN set -x && cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v0.4.4/${KREW}.tar.gz" && \
    tar zxvf "${KREW}.tar.gz" && \
    ./"${KREW}" install krew

# Create directories
RUN mkdir -p /home/$USERNAME/.kube \
    /home/$USERNAME/.local/bin \
    /home/$USERNAME/.config/k9s

# Copy configuration files
COPY --chown=$USERNAME:$USERNAME configs/.zshrc /home/$USERNAME/.zshrc
COPY --chown=$USERNAME:$USERNAME configs/kind-config.yaml /home/$USERNAME/.local/kind-config.yaml
COPY --chown=$USERNAME:$USERNAME scripts/post-create.sh /home/$USERNAME/.local/bin/post-create.sh
COPY --chown=$USERNAME:$USERNAME scripts/post-start.sh /home/$USERNAME/.local/bin/post-start.sh
COPY --chown=$USERNAME:$USERNAME scripts/lab-helpers.sh /home/$USERNAME/.local/bin/lab-helpers.sh

RUN chmod +x /home/$USERNAME/.local/bin/*.sh

WORKDIR /workspaces
