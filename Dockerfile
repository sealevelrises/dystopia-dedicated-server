FROM debian:bullseye-slim AS dystopia

ARG USER=steam
ARG HOME="/home/${USER}"
ARG STEAMCMDDIR="${HOME}/steamcmd"
ARG GAME_DIR="dystopia"
ARG GAME_PATH="${HOME}/${GAME_DIR}"
ARG METAMOD_VERSION=1.11/mmsource-1.11.0-git1148-linux
ARG SOURCEMOD_VERSION=1.11/sourcemod-1.11.0-git6906-linux

RUN set +x \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		ca-certificates \
		locales \
		wget \
		libsdl2-2.0-0:i386 

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales

# Install SteamCmd
RUN mkdir -p "${STEAMCMDDIR}" \
	&& mkdir -p "${GAME_PATH}/${GAME_DIR}" \
	&& mkdir -p "${GAME_PATH}/steamapps" \
	&& wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C "${STEAMCMDDIR}"

# Install Dystopia
RUN "${STEAMCMDDIR}/steamcmd.sh" \
		+force_install_dir "${GAME_PATH}" \
		+login anonymous \
		+app_update 17585 \
		+quit

# Install MetaMod (comment out for tournament servers)
RUN wget -qO- "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}.tar.gz" | tar xvzf - -C "${GAME_PATH}/${GAME_DIR}" \
	&& rm "${GAME_PATH}/${GAME_DIR}/addons/metamod_x64.vdf"

# Install Sourcemod (comment out for tournament servers)
RUN wget -qO- "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}.tar.gz" | tar xvzf - -C "${GAME_PATH}/${GAME_DIR}"


FROM debian:bullseye-slim

RUN set -x \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		lib32stdc++6 \
		lib32gcc-s1 \
		libncurses5:i386 \
		ca-certificates \
		locales \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales\
	&& apt-get autoremove -y \
	&& apt-get clean autoclean \
	&& rm -rf /var/lib/apt/lists/*

ARG PUID=1000
ARG USER=steam
ARG HOME="/home/${USER}"
ARG STEAMCMDDIR="${HOME}/steamcmd"
ARG GAME_DIR="dystopia"
ARG GAME_PATH="${HOME}/${GAME_DIR}"

RUN useradd -u "${PUID}" -m "${USER}"

# Copy Dystopia from build
COPY --chown=${PUID}:${PUID} --from=dystopia ${HOME} ${HOME}

# Copy external items
COPY --chown=${PUID}:${PUID} etc/cfg/server.cfg ${GAME_PATH}/${GAME_DIR}/cfg/server.cfg
COPY --chown=${PUID}:${PUID} etc/addons/ ${GAME_PATH}/${GAME_DIR}/addons/

RUN mkdir -p "${HOME}/.steam/sdk32" \
	&& ln -s "${STEAMCMDDIR}/linux32/steamclient.so" "${HOME}/.steam/sdk32/steamclient.so" \
	&& ln -s "${STEAMCMDDIR}/linux32/steamcmd" "${STEAMCMDDIR}/linux32/steam" \
	&& ln -s "${STEAMCMDDIR}/steamcmd.sh" "${STEAMCMDDIR}/steam.sh"

USER ${USER}

WORKDIR ${HOME}

ARG GAME_PORT=27016
ARG CLIENT_PORT=27006
ARG GAME_MAXPLAYERS=16
ARG GAME_MAP="dys_detonate"
ARG GAME_TICKRATE=66

ENV GAME_DIR=${GAME_DIR}
ENV GAME_PATH=${GAME_PATH}
ENV GAME_PORT=${GAME_PORT}
ENV CLIENT_PORT=${CLIENT_PORT}
ENV GAME_MAXPLAYERS=${GAME_MAXPLAYERS}
ENV GAME_MAP=${GAME_MAP}
ENV GAME_TICKRATE=${GAME_TICKRATE}

ENV GAME_ARGS="+maxplayers ${GAME_MAXPLAYERS} +map ${GAME_MAP} -tickrate ${GAME_TICKRATE} +log on +dys_stats_enabled 0"
ENV LD_LIBRARY_PATH="${GAME_PATH}/bin:${GAME_PATH}/bin/linux32:$LD_LIBRARY_PATH"

# Run the server
CMD ${GAME_PATH}/bin/linux32/srcds -port ${GAME_PORT} -clientport ${CLIENT_PORT} -game ${GAME_PATH}/${GAME_DIR} ${GAME_ARGS}

# Client ports
EXPOSE ${GAME_PORT}/tcp
EXPOSE ${GAME_PORT}/udp
EXPOSE ${CLIENT_PORT}/udp
