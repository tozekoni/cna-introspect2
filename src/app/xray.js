import AWSXRay from 'aws-xray-sdk';
import AWS from 'aws-sdk';

export const captureAWS = AWSXRay.captureAWS(AWS);
export const captureHTTPs = AWSXRay.captureHTTPs(require('https'));

// Update src/app/server.js
import AWSXRay from 'aws-xray-sdk';

// Add before other middleware
app.use(AWSXRay.express.openSegment('ClaimsService'));

// Add after error handling middleware
app.use(AWSXRay.express.closeSegment());
