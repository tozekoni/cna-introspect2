import {BedrockRuntimeClient, InvokeModelCommand} from "@aws-sdk/client-bedrock-runtime";
import {MODEL_ID, REGION} from "./config.js";

const client = new BedrockRuntimeClient({region: REGION});

export async function summarizeClaimNotes(claim, notes) {
    const prompt = `
You are an insurance claims assistant.

Given the following claim notes, generate:
1. Overall summary
2. Customer-facing summary
3. Adjuster-focused summary
4. Recommended next step

Claim:
${claim}

Claim notes:
${notes}
`;

    const command = new InvokeModelCommand({
        modelId: MODEL_ID,
        contentType: "application/json",
        accept: "application/json",
        body: JSON.stringify({
            messages: [
                {
                    role: "user",
                    content: prompt
                }
            ]
        })
    });


    const response = await client.send(command);
    const body = JSON.parse(new TextDecoder().decode(response.body));

    return body.content[0].text;
}
