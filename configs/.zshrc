export ZSH="$HOME/.oh-my-zsh"
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

#ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_THEME="gnzh"

plugins=(
  git
  kubectl
  helm
  terraform
  docker
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf
)

source $ZSH/oh-my-zsh.sh

# Go paths
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.local/bin:${KREW_ROOT:-$HOME/.krew}/bin

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kctx='kubectx'
alias kns='kubens'

# Helm aliases
alias h='helm'
alias hl='helm list'
alias hi='helm install'
alias hu='helm upgrade'
alias hd='helm delete'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'

# ArgoCD aliases
alias argo='argocd'

# Krew plugin aliases (installed via post-create)
alias kimg='kubectl images'          # Show container images in pods
alias ktree='kubectl tree'           # Show resource hierarchy
alias kneat='kubectl neat'           # Clean up yaml output
alias kcap='kubectl resource-capacity'  # Show node resource capacity
# kubectl ctx and kubectl ns work via krew (same as kubectx/kubens)

# Kind aliases
alias kind-up='kind create cluster --config ~/.local/kind-config.yaml --name lab'
alias kind-down='kind delete cluster --name lab'
alias kind-reset='kind-down && kind-up'

# LocalStack aliases
alias laws='aws --endpoint-url=http://localhost:4566'

# Lab helper functions
source ~/.local/bin/lab-helpers.sh

# Auto-complete
source <(kubectl completion zsh)
source <(helm completion zsh)
source <(kind completion zsh)
source <(argocd completion zsh)

# Nice prompt showing k8s context
PROMPT='%{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)%{$fg[yellow]%}[$(kubectl config current-context 2>/dev/null || echo "no-ctx")]%{$reset_color%} $ '

echo "🚀 GitOps Lab ready!"
echo "   Run 'lab-status' to check environment"
echo "   Run 'lab-up' to start the full stack"
