function maskEmail(value) {
  const email = String(value ?? '').trim();
  const atIndex = email.lastIndexOf('@');

  if (atIndex <= 0 || atIndex === email.length - 1) {
    return '••••';
  }

  const localPart = email.slice(0, atIndex);
  const domain = email.slice(atIndex + 1);
  const maskLength = Math.max(3, Math.min(localPart.length - 1, 6));

  return `${localPart[0]}${'•'.repeat(maskLength)}@${domain}`;
}

module.exports = { maskEmail };
