IMG_NAME=julia_controller

COMMAND_RUN=docker run \
	  --name ${IMG_NAME} \
	  --detach=false \
	  --rm \
	  -v `pwd`:/usr/myapp/ \
 	  --network host \
	  -i \
	  -t \
	  ${IMG_NAME} /bin/bash -c

build:
	docker build --build-arg --no-cache --rm -t ${IMG_NAME} .

remove-image:
	docker rmi ${IMG_NAME}

run:
	$(COMMAND_RUN) \
            "cd /usr/myapp && bash"
    
