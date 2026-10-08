const path = require('node:path');
const PDFDocument = require('pdfkit');

const FONT_PATH = path.join(__dirname, '..', 'assets', 'NotoSans-Variable.ttf');
const FCFA = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });

function displayDate(value) {
  const match = String(value ?? '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return String(value ?? '');
  return `${match[3]}/${match[2]}/${match[1]}`;
}

function cleanText(value, fallback = 'Non renseigné') {
  const text = String(value ?? '').trim();
  return text || fallback;
}

function writeLabel(doc, label, value, options = {}) {
  doc.font('NotoSans').fontSize(9).fillColor('#64748B').text(label.toUpperCase(), options);
  doc.moveDown(0.25);
  doc.font('NotoSans').fontSize(11).fillColor('#0F172A').text(cleanText(value), options);
  doc.moveDown(0.9);
}

function collectPdfBuffer(doc) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.once('error', reject);
    doc.once('end', () => resolve(Buffer.concat(chunks)));
    doc.end();
  });
}

async function createDevisPdfBuffer({
  devis,
  montant,
  dateValidite,
  commentaireAdmin,
  dateEmission,
}) {
  if (!devis || !Number.isSafeInteger(Number(montant)) || Number(montant) <= 0) {
    throw new TypeError('Un devis et un montant FCFA positif sont requis.');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(dateValidite ?? ''))) {
    throw new TypeError('La date de validité doit être une date ISO.');
  }

  const doc = new PDFDocument({
    size: 'A4',
    margins: { top: 54, right: 54, bottom: 58, left: 54 },
    bufferPages: true,
    info: {
      Title: `Devis ${devis.id}`,
      Author: 'ÉCHELLE EG39',
      Subject: 'Offre de prestation',
      Creator: 'ÉCHELLE EG39',
    },
  });
  doc.registerFont('NotoSans', FONT_PATH);

  doc.font('NotoSans').fontSize(20).fillColor('#075985').text('ÉCHELLE EG39');
  doc.moveDown(0.25);
  doc.fontSize(9).fillColor('#64748B').text('TOPOGRAPHIE & BTP');
  doc.moveDown(1.8);
  doc.fontSize(22).fillColor('#0F172A').text('OFFRE DE PRESTATION');
  doc.moveDown(0.35);
  doc.fontSize(11).fillColor('#475569').text(`Devis n° ${devis.id}`);
  doc.moveDown(1.4);

  const columnWidth = (doc.page.width - doc.page.margins.left - doc.page.margins.right - 24) / 2;
  const leftX = doc.page.margins.left;
  const rightX = leftX + columnWidth + 24;
  const detailsTop = doc.y;

  writeLabel(doc, 'Date d’émission', displayDate(dateEmission), { width: columnWidth });
  const leftBottom = doc.y;
  doc.y = detailsTop;
  writeLabel(doc, 'Valable jusqu’au (inclus)', displayDate(dateValidite), {
    x: rightX,
    width: columnWidth,
  });
  doc.y = Math.max(leftBottom, doc.y) + 8;

  doc.moveTo(leftX, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y)
    .lineWidth(1).strokeColor('#E2E8F0').stroke();
  doc.moveDown(1.3);

  doc.font('NotoSans').fontSize(13).fillColor('#075985').text('Client et demande');
  doc.moveDown(0.7);
  writeLabel(doc, 'Client', devis.nom);
  if (devis.email) writeLabel(doc, 'E-mail', devis.email);
  if (devis.telephone) writeLabel(doc, 'Téléphone', devis.telephone);
  writeLabel(doc, 'Prestation', devis.service_name || devis.serviceName);
  if (devis.description) writeLabel(doc, 'Description du projet', devis.description);

  doc.moveDown(0.4);
  doc.font('NotoSans').fontSize(13).fillColor('#075985').text('Montant proposé');
  doc.moveDown(0.5);
  doc.fontSize(22).fillColor('#0F172A').text(`${FCFA.format(Number(montant))} FCFA`);

  const note = String(commentaireAdmin ?? '').trim();
  if (note) {
    doc.moveDown(1.2);
    writeLabel(doc, 'Message de l’administration', note);
  }

  doc.moveDown(1.2);
  doc.font('NotoSans').fontSize(9).fillColor('#64748B')
    .text(`Cette offre est valable jusqu’au ${displayDate(dateValidite)} inclus.`, {
      width: doc.page.width - doc.page.margins.left - doc.page.margins.right,
    });
  doc.moveDown(0.5);
  doc.fontSize(8).fillColor('#94A3B8')
    .text('Document généré automatiquement à partir des informations de la demande.', {
      width: doc.page.width - doc.page.margins.left - doc.page.margins.right,
    });

  const range = doc.bufferedPageRange();
  for (let index = range.start; index < range.start + range.count; index += 1) {
    doc.switchToPage(index);
    doc.font('NotoSans').fontSize(8).fillColor('#94A3B8')
      .text(`ÉCHELLE EG39 · Devis ${devis.id} · Page ${index + 1 - range.start} / ${range.count}`, 54, 780, {
        width: doc.page.width - 108,
        align: 'center',
        lineBreak: false,
      });
  }

  return collectPdfBuffer(doc);
}

module.exports = { createDevisPdfBuffer, displayDate };
