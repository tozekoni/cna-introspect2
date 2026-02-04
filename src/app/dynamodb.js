import {DynamoDBDocumentClient, BatchWriteCommand, GetCommand} from "@aws-sdk/lib-dynamodb";
import {DynamoDBClient} from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({region: "us-east-1"});
const docClient = DynamoDBDocumentClient.from(client);

const getClaim = async (id) => {
    const command = new GetCommand({
        TableName: "claims-table",
        Key: {
            Id: "id",
        },
    });
    const response = await docClient.send(command);
    console.log(response);
    return response;
};

const insertClaims = async (claims) => {
    const putRequests = claims.map((claim) => ({
        PutRequest: {
            TableName: "claims-table",
            Item: claim,
        },
    }));

    const command = new BatchWriteCommand({
        RequestItems: putRequests,
    });

    await docClient.send(command);
}

export {
    getClaim,
    insertClaims
};