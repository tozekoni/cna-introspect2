import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const client = new S3Client({ region: "us-east-1" });

const uploadClaimNotes = async (notes) => {
    notes.each(async (note) => {
        await uploadSingleClaimNote(note.claimId, JSON.stringify(note));
    });
}

const uploadSingleClaimNote = async (claimId, noteContent) => {
    const input = { // PutObjectRequest
        Body: noteContent,
        Bucket: 'claim-notes-bucket',
        ContentType: "application/json",
        Key: `claim/${claimId}/notes.json`,
    };

    const command = new PutObjectCommand(input);
    return await client.send(command);
}

export {uploadClaimNotes};