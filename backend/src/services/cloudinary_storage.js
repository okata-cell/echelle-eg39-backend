const { randomUUID } = require('node:crypto');
const { Readable } = require('node:stream');
const cloudinary = require('cloudinary').v2;

const extensionByMimeType = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);

class CloudinaryStorageConfigurationError extends Error {
  constructor() {
    super('Cloudinary n’est pas configuré sur le serveur.');
    this.name = 'CloudinaryStorageConfigurationError';
    this.code = 'CLOUDINARY_STORAGE_NOT_CONFIGURED';
  }
}

function getCloudinary() {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME?.trim();
  const apiKey = process.env.CLOUDINARY_API_KEY?.trim();
  const apiSecret = process.env.CLOUDINARY_API_SECRET?.trim();

  if (!cloudName || !apiKey || !apiSecret) {
    throw new CloudinaryStorageConfigurationError();
  }

  cloudinary.config({
    cloud_name: cloudName,
    api_key: apiKey,
    api_secret: apiSecret,
    secure: true,
  });

  return cloudinary;
}

// Dossier Cloudinary où sont rangés les visuels, un par grand type de contenu.
const FOLDER_PROMOTIONS = 'promotions';
const FOLDER_ACTUALITES = 'actualites';

async function uploadImage(buffer, contentType, folder) {
  const extension = extensionByMimeType.get(contentType);
  if (!extension) {
    throw new TypeError('Format d’image non autorisé.');
  }

  const client = getCloudinary();
  const publicId = `${folder}/${randomUUID()}`;

  return new Promise((resolve, reject) => {
    const upload = client.uploader.upload_stream(
      {
        resource_type: 'image',
        public_id: publicId,
        format: extension,
        overwrite: false,
        invalidate: true,
      },
      (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        if (!result?.secure_url || !result.public_id) {
          reject(new Error('Cloudinary n’a pas renvoyé les informations du visuel.'));
          return;
        }

        resolve({ imageUrl: result.secure_url, storagePath: result.public_id });
      },
    );

    Readable.from([buffer]).pipe(upload);
  });
}

async function deleteImage(storagePath, folder) {
  if (!storagePath) return;
  if (!storagePath.startsWith(`${folder}/`)) {
    throw new TypeError('Chemin de l’image invalide.');
  }

  const client = getCloudinary();
  await client.uploader.destroy(storagePath, {
    resource_type: 'image',
    invalidate: true,
  });
}

function uploadPromotionImage(buffer, contentType) {
  return uploadImage(buffer, contentType, FOLDER_PROMOTIONS);
}

function deletePromotionImage(storagePath) {
  return deleteImage(storagePath, FOLDER_PROMOTIONS);
}

function uploadActualiteImage(buffer, contentType) {
  return uploadImage(buffer, contentType, FOLDER_ACTUALITES);
}

function deleteActualiteImage(storagePath) {
  return deleteImage(storagePath, FOLDER_ACTUALITES);
}

module.exports = {
  CloudinaryStorageConfigurationError,
  deleteActualiteImage,
  deletePromotionImage,
  uploadActualiteImage,
  uploadPromotionImage,
};
