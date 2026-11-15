// O "Pix copia e cola" (BR Code estático, do manual do Banco Central) feito aqui
// mesmo, sem serviço de fora: a pessoa escolhe o valor no app do banco.

// Só a chave aleatória (um UUID). Nunca CPF, telefone ou e-mail no site.
export const CHAVE_ALEATORIA = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function chaveValida(chave) {
  return CHAVE_ALEATORIA.test(String(chave || '').trim());
}

// Cada campo é: o número dele (2 dígitos), o tamanho (2 dígitos) e o valor.
function campo(id, valor) {
  return `${id}${String(valor.length).padStart(2, '0')}${valor}`;
}

// O nome e a cidade vão sem acento e só com letras, números e espaço.
function limpo(texto, maximo) {
  return String(texto || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^A-Za-z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maximo)
    .trim();
}

// CRC16-CCITT (polinômio 0x1021, começa em 0xFFFF), em 4 letras maiúsculas.
export function crc16(texto) {
  let crc = 0xffff;
  for (let i = 0; i < texto.length; i++) {
    crc ^= texto.charCodeAt(i) << 8;
    for (let b = 0; b < 8; b++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

// Sem valor fixo (sem o campo 54) e sem identificador (***): serve para sempre.
export function pixCopiaECola({ chave, nome, cidade }) {
  const n = limpo(nome, 25);
  const c = limpo(cidade, 15);
  if (!chaveValida(chave) || !n || !c) return '';
  const conta = campo('00', 'br.gov.bcb.pix') + campo('01', chave.trim().toLowerCase());
  const corpo =
    campo('00', '01') +
    campo('26', conta) +
    campo('52', '0000') +
    campo('53', '986') +
    campo('58', 'BR') +
    campo('59', n) +
    campo('60', c) +
    campo('62', campo('05', '***')) +
    '6304';
  return corpo + crc16(corpo);
}
