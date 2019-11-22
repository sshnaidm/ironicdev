#FROM centos/python-36-centos7
FROM python:3.7-alpine

# RUN yum install -y python3-dev && \
#      pip install -U pip tox && \
#      git clone https://opendev.org/openstack/ironic

RUN apk add --no-cache --virtual .build-deps gcc postgresql-libs postgresql-dev python3-dev libffi-dev musl-dev && \
    apk add --no-cache ipmitool git && \
    git clone https://opendev.org/openstack/ironic /source && \
    python3 -m pip install --no-cache-dir \
    -c https://releases.openstack.org/constraints/upper/master \
    -r /source/requirements.txt \
    -r /source/test-requirements.txt && \
    python3 -m pip install -U python-openstackclient && \
    python3 -m pip install -U python-ironicclient && \
    python3 -m pip install -U tox && \
    pip install -e git+https://github.com/openstack/ironic#egg=ironic && \
    apk --purge del .build-deps

#RUN apk update && apk add git python3-dev && pip install tox && git clone https://opendev.org/openstack/ironic /source
WORKDIR /src/ironic

COPY start.sh /start.sh
ENTRYPOINT [ "/start.sh" ]
