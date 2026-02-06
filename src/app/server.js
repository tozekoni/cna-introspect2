import express from 'express';
import cors from 'cors';
import {getClaim, insertClaims} from "./dynamodb.js";
import asyncHandler from 'express-async-handler';
import {getClaimNotes, uploadClaimNotes} from "./s3.js";
import {summarizeClaimNotes} from "./bedrock.js";
import {CloudWatchClient, PutMetricDataCommand} from "@aws-sdk/client-cloudwatch";
import {REGION} from "./config.js";
import AWSXRay from 'aws-xray-sdk';


const app = express();
const xrayExpress = AWSXRay.express;

const cloudwatch = new CloudWatchClient({region: REGION});


// Middleware
app.use(cors());
app.use(express.json());
app.use(xrayExpress.openSegment('ClaimsService'));

// Metrics middleware - must be before routes to capture all requests
app.use((req, res, next) => {
    const start = Date.now();

    res.on('finish', async () => {
        const duration = Date.now() - start;

        try {
            await cloudwatch.send(new PutMetricDataCommand({
                Namespace: 'ClaimsApp',
                MetricData: [
                    {
                        MetricName: 'RequestDuration',
                        Value: duration,
                        Unit: 'Milliseconds',
                        Dimensions: [
                            {Name: 'Endpoint', Value: req.path},
                            {Name: 'Method', Value: req.method},
                            {Name: 'StatusCode', Value: res.statusCode.toString()}
                        ]
                    }
                ]
            }));
        } catch (err) {
            console.error('Failed to send metrics:', err);
        }
    });

    next();
});

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
    const notes = await getClaimNotes(claimId);
    const result = await summarizeClaimNotes(claim, notes);
    res.json(JSON.parse(result.output.message.content[0].text));
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


app.use(xrayExpress.closeSegment());

export default app;