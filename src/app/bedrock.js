import {BedrockRuntimeClient, ConversationRole, ConverseCommand,} from "@aws-sdk/client-bedrock-runtime";
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

Result must be in json format with fields for each response. It must be parsabl and should not start with \`\`\`json or any other markdown.

Claim in json format:
${JSON.stringify(claim)}

Claim notes in json format:
${JSON.stringify(notes)}
`;

    const message = {
        content: [{text: prompt}],
        role: ConversationRole.USER,
    };

    const request = {
        modelId: MODEL_ID,
        messages: [message],
        inferenceConfig: {
            maxTokens: 8000,
            temperature: 0.5,
        },
    };


    const response = await client.send(new ConverseCommand(request));
    console.log(response);
    return response;
}
