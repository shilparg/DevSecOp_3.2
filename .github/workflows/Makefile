AWS_REGION=us-east-1
REPO_NAME=flask-ecr-demo
ACCOUNT_ID=$(shell aws sts get-caller-identity --query Account --output text)
IMAGE_URI=$(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(REPO_NAME)

build:
	docker build -t $(IMAGE_URI):latest -t $(IMAGE_URI):$(shell git rev-parse HEAD) .

push:
	docker push $(IMAGE_URI):latest
	docker push $(IMAGE_URI):$(shell git rev-parse HEAD)

ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(IMAGE_URI)

create-ecr:
	aws ecr create-repository --repository-name $(REPO_NAME) --region $(AWS_REGION) \
	--image-scanning-configuration scanOnPush=true \
	--encryption-configuration encryptionType=AES256