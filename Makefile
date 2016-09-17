JAVA_DIRECTORY=/usr/lib/jvm/java-8-openjdk
HDFS_DIRECTORY=hadoop-2.6.0
SPARK_DIRECTORY=spark-1.6.0-bin-hadoop2.6
HDFS_MASTER_HOST=arch-vbox
HDFS_MASTER_PORT=9000
HDFS_MASTER_URI=hdfs://${HDFS_MASTER_HOST}:${HDFS_MASTER_PORT}
HDFS_SLAVES=arch-vbox
SPARK_MASTER_HOST=arch-vbox
SPARK_MASTER_PORT=7077
SPARK_MASTER_URI=spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT}
SPARK_SLAVES=arch-vbox
INPUT_DIRECTORY=test
INPUT_DIRECTORY_URI=${HDFS_MASTER_URI}/${INPUT_DIRECTORY}
SHINGLE_SIZE=2
SIGNATURE_SIZE=10
NUMBER_OF_BOUNDS=4
CONFIGURATION_DIRECTORY=configuration

.PHONY: run
run: start-services copy-input-to-hdfs SimilarDocuments/target/scala-2.10/similar-documents_2.10-1.0.jar
	${SPARK_DIRECTORY}/bin/spark-submit --master ${SPARK_MASTER_URI} --class SimilarDocuments SimilarDocuments/target/scala-2.10/similar-documents_2.10-1.0.jar ${INPUT_DIRECTORY_URI} ${SHINGLE_SIZE} ${SIGNATURE_SIZE} ${NUMBER_OF_BOUNDS}

.PHONY: start-services
start-services: start-hdfs start-spark

.PHONY: start-hdfs
start-hdfs: ${HDFS_DIRECTORY}/.created update-hdfs-config
	${HDFS_DIRECTORY}/sbin/start-dfs.sh

.PHONY: update-hdfs-config
update-hdfs-config: ${HDFS_DIRECTORY}/.created
	cp -f ${CONFIGURATION_DIRECTORY}/core-site.xml ${HDFS_DIRECTORY}/etc/hadoop/core-site.xml && \
	sed -i -e "s|\$${HDFS_MASTER_URI}|${HDFS_MASTER_URI}|g" ${HDFS_DIRECTORY}/etc/hadoop/core-site.xml
	echo ${HDFS_MASTER_HOST} > ${HDFS_DIRECTORY}/etc/hadoop/masters
	printf "%s\n" ${HDFS_SLAVES} > ${HDFS_DIRECTORY}/etc/hadoop/slaves
	cp -f ${CONFIGURATION_DIRECTORY}/hdfs-site.xml ${HDFS_DIRECTORY}/etc/hadoop/hdfs-site.xml

.PHONY: stop-hdfs
stop-hdfs:
	-${HDFS_DIRECTORY}/sbin/stop-dfs.sh

.PHONY: format
format: ${HDFS_DIRECTORY}/.created
	${HDFS_DIRECTORY}/bin/hdfs namenode -format

${HDFS_DIRECTORY}/.created:
	wget -nc ftp://ftp.task.gda.pl/pub/www/apache/dist/hadoop/core/hadoop-2.6.0/hadoop-2.6.0.tar.gz
	tar -xvzf hadoop-2.6.0.tar.gz
	sed -i -e "s|^export JAVA_HOME=\$${JAVA_HOME}|export JAVA_HOME=${JAVA_DIRECTORY}|g" ${HDFS_DIRECTORY}/etc/hadoop/hadoop-env.sh
	touch ${HDFS_DIRECTORY}/.created
	$(MAKE) format

.PHONY: start-spark
start-spark: ${SPARK_DIRECTORY}/.created update-spark-config
	${SPARK_DIRECTORY}/sbin/start-all.sh

.PHONY: stop-spark
stop-spark:
	-${SPARK_DIRECTORY}/sbin/stop-all.sh

.PHONY: update-spark-config
update-spark-config:
	printf "%s\n" ${SPARK_SLAVES} > ${SPARK_DIRECTORY}/conf/slaves

${SPARK_DIRECTORY}/.created:
	wget -nc ftp://ftp.task.gda.pl/pub/www/apache/dist/spark/spark-1.6.0/spark-1.6.0-bin-hadoop2.6.tgz
	tar -xvzf spark-1.6.0-bin-hadoop2.6.tgz
	touch ${SPARK_DIRECTORY}/.created

.PHONY: copy-input-to-hdfs
copy-input-to-hdfs: start-hdfs ${INPUT_DIRECTORY}
	${HDFS_DIRECTORY}/bin/hadoop fs -copyFromLocal ${INPUT_DIRECTORY} /

SimilarDocuments/target/scala-2.10/similar-documents_2.10-1.0.jar: SimilarDocuments/src/main/scala/SimilarDocuments.scala
	cd SimilarDocuments && sbt package

clean:
	$(MAKE) stop-hdfs
	$(MAKE) stop-spark
	-rm -rf ${HDFS_DIRECTORY}
	-rm -rf ${SPARK_DIRECTORY}
	-rm -rf SimilarDocuments/target
	-rm -rf SimilarDocuments/project