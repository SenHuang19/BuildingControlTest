IMG_NAME=jmodelica

COMMAND_RUN=docker run \
	  --name ${IMG_NAME} \
	  -p 127.0.0.1:5000:5000 \
 	  -it

build:
	docker build --build-arg testcase=${IMG_NAME} --no-cache --rm -t ${IMG_NAME} .

remove-image:
	docker rmi ${IMG_NAME}

run:
	$(COMMAND_RUN) ${IMG_NAME} python web.py config