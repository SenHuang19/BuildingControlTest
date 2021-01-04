FROM michaelwetter/ubuntu-1804_jmodelica_trunk

ENV ROOT_DIR /usr/local
ENV JMODELICA_HOME $ROOT_DIR/JModelica
ENV IPOPT_HOME $ROOT_DIR/Ipopt-3.12.4
ENV SUNDIALS_HOME $JMODELICA_HOME/ThirdParty/Sundials
ENV SEPARATE_PROCESS_JVM /usr/lib/jvm/java-8-openjdk-amd64/
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV PYTHONPATH $PYTHONPATH:$JMODELICA_HOME/Python:$JMODELICA_HOME/Python/pymodelica
ENV MODELICAPATH $MODELICAPATH:/home/developer/library

USER developer

WORKDIR $HOME

RUN mkdir fmu && \
    mkdir library

RUN pip install --user flask-restful pandas

COPY model/testcase.py $HOME/

COPY model/web.py $HOME/

COPY model/config $HOME/

COPY model/fmu $HOME/fmu/

COPY model/library $HOME/library/