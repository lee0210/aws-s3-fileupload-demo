PROJECT_DIR := $(shell realpath ..)

all: create_build_folder package_compress_image_function build_express_app terraform_apply

build: create_build_folder package_compress_image_function build_express_app

deploy: terraform_apply

destroy: terraform_destroy

create_build_folder:
	@echo "Clean and Creating build folder"
	rm -rf ${PROJECT_DIR}/.terraform_build && \
	mkdir -p ${PROJECT_DIR}/.terraform_build

package_compress_image_function:
	@echo "Compressing image function"
	mkdir -p ${PROJECT_DIR}/.terraform_build/lambda && \
	cp -r ${PROJECT_DIR}/lambda/* ${PROJECT_DIR}/.terraform_build/lambda && \
	cd ${PROJECT_DIR}/.terraform_build/lambda && \
	docker run --platform linux/arm64 --rm -v .:/var/task public.ecr.aws/sam/build-python3.9 pip install -r requirements.txt -t . && \
	zip -q -X -r ${PROJECT_DIR}/.terraform_build/lambda_package.zip . 
	find ${PROJECT_DIR}/.terraform_build/lambda -type f ! -name '*.pyc' | sort | xargs sha256sum | awk '{print $$1}' | sha256sum > ${PROJECT_DIR}/.terraform_build/lambda_package.sha256sum

build_express_app:
	@echo "Building express app"
	cd ${PROJECT_DIR}/backend && \
	docker build --platform linux/arm64 -o type=docker,dest=- . > ${PROJECT_DIR}/.terraform_build/express-app.tar
	docker load -i ${PROJECT_DIR}/.terraform_build/express-app.tar | awk '/Loaded image ID:/ {print $$4}' | xargs -I {} docker tag {} express-app:latest

terraform_apply:
	@echo "Applying terraform"
	terraform init && \
	terraform apply -auto-approve

terraform_destroy:
	@echo "Destroying terraform"
	terraform destroy -auto-approve

clean:
	@echo "Cleaning build folder"
	rm -rf ${PROJECT_DIR}/.terraform_build

.PHONY: all build deploy create_build_folder package_compress_image_function terraform_apply terraform_destroy destroy clean