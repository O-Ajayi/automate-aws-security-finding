import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

async function main() {
  const now = new Date().toISOString();
  await client.send(
    new PutCommand({
      TableName: process.env.FINDINGS_TABLE ?? "findings_catalog",
      Item: {
        findingId: "sample-finding-1",
        accountId: "111111111111",
        region: "us-east-1",
        resourceId: "i-1234567890",
        title: "Outdated OpenSSL package",
        severity: "HIGH",
        status: "needs_plan",
        dedupKey: "111111111111:us-east-1:openssl:i-1234567890",
        updatedAt: now
      }
    })
  );
  console.log("Seed completed");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
