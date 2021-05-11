COMMAND_RUN1=docker run \
      --detach=true \
	  --name ${IMG_NAME1} \
	  -p 127.0.0.1:${Port1}:5000 \
	  --net mynet \
 	  -it

COMMAND_RUN2=docker run \
      --detach=true \
	  --name ${IMG_NAME2} \
	  -p 127.0.0.1:${Port2}:5500 \
	  --net mynet \
 	  -it

build:
	docker build --no-cache --rm -t ${IMG_NAME1} .
	cd eplus && docker build  --no-cache --rm -t ${IMG_NAME2} .

remove-image:
	docker rmi ${IMG_NAME}

run_jmodelica:
	$(COMMAND_RUN1) ${IMG_NAME1} python web.py config

run_eplus:
	$(COMMAND_RUN2) ${IMG_NAME2} python web.py config ${IMG_NAME1}	
	
run:
	make run_eplus	
	make run_jmodelica