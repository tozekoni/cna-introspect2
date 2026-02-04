import {DynamoDBDocumentClient, QueryCommand} from "@aws-sdk/lib-dynamodb";
import {DynamoDBClient} from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({region: "us-east-1"});
const docClient = DynamoDBDocumentClient.from(client);

const getClaims = async (count) => {
    const params = {
        TableName: "claims-table",
        PageSize: count,
    };
    const data = await docClient.send(new QueryCommand(params));
    console.log("Query Results:", data);
    return data.Items;
};

export {
    getClaims
};