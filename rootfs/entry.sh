#!/usr/bin/env bash

set -e

[ "$DEBUG" == 'true' ] && set -x

DAEMON=vsftpd

#Setting PASV parameters
echo ">> Setting PASV parameters"
if [ -n "$PASV_MAX" ]; then
  echo "pasv_max_port=$PASV_MAX" >> /etc/vsftpd/vsftpd.conf
  if [ -n "$PASV_MIN" ]; then
    echo "pasv_min_port=$PASV_MIN" >> /etc/vsftpd/vsftpd.conf
    if [ -n "$PASV_ADDRESS" ]; then
      echo "pasv_address=$PASV_ADDRESS" >> /etc/vsftpd/vsftpd.conf
    else
      echo "!! PASV_ADDRESS not set, setup failed!"
      exit 1
    fi
  else
    echo "!! PASV_MIN not set, setup failed!"
    exit 1
  fi
else
  echo "!! PASV_MAX not set, setup failed!"
  exit 1
fi

# Create FTP users
if [ -n "${FTP_USERS}" ]; then
  USERS=$(echo $FTP_USERS | tr "," "\n")
  for U in $USERS; do
    IFS=':' read -ra FU <<< "$U"
    _NAME=${FU[0]}
    _PASS=${FU[1]}
    _UID=${FU[2]}
    _GID=${FU[3]}

    echo ">> Adding user ${_NAME} with uid: ${_UID}, gid: ${_GID}."
    getent group ${_NAME} >/dev/null 2>&1 || addgroup -g ${_GID} ${_NAME}
    getent passwd ${_NAME} >/dev/null 2>&1 || adduser -D -u ${_UID} -G ${_NAME} -s '/bin/false' ${_NAME}
    echo "${_NAME}:${_PASS}" | /usr/sbin/chpasswd

    # Add directory symlinks for users
    if [[ -n "${SYMLINK}" ]]; then
      echo "chroot_local_user=NO" >> /etc/vsftpd/vsftpd.conf
      DIRS=$(echo $SYMLINK | tr "," "\n")
      for D in $DIRS; do
          IFS=':' read -ra DS <<< "$D"
          _DIR=${DS[0]}
          _DST=${DS[1]}

          echo ">> Creating symbolic link /home/${_NAME}/${_DST} for ${_DIR}"
          if [ ! -d "/home/${_NAME}/${_DST}" ]; then
              ln -s ${_DIR} /home/${_NAME}/${_DST}
          fi
      done
    else
      echo "chroot_local_user=YES" >> /etc/vsftpd/vsftpd.conf
    fi
  done
else
  echo "!! FTP_USERS not set, setup failed!"
  exit 1
fi

cat << _EOF >> /etc/vsftpd/vsftpd.conf
local_enable=YES
allow_writeable_chroot=YES
max_clients=10
max_per_ip=5
write_enable=YES
local_umask=022
passwd_chroot_enable=YES
pasv_enable=YES
listen_ipv6=NO
seccomp_sandbox=NO
ftpd_banner=${FTP_BANNER}
_EOF

# Catch stop signals
stop() {
    echo "Received SIGINT or SIGTERM. Shutting down $DAEMON"
    # Get PID
    pid=$(cat /var/run/$DAEMON/$DAEMON.pid)
    # Set TERM
    kill -SIGTERM "${pid}"
    # Wait for exit
    wait "${pid}"
    # All done.
    # All done.
    echo "Done."
}

echo "Running $@"
if [ "$(basename $1)" == "$DAEMON" ]; then
    trap stop SIGINT SIGTERM
    $@ &
    pid="$!"
    mkdir -p /var/run/$DAEMON && echo "${pid}" > /var/run/$DAEMON/$DAEMON.pid
    wait "${pid}" && exit $?
else
    exec "$@"
fi
