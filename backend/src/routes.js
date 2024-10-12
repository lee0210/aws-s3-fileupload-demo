import express from 'express';
import { getSignedUrlForGetObject, getSignedUrlForPostObject } from './aws-s3.js';

const router = express.Router();

router.post('/file', async (req, res) => {
    const { filename: objectKey, ftype} = req.body;
    return res.json(await getSignedUrlForPostObject(objectKey, ftype));
});

router.get('/file/:objectKey', async (req, res) => {
    const objectKey = req.params.objectKey;
    const signedUrl = await getSignedUrlForGetObject(objectKey);
    return res.json({signedUrl});
});

export default router;