PROJECT_DIR := $(shell realpath ..)

.PHONY: all
all: create_build_folder package_compress_image_function terraform_apply

.PHONY: build
build: create_build_folder package_compress_image_function

.PHONY: deploy
deploy: terraform_apply

.PHONY: destroy
destroy: terraform_destroy

.PHONY: create_build_folder
create_build_folder:
	@echo "Clean and Creating build folder"
	rm -rf ${PROJECT_DIR}/.terraform_build && \
	mkdir -p ${PROJECT_DIR}/.terraform_build

.PHONY: package_compress_image_function
package_compress_image_function:
	@echo "Compressing image function"
	mkdir -p ${PROJECT_DIR}/.terraform_build/lambda && \
	cp -r ${PROJECT_DIR}/lambda/* ${PROJECT_DIR}/.terraform_build/lambda && \
	cd ${PROJECT_DIR}/.terraform_build/lambda && \
	docker run --platform linux/arm64 --rm -v .:/var/task public.ecr.aws/sam/build-python3.9 pip install -r requirements.txt -t . && \
	zip -q -X -r ${PROJECT_DIR}/.terraform_build/lambda_package.zip . 
	find ${PROJECT_DIR}/.terraform_build/lambda -type f ! -name '*.pyc' | sort | xargs sha256sum | awk '{print $$1}' | sha256sum > ${PROJECT_DIR}/.terraform_build/lambda_package.sha256sum

.PHONY: terraform_apply
terraform_apply:
	@echo "Applying terraform"
	terraform init && \
	terraform apply -auto-approve

.PHONY: terraform_destroy
terraform_destroy:
	@echo "Destroying terraform"
	terraform destroy -auto-approve

.PHONY: clean
clean:
	@echo "Cleaning build folder"
	rm -rf ${PROJECT_DIR}/.terraform_build

