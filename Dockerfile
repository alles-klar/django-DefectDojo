########## Stage: build ##########
FROM python:3.7.2 as base

# Update and install basic requirements
# hadolint ignore=DL3008
RUN apt-get update && apt-get install --no-install-recommends -y default-libmysqlclient-dev libjpeg-dev gcc libssl-dev wkhtmltopdf build-essential curl apt-transport-https expect xmlsec1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# hadolint ignore=DL3013
RUN pip install --upgrade pip
WORKDIR /opt/django-DefectDojo

FROM base as yarn
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    #Node
    && curl -sL https://deb.nodesource.com/setup_6.x | bash \
    && apt-get update && apt-get install --no-install-recommends -y nodejs yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
COPY components/ components/
WORKDIR /opt/django-DefectDojo/components
RUN yarn
WORKDIR /opt/django-DefectDojo

FROM base as build
ENV PYTHONUNBUFFERED 1

# Install python packages
COPY setup/requirements.txt setup/postgresql.txt ./
RUN pip install --no-cache-dir -r postgresql.txt

# Add the application files
COPY --from=yarn /opt/django-DefectDojo/components components
COPY tests tests
COPY dojo dojo
COPY manage.py setup.py ./

RUN pip install .
RUN pip wheel --wheel-dir=/tmp/wheels -r postgresql.txt .
# COPY --from=yarn ? ?

# Create the application user
#RUN groupadd -r dojo && useradd --comment "DefectDojo" -r -g dojo dojo
#USER dojo
#RUN chown dojo:dojo -R /opt/django-DefectDojo

########## Stage: release ##########
FROM python:3.7.2-slim as release
# hadolint ignore=DL3008
RUN apt-get update \
    # libopenjp2-7 libjpeg62 libtiff5 are required by the pillow package
    && apt-get install --no-install-recommends -y expect  libopenjp2-7 libjpeg62 libtiff5 xmlsec1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3013
RUN pip install --no-cache-dir --upgrade pip

WORKDIR /opt/django-DefectDojo
COPY --from=build /tmp/wheels /tmp/wheels
COPY --from=yarn /opt/django-DefectDojo/components components
COPY tests tests
COPY dojo dojo
COPY manage.py ./
COPY setup/requirements.txt setup/postgresql.txt ./
# hadolint ignore=DL3013
RUN pip install \
      --no-cache-dir \
      --no-index \
      --find-links=/tmp/wheels \
      redis==3.2.0 djangosaml2==0.17.2 psycopg2-binary==2.7.5 DefectDojo

COPY entrypoint_scripts entrypoint_scripts
COPY wsgi.py wsgi_params docker-start.bash wait-for-it.sh ./
RUN chmod +x wait-for-it.sh docker-start.bash entrypoint_scripts/common/setup-superuser.expect

RUN groupadd -r dojo && useradd --no-log-init -r -g dojo dojo \
    && chown -R dojo /opt/django-DefectDojo/
USER dojo

CMD ["./docker-start.bash","-s"]