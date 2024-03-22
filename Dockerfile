FROM alpine:latest as builder

# ARGs
ARG USER=user
ARG USER_PASSWORD=password
ARG USER_SUDO_ENABLED=false
ARG GROUP_NAME=group
ARG UID=1000
ARG GID=1000
ARG PYTHON_VERSION=3.12
ARG POETRY_HOME=/poetry

# ENV
ENV ZSH_THEME=robbyrussell

# ROOT
# update, upgrade and install packages
RUN apk update && apk upgrade && apk add --no-cache \
    sudo \
    shadow \
    zsh \
    zsh-vcs \
    bash \
    curl \
    git \
    build-base \
    libffi-dev \
    openssl-dev \
    bzip2-dev \
    zlib-dev \
    readline-dev \
    sqlite-dev \
    xz-dev 

# install pyenv globaly 
RUN git clone https://github.com/pyenv/pyenv.git /pyenv
ENV PYENV_ROOT=/pyenv
ENV PATH="$PYENV_ROOT/bin:$PATH"
# install python version
RUN pyenv install $PYTHON_VERSION
# set python version as global
RUN pyenv global $PYTHON_VERSION
RUN pyenv rehash
# add python from pyenv to current shell
RUN eval "$(pyenv init --path)"
# /bin/sh python: not found

# install poetry globaly
ENV POETRY_HOME=$POETRY_HOME
RUN curl -sSL https://install.python-poetry.org | $(pyenv which python) -
ENV PATH="$POETRY_HOME/bin:$PATH"

#  create new user and group
RUN addgroup -g $GID $GROUP_NAME || true \
    && adduser -D -u $UID -G $GROUP_NAME -s /bin/sh $USER || true \
    && echo "$USER:$USER_PASSWORD" | chpasswd \
    && if [ "$USER_SUDO_ENABLED" = "true" ]; then echo "$USER ALL=(ALL) ALL" >> /etc/sudoers.d/$USER && chmod 0440 /etc/sudoers.d/$USER; fi

# set the default shell for root to zsh
RUN chsh -s $(which zsh) \
    && sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && sed -i "s/robbyrussell/"'$ZSH_THEME'"/g" /root/.zshrc

# USER
USER $USER
# set the default shell for the user to zsh if the user is not root
RUN if [ $USER != "root" ]; \
    then \
        chsh -s $(which zsh) && \
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
        sed -i "s/robbyrussell/"'$ZSH_THEME'"/g" /home/$USER/.zshrc && \
        echo 'eval "$(pyenv init - --no-rehash)"' >> /home/$USER/.zshrc; \
    fi
# restart shell
# DEV BUILD (set up your development build here)
FROM builder as development
USER root
# ARGs
ARG WORKSPACE_DIR=/workspace
# ENV
ENV WORKSPACE_DIR=$WORKSPACE_DIR

# install packages
RUN apk add --no-cache \
    pre-commit --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
# create the workspace directory
RUN mkdir -p $WORKSPACE_DIR \
    && chown -R $USER:$GROUP_NAME $WORKSPACE_DIR \
    && chmod -R 770 $WORKSPACE_DIR


USER $USER
# set the working directory
WORKDIR $WORKSPACE_DIR
# set worspace as a safe directory
RUN git config --global --add safe.directory $WORKSPACE_DIR
# keep container running
CMD tail -f /dev/null

# PROD BUILD (set up your production build here)
FROM builder as production
USER root
# ARGs
ARG APP_DIR=/app
# ENV
ENV APP_DIR=$APP_DIR
# create the app directory
RUN mkdir -p $APP_DIR \
    && chown -R $UID:$GID $APP_DIR \
    && chmod -R 770 $APP_DIR

USER $USER
# set the working directory
WORKDIR $WORKSPACE_DIR

CMD echo "Well done! But you need to set up your production build."
