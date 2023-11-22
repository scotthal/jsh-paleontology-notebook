FROM python:latest as build

RUN useradd -m -p '*' -s /bin/bash paleontologist
WORKDIR /home/paleontologist
USER paleontologist
ENV PATH="/home/paleontologist/.local/bin:${PATH}"

COPY ./requirements.txt ./
RUN pip install -r requirements.txt
COPY ./*.ipynb ./
COPY ./*.py ./
RUN jupyter nbconvert --no-prompt --to script stats.ipynb

FROM python:latest

RUN useradd -m -p '*' -s /bin/bash paleontologist
WORKDIR /home/paleontologist
USER paleontologist
ENV PATH="/home/paleontologist/.local/bin:${PATH}"
ENV PAGER="/usr/bin/cat"

RUN pip install numpy
COPY --from=build /home/paleontologist/stats.sh /home/paleontologist/stats.sh
COPY --from=build /home/paleontologist/lsfit.py /home/paleontologist/lsfit.py

CMD ["/bin/bash"]
