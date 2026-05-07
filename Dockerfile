FROM node:22-alpine
WORKDIR /app
COPY package.json ./
COPY services ./services
COPY frontend ./frontend
RUN apk add --no-cache python3 py3-pip
RUN npm install --workspace frontend
RUN pip3 install -r services/ingestion-service/requirements.txt \
  -r services/remediation-generator-service/requirements.txt \
  -r services/remediation-validator-service/requirements.txt \
  -r services/approval-service/requirements.txt \
  -r services/execution-service/requirements.txt \
  -r services/reporting-service/requirements.txt
RUN npm run build
CMD ["npm", "run", "dev", "--workspace", "frontend"]
