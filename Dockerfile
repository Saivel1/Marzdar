ARG PYTHON_VERSION=3.12

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1

WORKDIR /code

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential curl unzip gcc python3-dev libpq-dev default-libmysqlclient-dev pkg-config libyaml-dev \
    && curl --fail --location --retry 5 --retry-delay 5 --connect-timeout 30 --output /tmp/install_latest_xray.sh https://raw.githubusercontent.com/Gozargah/Marzban-scripts/master/install_latest_xray.sh \
    && sed -i "s/curl -RL /curl --fail --retry 5 --retry-all-errors --retry-delay 5 -RL /" /tmp/install_latest_xray.sh \
    && for attempt in 1 2 3; do \
         bash /tmp/install_latest_xray.sh && break; \
         if [ "$attempt" -eq 3 ]; then exit 1; fi; \
         echo "Xray installation failed; retrying ($attempt/3)..."; \
         sleep 10; \
       done \
    && rm /tmp/install_latest_xray.sh \
    && rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /code/
RUN python3 -m pip install --upgrade pip "setuptools<81" \
    && pip install --no-cache-dir --upgrade -r /code/requirements.txt

FROM python:$PYTHON_VERSION-slim

ENV PYTHON_LIB_PATH=/usr/local/lib/python${PYTHON_VERSION%.*}/site-packages
WORKDIR /code

RUN apt-get update \
    && apt-get install -y --no-install-recommends libmariadb3 libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/*

RUN rm -rf $PYTHON_LIB_PATH/*

COPY --from=build $PYTHON_LIB_PATH $PYTHON_LIB_PATH
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/share/xray /usr/local/share/xray

COPY . /code

RUN ln -s /code/marzban-cli.py /usr/bin/marzban-cli \
    && chmod +x /usr/bin/marzban-cli \
    && marzban-cli completion install --shell bash

CMD ["bash", "-c", "alembic upgrade head; python main.py"]
