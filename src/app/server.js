import express from 'express';
import cors from 'cors';
import {getClaim, insertClaims} from "./dynamodb.js";
import asyncHandler from 'express-async-handler';
import {uploadClaimNotes, getClaimNotes} from "./s3.js";
import {summarizeClaimNotes} from "./bedrock.js";

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        service: 'claims-service',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/test', (req, res) => {
    res.json({
        status: 'OK',
        service: 'claims-service',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/claims/:id', asyncHandler(async (req, res) => {
    res.json(await getClaim(req.params.id));
}));

app.post('/api/claims/:id/summarize', asyncHandler(async (req, res) => {
    const claimId = req.params.id;
    const claim = await getClaim(claimId);
    const notes = getClaimNotes(claimId);
    res.json(await summarizeClaimNotes(claim, notes));
}));

app.post('/api/claims', asyncHandler(async (req, res) => {
    res.json(await insertClaims(req.body));
}));

app.post('/api/claimNotes', asyncHandler(async (req, res) => {
    res.json(await uploadClaimNotes(req.body));
}));

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        error: 'Something went wrong!'
    });
});

export default app;