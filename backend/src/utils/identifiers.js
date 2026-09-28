function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

function normalizePhone(value) {
  let normalized = String(value ?? '')
    .trim()
    .replace(/[\s\-().]/g, '');

  if (!normalized) return '';
  if (normalized.startsWith('+')) return normalized;
  if (normalized.startsWith('00')) return `+${normalized.slice(2)}`;
  if (normalized.startsWith('228')) return `+${normalized}`;
  if (normalized.startsWith('0') && /^\d{9,10}$/.test(normalized)) {
    return `+228${normalized.slice(1)}`;
  }
  if (/^\d{8,9}$/.test(normalized)) return `+228${normalized}`;

  return normalized;
}

function getPhoneCandidates(value) {
  const raw = String(value ?? '').trim();
  const normalized = normalizePhone(raw);
  const withoutPlus = normalized.startsWith('+')
    ? normalized.slice(1)
    : normalized;

  return [...new Set([raw, normalized, withoutPlus].filter(Boolean))];
}

function normalizeIdentifier(value) {
  const raw = String(value ?? '').trim();
  return {
    raw,
    email: normalizeEmail(raw),
    phoneCandidates: getPhoneCandidates(raw),
  };
}

module.exports = {
  normalizeEmail,
  normalizePhone,
  getPhoneCandidates,
  normalizeIdentifier,
};
