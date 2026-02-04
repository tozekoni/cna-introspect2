import {GetObjectCommand, PutObjectCommand, S3Client} from "@aws-sdk/client-s3";
import {BUCKET_NAME, REGION} from "./config.js";

const client = new S3Client({region: REGION});

const getKey = (claimId) => `claim/${claimId}/notes.json`;

const getClaimNotes = async (claimId) => {
    const input = { // GetObjectRequest
        Bucket: BUCKET_NAME,
        Key: getKey(claimId),
    };
    const command = new GetObjectCommand(input);
    const response = await client.send(command);
    const bodyString = await response.Body.transformToString();
    return JSON.parse(bodyString);
}

const uploadClaimNotes = async (notes) => {
    await Promise.all(notes.map(async (note) => {
        await uploadSingleClaimNote(note.claimId, JSON.stringify(note));
    }));
}

const uploadSingleClaimNote = async (claimId, noteContent) => {
    const input = { // PutObjectRequest
        Body: noteContent,
        Bucket: BUCKET_NAME,
        ContentType: "application/json",
        Key: getKey(claimId),
    };

    const command = new PutObjectCommand(input);
    return await client.send(command);
}

export {uploadClaimNotes, getClaimNotes};