const { randomUUID } = require('node:crypto');
const { cert, getApp, getApps, initializeApp } = require('firebase-admin/app');
const { getStorage } = require('firebase-admin/storage');

const extensionByMimeType = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);

class FirebaseStorageConfigurationError extends Error {
  constructor() {
    super('Firebase Storage n’est pas configuré sur le serveur.');
    this.name = 'FirebaseStorageConfigurationError';
    this.code = 'FIREBASE_STORAGE_NOT_CONFIGURED';
  }
}

function getFirebaseBucket() {
  const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET?.trim();

  if (!projectId || !clientEmail || !privateKey || !bucketName) {
    throw new FirebaseStorageConfigurationError();
  }

  let app;
  if (getApps().length > 0) {
    app = getApp();
  } else {
    app = initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
      storageBucket: bucketName,
    });
  }

  return getStorage(app).bucket(bucketName);
}

async function uploadPromotionImage(buffer, contentType) {
  const extension = extensionByMimeType.get(contentType);
  if (!extension) {
    throw new TypeError('Format d’image non autorisé.');
  }

  const bucket = getFirebaseBucket();
  const storagePath = `promotions/${randomUUID()}.${extension}`;
  const downloadToken = randomUUID();
  const file = bucket.file(storagePath);

  await file.save(buffer, {
    resumable: false,
    metadata: {
      contentType,
      cacheControl: 'public, max-age=86400',
      metadata: { firebaseStorageDownloadTokens: downloadToken },
    },
  });

  const imageUrl =
    `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}` +
    `/o/${encodeURIComponent(storagePath)}?alt=media&token=${downloadToken}`;

  return { imageUrl, storagePath };
}

async function deletePromotionImage(storagePath) {
  if (!storagePath) return;
  const bucket = getFirebaseBucket();
  await bucket.file(storagePath).delete({ ignoreNotFound: true });
}

module.exports = {
  FirebaseStorageConfigurationError,
  deletePromotionImage,
  uploadPromotionImage,
};
