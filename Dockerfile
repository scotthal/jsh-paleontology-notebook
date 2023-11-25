FROM python:latest as build

RUN useradd -m -p '*' -s /bin/bash paleontologist
WORKDIR /home/paleontologist
USER paleontologist
ENV PATH="/home/paleontologist/.local/bin:${PATH}"

COPY ./requirements.txt ./
RUN pip install -r requirements.txt
COPY ./*.ipynb ./
COPY ./*.py ./
COPY ./project_sizes.sh ./project_sizes.sh
RUN jupyter nbconvert --no-prompt --to script stats.ipynb

FROM python:latest

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update; \
    apt-get -y dist-upgrade; \
    apt-get -y install bc parallel zstd; \
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists*
ENV DEBIAN_FRONTEND=

RUN useradd -m -p '*' -s /bin/bash paleontologist
WORKDIR /home/paleontologist
USER paleontologist
ENV PATH="/home/paleontologist/.local/bin:${PATH}"
ENV PAGER="/usr/bin/cat"

RUN pip install numpy
COPY --from=build /home/paleontologist/stats.sh /home/paleontologist/stats.sh
COPY --from=build /home/paleontologist/project_sizes.sh /home/paleontologist/project_sizes.sh
COPY --from=build /home/paleontologist/lsfit.py /home/paleontologist/lsfit.py

CMD ["/bin/bash"]
