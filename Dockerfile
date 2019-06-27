FROM alpine:3.7
RUN apk update && apk upgrade && apk --update --no-cache add bash vsftpd
COPY rootfs /
RUN chmod +x /entry.sh && ln -s ./ssl/fullchain.pem /etc/vsftpd/vsftpd.crt && ln -s ./ssl/key.pem /etc/vsftpd/v$
ENTRYPOINT ["/entry.sh"]
CMD ["/usr/sbin/vsftpd", "/etc/vsftpd/vsftpd.conf"]
