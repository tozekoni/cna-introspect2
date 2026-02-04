import express from 'express';
import cors from 'cors';
import {getClaim, insertClaims} from "./dynamodb.js";

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

app.get('/api/claims/:id', (req, res) => {
    res.json(getClaim(req.params.id));
});

app.post('/api/claims', (req, res) => {
    res.json(insertClaims(req.body));
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        error: 'Something went wrong!'
    });
});

export default app;