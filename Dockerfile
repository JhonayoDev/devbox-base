# ─────────────────────────────────────────────────────────────
#  devbox-base — imagen base genérica para devcontainers
#
#  Contiene SOLO herramientas comunes independientes de lenguaje:
#  SO, zsh + OMZ + plugins, nvim, lazygit, utilidades de terminal.
#
#  NO contiene: Java, Node, Flutter, Python SDK ni ningún runtime.
#  Esas responsabilidades son de las devcontainer features.
#
#  NO contiene: configuración personal (.zshrc, temas, nvim config).
#  Esas responsabilidades son de los dotfiles via DevPod.
#
#  Publicada en: ghcr.io/jhonayodev/devbox-base:latest
# ─────────────────────────────────────────────────────────────
FROM ubuntu:24.04

# ─── Build args — obligatorios, sin default intencional ───────
# Cada proyecto debe pasarlos explícitamente en devcontainer.json:
#   "build": { "args": { "USERNAME": "vscode", "USER_UID": "1000", "USER_GID": "1000" } }
# Si no se pasan, el build falla — es intencional para evitar
# usuarios incorrectos silenciosos.
ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG NVIM_VERSION=v0.11.0

# Validar que los args obligatorios fueron pasados
RUN : "${USERNAME:?USERNAME es obligatorio. Pásalo via build.args en devcontainer.json}" \
  && : "${USER_UID:?USER_UID es obligatorio. Pásalo via build.args en devcontainer.json}" \
  && : "${USER_GID:?USER_GID es obligatorio. Pásalo via build.args en devcontainer.json}"

# ─── Sistema base ─────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
  # Build tools — make requerido por nvim-treesitter para compilar parsers
  build-essential \
  make \
  libssl-dev \
  libffi-dev \
  # Utilidades esenciales
  curl \
  wget \
  git \
  unzip \
  zip \
  ca-certificates \
  gnupg \
  locales \
  tzdata \
  sudo \
  # tar + gzip: Mason los usa para descomprimir binarios de LSPs
  tar \
  gzip \
  # Herramientas de terminal requeridas por nvim/LazyVim
  ripgrep \
  fd-find \
  fzf \
  tree \
  bat \
  xclip \
  xsel \
  # Python base: requerido por algunos plugins de nvim y Mason
  python3 \
  python3-pip \
  python3-venv \
  # Zsh
  zsh \
  fontconfig \
  stow \
  # Utilidades extra
  htop \
  jq \
  && rm -rf /var/lib/apt/lists/*

# Symlinks de nombres alternativos en Ubuntu
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

# ─── Locale UTF-8 ─────────────────────────────────────────────
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ─── Crear usuario ────────────────────────────────────────────
# Ubuntu 24.04 trae el usuario "ubuntu" por defecto — lo eliminamos
# para evitar conflictos de UID.
# Shell = zsh desde la creación del usuario.
RUN userdel -r ubuntu 2>/dev/null || true \
  && groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m -s /usr/bin/zsh $USERNAME \
  && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# ─── Neovim ───────────────────────────────────────────────────
# Versión fijada para builds reproducibles.
# Para actualizar: cambiar NVIM_VERSION y hacer --no-cache
RUN curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
  && tar -C /opt -xzf nvim-linux-x86_64.tar.gz \
  && ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
  && rm nvim-linux-x86_64.tar.gz

# ─── lazygit ──────────────────────────────────────────────────
RUN LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//') \
  && curl -Lo /tmp/lazygit.tar.gz \
  "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
  && tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit \
  && install /tmp/lazygit /usr/local/bin/lazygit \
  && rm -f /tmp/lazygit /tmp/lazygit.tar.gz

# ─── A partir de acá todo como el usuario ─────────────────────
USER $USERNAME
WORKDIR /home/$USERNAME
ENV HOME=/home/$USERNAME
ENV USER=$USERNAME

# ─── Oh My Zsh + plugins + powerlevel10k ──────────────────────
# Instalados en la imagen — son infraestructura, no configuración.
# La configuración personal (.zshrc, tema activo) viene de dotfiles.
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" \
  && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" \
  && git clone --depth=1 https://github.com/zsh-users/zsh-completions \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions" \
  && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
