const {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const SIGNED_URL_TTL_SECONDS = 300;

class StorageNotConfiguredError extends Error {
  constructor() {
    super('Le stockage privé des documents est indisponible.');
    this.name = 'StorageNotConfiguredError';
    this.code = 'R2_NOT_CONFIGURED';
  }
}

let cachedClient;
let cachedConfig;

function readConfig() {
  const { R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME } = process.env;
  if (![R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME]
    .every((value) => typeof value === 'string' && value.trim())) {
    throw new StorageNotConfiguredError();
  }
  return {
    accountId: R2_ACCOUNT_ID.trim(),
    accessKeyId: R2_ACCESS_KEY_ID.trim(),
    secretAccessKey: R2_SECRET_ACCESS_KEY.trim(),
    bucketName: R2_BUCKET_NAME.trim(),
  };
}

function getStorage() {
  const config = readConfig();
  const fingerprint = `${config.accountId}:${config.bucketName}:${config.accessKeyId}`;
  if (!cachedClient || cachedConfig !== fingerprint) {
    cachedClient = new S3Client({
      region: 'auto',
      endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
    });
    cachedConfig = fingerprint;
  }
  return { client: cachedClient, bucketName: config.bucketName };
}

async function putPrivatePdf(key, buffer, devisId) {
  const { client, bucketName } = getStorage();
  await client.send(new PutObjectCommand({
    Bucket: bucketName,
    Key: key,
    Body: buffer,
    ContentLength: buffer.length,
    ContentType: 'application/pdf',
    ContentDisposition: `inline; filename="devis-${Number(devisId)}.pdf"`,
    CacheControl: 'private, no-store',
  }));
}

async function signPrivatePdfGet(key, devisId) {
  const { client, bucketName } = getStorage();
  const expiresIn = SIGNED_URL_TTL_SECONDS;
  const url = await getSignedUrl(
    client,
    new GetObjectCommand({
      Bucket: bucketName,
      Key: key,
      ResponseContentType: 'application/pdf',
      ResponseContentDisposition: `inline; filename="devis-${Number(devisId)}.pdf"`,
      ResponseCacheControl: 'private, no-store',
    }),
    { expiresIn },
  );
  return {
    url,
    expiresAt: new Date(Date.now() + expiresIn * 1000).toISOString(),
  };
}

async function deletePrivatePdf(key) {
  const { client, bucketName } = getStorage();
  await client.send(new DeleteObjectCommand({ Bucket: bucketName, Key: key }));
}

module.exports = {
  SIGNED_URL_TTL_SECONDS,
  StorageNotConfiguredError,
  putPrivatePdf,
  signPrivatePdfGet,
  deletePrivatePdf,
};
