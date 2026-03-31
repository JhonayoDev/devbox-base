# ─────────────────────────────────────────────────────────────
#  devbox-base — imagen base genérica
#
#  Contiene SOLO herramientas comunes independientes de lenguaje:
#  SO, zsh, nvim, git, utilidades de terminal.
#
#  NO contiene: Java, Node, Flutter, Python ni ningún SDK.
#  Esas responsabilidades son de devbox-features.
#
#  Publicada en: ghcr.io/jhonayodev/devbox-base:latest
# ─────────────────────────────────────────────────────────────
FROM ubuntu:24.04

# ─── Build args ───────────────────────────────────────────────
# Todos los valores vienen de afuera — esta imagen no tiene
# nada hardcodeado específico de un usuario o entorno.
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=1000
ARG NVIM_VERSION=v0.11.6

# ─── Sistema base ─────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # SSH
    openssh-server \
    # Build tools — make requerido por nvim-treesitter para compilar parsers
    build-essential \
    make \
    libssl-dev \
    libffi-dev \
    # Utilidades esenciales
    curl wget git unzip zip \
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
    xclip xsel \
    # Python base: requerido por algunos plugins de nvim
    python3 python3-pip python3-venv \
    # Zsh
    zsh \
    fontconfig \
    # Utilidades extra
    tmux \
    htop \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Symlinks de nombres alternativos en Ubuntu
# fd-find se instala como fdfind — bat en Ubuntu 24.04 ya se llama bat
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

# ─── Locale UTF-8 ─────────────────────────────────────────────
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ─── Crear usuario ─────────────────────────────────────────────
# Ubuntu 24.04 trae el usuario "ubuntu" por defecto — lo eliminamos
# para evitar conflictos de UID con el usuario custom.
# Shell = zsh para que el .zshrc de dotfiles funcione correctamente.
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
# Requerido por Snacks.nvim (<leader>gg abre lazygit como terminal)
RUN LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//') \
    && curl -Lo /tmp/lazygit.tar.gz \
      "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit \
    && install /tmp/lazygit /usr/local/bin/lazygit \
    && rm -f /tmp/lazygit /tmp/lazygit.tar.gz

# ─── SSH ───────────────────────────────────────────────────────
RUN mkdir /var/run/sshd \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config

# ─── A partir de acá todo como el usuario ─────────────────────
USER $USERNAME
WORKDIR /home/$USERNAME

ENV HOME=/home/$USERNAME
ENV USER=$USERNAME

# ─── Oh My Zsh ────────────────────────────────────────────────
# RUNZSH=no evita que el installer intente lanzar zsh al terminar
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Plugins declarados en el .zshrc
RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-completions \
      "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions" \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# ─── SSH keys del usuario ──────────────────────────────────────
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh

# ─── Volver a root para el entrypoint ─────────────────────────
USER root

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
