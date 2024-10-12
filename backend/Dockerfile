FROM public.ecr.aws/docker/library/node:20-slim
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter
EXPOSE 3000
WORKDIR "/var/task"
ADD ./package.json /var/task/package.json
RUN npm install --omit=dev
ADD src/ /var/task/src
CMD ["node", "src/app.js"]