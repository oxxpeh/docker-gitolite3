FROM ubuntu:24.04
ARG GID=1001
ARG PASS=PassWord
ARG UID=1001
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y iproute2 iputils-ping gitolite3  openssh-server vim
# ssh start
RUN mkdir /var/run/sshd

RUN sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
RUN sed -i "s/#PermitEmptyPasswords no/PermitEmptyPasswords yes/" /etc/ssh/sshd_config

RUN echo "root:${PASS}" | chpasswd

RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# ssh end

COPY ssh_host_dsa_key /etc/ssh/
COPY ssh_host_dsa_key.pub /etc/ssh/
COPY ssh_host_ecdsa_key /etc/ssh/
COPY ssh_host_ecdsa_key.pub /etc/ssh/
COPY ssh_host_ed25519_key.pub /etc/ssh/
COPY ssh_host_ed25519_key /etc/ssh/
COPY ssh_host_rsa_key /etc/ssh/
COPY ssh_host_rsa_key.pub /etc/ssh/
COPY admin.pub /tmp/
RUN chmod 600 /etc/ssh/ssh_host_*

RUN addgroup --gid ${GID}  gitolite3
RUN adduser --system --shell /bin/bash --disabled-password\
 --home /home/gitolite3 --uid ${UID} --gid ${GID}  gitolite3

#RUN su - gitolite3 -c "gitolite setup -pk /tmp/admin.pub"

CMD ["/usr/sbin/sshd", "-D"]
