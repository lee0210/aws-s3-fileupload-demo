import { S3Client, GetObjectCommand, HeadObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { createPresignedPost } from "@aws-sdk/s3-presigned-post";

const s3ClientConfig = {
    region: process.env.AWS_S3_BUCKET_REGION,
};

if (process.env.AWS_S3_ENDPOINT) {
    s3ClientConfig.endpoint = process.env.AWS_S3_ENDPOINT;
    s3ClientConfig.forcePathStyle = true;
}

const s3Client = new S3Client(s3ClientConfig);

const getSignedUrlForPostObject = async (objectKey, ftype) => {
    let { url: signedUrl, fields } = await createPresignedPost(s3Client, {
        Bucket: process.env.AWS_S3_BUCKET_NAME,
        Key: objectKey,
        Expires: 3600,
        Fields: {
            'Content-Type': ftype,
        },
        Conditions: [
            ['content-length-range', 0, 5 * 1024 * 1024], // up to 5 MB
            ["starts-with", "$Content-Type", "image/"],
        ],
    });

    if (process.env.AWS_S3_ENDPOINT) {
        const url = new URL(signedUrl);
        const localhostUrl = `http://localhost:${url.port}`;
        signedUrl = signedUrl.replace(url.origin, localhostUrl);
    }

    return { signedUrl, fields };
}

const getSignedUrlForGetObject = async (objectKey) => {
    try {
        await s3Client.send(new HeadObjectCommand({
            Bucket: process.env.AWS_S3_BUCKET_NAME,
            Key: `${objectKey}.webp`,
        }));
        objectKey = `${objectKey}.webp`;
    } catch (error) {
        // If the .webp file does not exist, proceed with the original objectKey
    }

    const command = new GetObjectCommand({
        Bucket: process.env.AWS_S3_BUCKET_NAME,
        Key: objectKey,
    });

    let signedUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });

    if (process.env.AWS_S3_ENDPOINT) {
        const url = new URL(signedUrl);
        const localhostUrl = `http://localhost:${url.port}`;
        signedUrl = signedUrl.replace(url.origin, localhostUrl);
    }

    return signedUrl;
}

export { getSignedUrlForGetObject, getSignedUrlForPostObject };